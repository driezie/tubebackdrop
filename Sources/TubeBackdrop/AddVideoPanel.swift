import SwiftUI

struct AddVideoPanel: View {
  @EnvironmentObject private var store: VideoStore

  @State private var urlField = ""
  @State private var errorText: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Add video")
            .font(.largeTitle.weight(.bold))
          Text("Paste a YouTube URL. It is saved to your library; download from Library when ready.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 10) {
            TextField("https://www.youtube.com/watch?v=…", text: $urlField)
              .textFieldStyle(.roundedBorder)
              .font(.body)
              .onSubmit { addURL() }

            Button("Add to library") { addURL() }
              .keyboardShortcut(.return, modifiers: [])
          }

          if YouTubeDownloader.findYtDlp() == nil {
            Label(
              "yt-dlp not found. Install with: brew install yt-dlp ffmpeg",
              systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
            .font(.callout)
          }

          if let errorText {
            Text(errorText)
              .font(.callout)
              .foregroundStyle(.red)
          }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.background.opacity(0.65))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )

        Text("Tip: Press ⌘K anytime to search the library or paste a link.")
          .font(.callout)
          .foregroundStyle(.tertiary)
      }
      .padding(24)
      .frame(maxWidth: 560, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
  }

  private func addURL() {
    errorText = nil
    store.addYouTubeURL(urlField)
    urlField = ""
  }
}
