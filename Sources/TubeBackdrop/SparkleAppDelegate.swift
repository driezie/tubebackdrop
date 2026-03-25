#if canImport(Sparkle)
import AppKit
import Sparkle

/// Hosts Sparkle’s standard updater (appcast + signed ZIP). Only compiled when Sparkle is linked (Xcode app target).
final class SparkleAppDelegate: NSObject, NSApplicationDelegate {
  static weak var shared: SparkleAppDelegate?

  private var updaterController: SPUStandardUpdaterController!

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  @objc func checkForUpdates(_ sender: Any?) {
    updaterController.checkForUpdates(sender)
  }
}

enum SparkleUpdateMenu {
  static func checkForUpdates() {
    guard let appDelegate = SparkleAppDelegate.shared else { return }
    appDelegate.checkForUpdates(nil)
  }
}
#endif
