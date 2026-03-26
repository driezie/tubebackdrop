import Foundation
import SwiftUI

/// Thread-safe flag for device-flow polling (read from URLSession continuations).
private final class OAuthCancellationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  func cancel() {
    lock.lock()
    cancelled = true
    lock.unlock()
  }

  func isCancelled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
}

@MainActor
final class GitHubSession: ObservableObject {
  @Published private(set) var isSignedIn = false
  @Published private(set) var login: String?
  @Published var authErrorMessage: String?
  @Published private(set) var isSigningIn = false

  private var signInTask: Task<Void, Never>?
  private var activeCancellation: OAuthCancellationBox?

  private let userDefaultsKey = "githubSession.login"

  init() {
    restoreFromKeychain()
  }

  func restoreFromKeychain() {
    guard let _ = GitHubTokenKeychain.read() else {
      isSignedIn = false
      login = nil
      UserDefaults.standard.removeObject(forKey: userDefaultsKey)
      return
    }
    isSignedIn = true
    login = UserDefaults.standard.string(forKey: userDefaultsKey)
  }

  func signIn() {
    authErrorMessage = nil
    let box = OAuthCancellationBox()
    activeCancellation = box
    signInTask?.cancel()
    signInTask = Task { await self.runDeviceFlow(cancellation: box) }
  }

  func cancelSignIn() {
    activeCancellation?.cancel()
    signInTask?.cancel()
    isSigningIn = false
  }

  func signOut() {
    activeCancellation?.cancel()
    signInTask?.cancel()
    signInTask = nil
    try? GitHubTokenKeychain.delete()
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    isSignedIn = false
    login = nil
    authErrorMessage = nil
    isSigningIn = false
  }

  private func runDeviceFlow(cancellation: OAuthCancellationBox) async {
    let clientID = GitHubOAuthConfig.clientID
    guard GitHubOAuthConfig.isConfigured else {
      authErrorMessage =
        "Set your GitHub OAuth App Client ID: add environment variable TUBEBACKDROP_GITHUB_CLIENT_ID "
        + "or edit GitHubOAuthConfig."
      return
    }

    isSigningIn = true
    defer { isSigningIn = false }

    do {
      let start = try await GitHubDeviceOAuthClient.requestDeviceCode(
        clientID: clientID,
        scope: GitHubOAuthConfig.oauthScope
      )

      let openURL = start.verificationURLComplete ?? start.verificationURL
      GitHubDeviceOAuthClient.openVerificationURL(openURL)

      let token = try await GitHubDeviceOAuthClient.pollForAccessToken(
        clientID: clientID,
        deviceCode: start.deviceCode,
        expiresAt: start.expiresAt,
        baseInterval: start.intervalSeconds,
        shouldCancel: {
          Task.isCancelled || cancellation.isCancelled()
        }
      )

      try GitHubTokenKeychain.save(token)
      let ghLogin = try await GitHubDeviceOAuthClient.fetchLogin(accessToken: token)
      UserDefaults.standard.set(ghLogin, forKey: userDefaultsKey)
      login = ghLogin
      isSignedIn = true
      authErrorMessage = nil
    } catch is CancellationError {
      authErrorMessage = nil
    } catch let e as GitHubDeviceOAuthClient.OAuthError {
      authErrorMessage = e.localizedDescription
    } catch {
      authErrorMessage = error.localizedDescription
    }
  }
}
