import SwiftUI

/// Blocks the dashboard until the user completes GitHub sign-in (device flow).
struct GitHubLoginGateOverlay: View {
  @ObservedObject var session: GitHubSession

  var body: some View {
    ZStack {
      Color.black.opacity(0.55)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 16) {
        Text("Sign in with GitHub")
          .font(.title2.weight(.bold))

        Text(
          "TubeBackdrop needs a GitHub account before you can use the app. "
            + "Permissions follow your GitHub App registration (user identity)."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        if !GitHubOAuthConfig.isConfigured {
          Text(
            "Configure TUBEBACKDROP_GITHUB_CLIENT_ID (Xcode scheme environment) "
              + "or set embeddedClientID in GitHubOAuthConfig.swift. "
              + "For a GitHub App: Developer settings → your app → enable Device flow."
          )
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
        }

        if let err = session.authErrorMessage, !err.isEmpty {
          Text(err)
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }

        if session.isSigningIn {
          HStack(spacing: 12) {
            ProgressView()
              .scaleEffect(0.9)
            Text("Complete authorization in your browser, then return here.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }

        HStack(spacing: 12) {
          Button {
            session.signIn()
          } label: {
            Label("Continue with GitHub", systemImage: "chevron.right.2")
          }
          .keyboardShortcut(.return, modifiers: [])
          .disabled(session.isSigningIn || !GitHubOAuthConfig.isConfigured)

          if session.isSigningIn {
            Button("Cancel") {
              session.cancelSignIn()
            }
            .keyboardShortcut(.escape, modifiers: [])
          }
        }
        .padding(.top, 4)
      }
      .padding(28)
      .frame(width: 420, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color(nsColor: .windowBackgroundColor))
          .shadow(color: .black.opacity(0.25), radius: 28, y: 10)
      )
    }
    .transition(.opacity)
    .animation(.easeOut(duration: 0.2), value: session.isSigningIn)
  }
}
