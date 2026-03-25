#if canImport(Sparkle)
import AppKit
import Sparkle

/// Hosts Sparkle’s standard updater (appcast + signed ZIP). Only compiled when Sparkle is linked (Xcode app target).
final class SparkleAppDelegate: NSObject, NSApplicationDelegate {
  static weak var shared: SparkleAppDelegate?

  private var updaterController: SPUStandardUpdaterController!
  private var sessionProgressContext = 0

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    let updater = updaterController.updater
    SparkleUpdateState.shared.attach(updater: updater)
    updater.addObserver(
      self,
      forKeyPath: #keyPath(SPUUpdater.sessionInProgress),
      options: [.new, .initial],
      context: &sessionProgressContext
    )
    DispatchQueue.main.async {
      SparkleUpdateState.shared.setUpdateSessionActive(updater.sessionInProgress)
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActiveNotification),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      SparkleUpdateState.shared.requestSilentProbeIfNeeded()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    updaterController?.updater.removeObserver(self, forKeyPath: #keyPath(SPUUpdater.sessionInProgress), context: &sessionProgressContext)
  }

  @objc private func applicationDidBecomeActiveNotification() {
    Task { @MainActor in
      SparkleUpdateState.shared.requestSilentProbeIfNeeded()
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if context == &sessionProgressContext, keyPath == #keyPath(SPUUpdater.sessionInProgress),
      let updater = object as? SPUUpdater
    {
      DispatchQueue.main.async {
        SparkleUpdateState.shared.setUpdateSessionActive(updater.sessionInProgress)
      }
      return
    }
    super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
  }

  @objc func checkForUpdates(_ sender: Any?) {
    updaterController.checkForUpdates(sender)
  }
}

extension SparkleAppDelegate: SPUUpdaterDelegate {
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    Task { @MainActor in
      SparkleUpdateState.shared.applyFoundUpdate(item: item)
    }
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    Task { @MainActor in
      SparkleUpdateState.shared.applyNoNewUpdate()
    }
  }
}

enum SparkleUpdateMenu {
  static func checkForUpdates() {
    guard let appDelegate = SparkleAppDelegate.shared else { return }
    appDelegate.checkForUpdates(nil)
  }
}
#endif
