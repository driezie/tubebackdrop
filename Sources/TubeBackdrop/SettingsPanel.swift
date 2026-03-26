import AppKit
import SwiftUI

struct SettingsPanel: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var githubSession: GitHubSession

  @State private var profileURLField = ""
  @State private var savedNotice = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Settings")
            .font(.title.weight(.bold))
          Text("Link a YouTube channel or profile for quick reference")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        if GitHubOAuthConfig.isLoginGateEnabled {
          VStack(alignment: .leading, spacing: 12) {
            Text("GitHub account")
              .font(.headline)

            if let login = githubSession.login {
              Text("Signed in as \(login)")
                .font(.body)
              Button("Sign out of GitHub", role: .destructive) {
                githubSession.signOut()
              }
            } else if githubSession.isSignedIn {
              Text("Signed in")
                .font(.body)
              Button("Sign out of GitHub", role: .destructive) {
                githubSession.signOut()
              }
            } else {
              Text("Not signed in")
                .font(.body)
                .foregroundStyle(.secondary)
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

        VStack(alignment: .leading, spacing: 12) {
          Text("Linked profile")
            .font(.headline)

          TextField(
            "https://www.youtube.com/@yourchannel or /channel/…",
            text: $profileURLField
          )
          .textFieldStyle(.roundedBorder)
          .font(.body)

          Text(
            "Paste the full URL from your browser when viewing the channel home page. " +
              "This is stored only on your Mac."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          HStack(spacing: 10) {
            Button("Save link") {
              store.setLinkedYouTubeProfileURL(profileURLField)
              savedNotice = true
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                savedNotice = false
              }
            }
            .keyboardShortcut(.return, modifiers: [.command])

            if store.linkedYouTubeProfileURL != nil {
              Button("Open in browser") {
                openLinkedProfile()
              }

              Button("Clear link", role: .destructive) {
                store.setLinkedYouTubeProfileURL(nil)
                profileURLField = ""
              }
            }
          }

          if savedNotice {
            Text("Saved")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let linked = store.linkedYouTubeProfileURL {
            Text("Current: \(linked)")
              .font(.caption)
              .foregroundStyle(.tertiary)
              .textSelection(.enabled)
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
    .onAppear {
      profileURLField = store.linkedYouTubeProfileURL ?? ""
    }
  }

  private func openLinkedProfile() {
    guard let s = store.linkedYouTubeProfileURL?.trimmingCharacters(in: .whitespacesAndNewlines),
          !s.isEmpty,
          let url = URL(string: s), url.scheme != nil
    else { return }
    NSWorkspace.shared.open(url)
  }
}
