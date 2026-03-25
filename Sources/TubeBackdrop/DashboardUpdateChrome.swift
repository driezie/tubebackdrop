#if canImport(Sparkle)
import SwiftUI

/// Toolbar control: in-place Sparkle update (same flow as the menu), not a separate “download full app” page.
struct DashboardUpdateToolbarAccessory: View {
  @ObservedObject private var sparkle = SparkleUpdateState.shared

  var body: some View {
    Group {
      if sparkle.updateAvailable {
        Button {
          sparkle.startUserUpdateFlow()
        } label: {
          if sparkle.offeredVersion.isEmpty {
            Label("Update available", systemImage: "arrow.down.circle.fill")
          } else {
            Label("v\(sparkle.offeredVersion)", systemImage: "arrow.down.circle.fill")
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help(
          sparkle.offeredVersion.isEmpty
            ? "Install the latest version (in-place update)"
            : "Install version \(sparkle.offeredVersion) (in-place update)"
        )
        .accessibilityLabel("Software update available")
      }
    }
  }
}

struct DashboardUpdateSessionOverlay: View {
  @ObservedObject private var sparkle = SparkleUpdateState.shared

  var body: some View {
    Group {
      if sparkle.updateSessionActive {
        ZStack {
          Color.black.opacity(0.4)
            .ignoresSafeArea()

          VStack(spacing: 14) {
            ProgressView()
              .scaleEffect(1.15)
            Text("Updating TubeBackdrop…")
              .font(.headline)
            Text("Sparkle is downloading or installing the update. You may be prompted to authorize; the app may restart when finished.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 320)
          }
          .padding(28)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color(nsColor: .windowBackgroundColor))
              .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
          )
        }
        .transition(.opacity)
        .allowsHitTesting(true)
      }
    }
    .animation(.easeOut(duration: 0.2), value: sparkle.updateSessionActive)
  }
}
#endif
