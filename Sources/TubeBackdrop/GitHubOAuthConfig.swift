import Foundation

/// **GitHub App** or classic **OAuth App** — enable [Device flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow)
/// in the app settings. On-device authorization uses only the Client ID (never embed a client secret).
enum GitHubOAuthConfig {
  /// Set to `true` to show the sign-in overlay before the dashboard and the GitHub block in Settings.
  static let isLoginGateEnabled = false

  /// Prefer `TUBEBACKDROP_GITHUB_CLIENT_ID` in the environment (Xcode scheme, launchctl, or `swift run`).
  static var clientID: String {
    if let env = ProcessInfo.processInfo.environment["TUBEBACKDROP_GITHUB_CLIENT_ID"],
       !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return env.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return embeddedClientID
  }

  /// TubeBackdrop GitHub App — public Client ID from GitHub → Settings → Developer settings → GitHub Apps.
  private static let embeddedClientID = "Iv23li6DVLKA8HV1whHt"

  static var isConfigured: Bool { !clientID.isEmpty }

  /// OAuth App only: e.g. `read:user`. **GitHub Apps** use app permissions instead — leave empty.
  static let oauthScope = ""
}
