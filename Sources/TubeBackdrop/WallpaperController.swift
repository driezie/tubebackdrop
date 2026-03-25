import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class WallpaperController: ObservableObject {
  @Published var isRunning = false

  private var windows: [NSWindow] = []
  private var players: [AVPlayer] = []
  private var loopObservers: [NSObjectProtocol] = []
  private var statusObservations: [NSKeyValueObservation] = []

  func stop() {
    statusObservations.removeAll()

    loopObservers.forEach { NotificationCenter.default.removeObserver($0) }
    loopObservers.removeAll()

    windows.forEach { $0.orderOut(nil) }
    windows.removeAll()

    players.forEach { $0.pause() }
    players.removeAll()

    isRunning = false
  }

  func playVideo(at fileURL: URL) {
    stop()
    let screens = NSScreen.screens
    guard !screens.isEmpty else { return }

    isRunning = true

    for screen in screens {
      let player = AVPlayer(url: fileURL)
      player.isMuted = true
      player.automaticallyWaitsToMinimizeStalling = false
      player.actionAtItemEnd = .none
      attachLoop(to: player)

      let window = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.isOpaque = true
      window.backgroundColor = .black
      window.hasShadow = false
      window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
      window.collectionBehavior = [
        .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
      ]
      window.isReleasedWhenClosed = false
      window.ignoresMouseEvents = true

      let initialBounds = NSRect(origin: .zero, size: screen.frame.size)
      let box = VideoBackdropView(frame: initialBounds)
      window.contentView = box
      box.autoresizingMask = [.width, .height]
      box.player = player

      observeReadyToPlay(player: player)

      window.setFrame(screen.frame, display: true)
      window.orderBack(nil)
      window.orderFrontRegardless()
      box.layoutSubtreeIfNeeded()

      windows.append(window)
      players.append(player)
    }
  }

  private func observeReadyToPlay(player: AVPlayer) {
    guard let item = player.currentItem else {
      player.play()
      return
    }

    let obs = item.observe(\.status, options: [.initial, .new]) { [weak player] it, _ in
      guard it.status == .readyToPlay else { return }
      DispatchQueue.main.async {
        player?.play()
      }
    }
    statusObservations.append(obs)
  }

  private func attachLoop(to player: AVPlayer) {
    guard let item = player.currentItem else { return }
    let token = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak player] _ in
      player?.seek(to: .zero)
      player?.play()
    }
    loopObservers.append(token)
  }
}

final class VideoBackdropView: NSView {
  private let playerLayer = AVPlayerLayer()

  var player: AVPlayer? {
    didSet { playerLayer.player = player }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
    playerLayer.videoGravity = .resizeAspectFill
    playerLayer.needsDisplayOnBoundsChange = true
    layer?.addSublayer(playerLayer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    playerLayer.frame = bounds
  }

  override var isOpaque: Bool { true }

  override var acceptsFirstResponder: Bool { false }
}
