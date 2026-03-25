import SwiftUI

struct AddVideoPanel: View {
  @EnvironmentObject private var store: VideoStore

  @State private var urlField = ""
  @State private var errorText: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Add video")
            .font(.title.weight(.bold))
          Text("Paste a YouTube URL")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
      }
      .padding(24)
      .frame(maxWidth: 560, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func addURL() {
    errorText = nil
    store.addYouTubeURL(urlField)
    urlField = ""
  }
}
