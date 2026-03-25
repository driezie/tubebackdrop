import SwiftUI

struct DashboardSidebar: View {
  @Binding var selection: SidebarSelection
  @EnvironmentObject private var wallpaper: WallpaperController

  var body: some View {
    List(SidebarSelection.allCases, selection: $selection) { item in
      Label(item.title, systemImage: item.icon)
        .tag(item)
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading, spacing: 10) {
        Divider()
        HStack(spacing: 8) {
          Image(systemName: wallpaper.isRunning ? "play.circle.fill" : "pause.circle")
            .foregroundStyle(wallpaper.isRunning ? .green : .secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text("Video backdrop")
              .font(.caption.weight(.semibold))
            Text(wallpaper.isRunning ? "Playing on desktop" : "Idle")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 8)
    }
    .navigationTitle("TubeBackdrop")
  }
}
