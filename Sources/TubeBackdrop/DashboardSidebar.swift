import SwiftUI

/// Solid, non–split-view sidebar (no system glass / `List` sidebar chrome).
struct DashboardSidebar: View {
  @Binding var selection: SidebarSelection
  @EnvironmentObject private var wallpaper: WallpaperController

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("TubeBackdrop")
        .font(.system(size: 13, weight: .bold, design: .default))
        .tracking(0.3)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 18)

      VStack(alignment: .leading, spacing: 4) {
        ForEach(SidebarSelection.allCases) { item in
          sidebarRow(item)
        }
      }
      .padding(.horizontal, 10)

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Circle()
          .fill(wallpaper.isRunning ? Color.green.opacity(0.85) : Color.secondary.opacity(0.35))
          .frame(width: 6, height: 6)
        Text(wallpaper.isRunning ? "Backdrop on" : "Backdrop off")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))

      Divider()
        .background(Color(nsColor: .separatorColor))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private func sidebarRow(_ item: SidebarSelection) -> some View {
    let isOn = selection == item
    return Button {
      selection = item
    } label: {
      HStack(spacing: 10) {
        Image(systemName: item.icon)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(isOn ? Color.accentColor : .secondary)
          .frame(width: 22, alignment: .center)
        Text(item.title)
          .font(.system(size: 13, weight: isOn ? .semibold : .regular))
          .foregroundStyle(isOn ? Color.primary : Color.secondary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isOn ? Color.accentColor.opacity(0.18) : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(isOn ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}
