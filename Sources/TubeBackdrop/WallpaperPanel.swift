import SwiftUI

struct WallpaperPanel: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var wallpaper: WallpaperController

  @State private var errorText: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Wallpaper")
            .font(.title.weight(.bold))
          Text("Fullscreen video behind the desktop")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        HStack(alignment: .top, spacing: 16) {
          statusCard
          Spacer(minLength: 0)
        }

        if let errorText {
          Text(errorText)
            .font(.callout)
            .foregroundStyle(.red)
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Set from library")
            .font(.headline)
          let ready = store.items.filter(\.isDownloaded)
          if ready.isEmpty {
            Text("Download a video in Library first.")
              .font(.callout)
              .foregroundStyle(.secondary)
          } else {
            ForEach(ready) { item in
              Button {
                apply(item)
              } label: {
                HStack {
                  Image(systemName: "film")
                  Text(item.displayTitle ?? item.youtubeURL)
                    .lineLimit(1)
                  Spacer()
                  Text("Play")
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                )
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear { store.refreshDownloadedState() }
  }

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        Image(systemName: wallpaper.isRunning ? "play.circle.fill" : "pause.circle")
          .font(.title)
          .foregroundStyle(wallpaper.isRunning ? .green : .secondary)
        VStack(alignment: .leading, spacing: 4) {
          Text(wallpaper.isRunning ? "Backdrop active" : "Backdrop off")
            .font(.title3.weight(.semibold))
          Text(wallpaper.isRunning ? "Video is rendering behind Finder and windows." : "Start a clip from the list below or Library.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Button("Stop video backdrop") {
        wallpaper.stop()
      }
      .disabled(!wallpaper.isRunning)
      .buttonStyle(.borderedProminent)
      .tint(.red.opacity(0.85))
    }
    .padding(18)
    .frame(maxWidth: 400, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
    )
  }

  private func apply(_ item: VideoItem) {
    errorText = nil
    guard let file = store.resolvedFileURL(for: item) else {
      errorText = "Missing file on disk."
      store.refreshDownloadedState()
      return
    }
    wallpaper.playVideo(at: file)
  }
}
