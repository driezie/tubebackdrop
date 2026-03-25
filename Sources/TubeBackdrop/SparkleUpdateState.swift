#if canImport(Sparkle)
import Combine
import Sparkle

/// Published state for dashboard update affordances (silent probe + Sparkle session).
@MainActor
final class SparkleUpdateState: ObservableObject {
  static let shared = SparkleUpdateState()

  @Published var updateAvailable = false
  @Published var offeredVersion: String = ""
  @Published var updateSessionActive = false

  private weak var updater: SPUUpdater?
  private var lastSilentProbe: Date?
  private static let probeInterval: TimeInterval = 3600

  private init() {}

  func attach(updater: SPUUpdater) {
    self.updater = updater
  }

  /// Background check only; does not present Sparkle UI. Throttled to `probeInterval`.
  func requestSilentProbeIfNeeded() {
    guard let updater else { return }
    let now = Date()
    if let last = lastSilentProbe, now.timeIntervalSince(last) < Self.probeInterval {
      return
    }
    lastSilentProbe = now
    updater.checkForUpdateInformation()
  }

  func startUserUpdateFlow() {
    SparkleUpdateMenu.checkForUpdates()
  }

  func applyFoundUpdate(item: SUAppcastItem) {
    let v = item.displayVersionString
    offeredVersion = v.isEmpty ? item.versionString : v
    updateAvailable = true
  }

  func applyNoNewUpdate() {
    updateAvailable = false
    offeredVersion = ""
  }

  func setUpdateSessionActive(_ active: Bool) {
    updateSessionActive = active
  }
}
#endif
