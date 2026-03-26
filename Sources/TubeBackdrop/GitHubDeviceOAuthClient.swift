import AppKit
import Foundation

/// OAuth 2.0 device authorization (RFC 8628) against GitHub.
enum GitHubDeviceOAuthClient {
  struct DeviceStart: Sendable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let verificationURLComplete: URL?
    let expiresAt: Date
    let intervalSeconds: TimeInterval
  }

  enum OAuthError: Error, LocalizedError {
    case http(Int)
    case decoding
    case github(String, String?)
    case missingClientID

    var errorDescription: String? {
      switch self {
      case .http(let code): return "GitHub returned HTTP \(code)."
      case .decoding: return "Could not read GitHub’s response."
      case .github(let code, let description):
        switch code {
        case "device_flow_disabled":
          return
            "Device Flow is off for this app. On GitHub: Settings → Developer settings → "
            + "GitHub Apps → TubeBackdrop → enable “Enable Device Flow”, then click Save."
        case "incorrect_client_credentials":
          return description
            ?? "Unknown Client ID. Check TUBEBACKDROP_GITHUB_CLIENT_ID and GitHubOAuthConfig."
        default:
          return description ?? "GitHub error: \(code)."
        }
      case .missingClientID: return "GitHub Client ID is not configured."
      }
    }
  }

  /// GitHub returns 4xx with JSON `{ error, error_description }` for OAuth/device endpoints.
  private static func oauthErrorFromResponseBody(_ data: Data) -> OAuthError? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let err = json["error"] as? String
    else { return nil }
    let description = json["error_description"] as? String
    return .github(err, description)
  }

  private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
  private static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
  private static let userAPI = URL(string: "https://api.github.com/user")!

  static func requestDeviceCode(clientID: String, scope: String) async throws -> DeviceStart {
    guard !clientID.isEmpty else { throw OAuthError.missingClientID }

    var request = URLRequest(url: deviceCodeURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let encodedClient = clientID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientID
    // GitHub App device flow: `client_id` only. Classic OAuth apps may add `scope`.
    var body = "client_id=\(encodedClient)"
    let trimmedScope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedScope.isEmpty {
      let encodedScope =
        trimmedScope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedScope
      body += "&scope=\(encodedScope)"
    }
    request.httpBody = body.data(using: .utf8)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw OAuthError.decoding }
    guard (200 ..< 300).contains(http.statusCode) else {
      if let oauthErr = oauthErrorFromResponseBody(data) { throw oauthErr }
      throw OAuthError.http(http.statusCode)
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let deviceCode = json["device_code"] as? String,
      let userCode = json["user_code"] as? String,
      let verificationURI = json["verification_uri"] as? String,
      let verificationURL = URL(string: verificationURI),
      let expiresIn = json["expires_in"] as? Int
    else { throw OAuthError.decoding }

    let interval = (json["interval"] as? Int).map { TimeInterval($0) } ?? 5
    let completeString = json["verification_uri_complete"] as? String
    let completeURL = completeString.flatMap { URL(string: $0) }

    let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    return DeviceStart(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationURL: verificationURL,
      verificationURLComplete: completeURL,
      expiresAt: expiresAt,
      intervalSeconds: max(5, interval)
    )
  }

  /// Polls until the user authorizes, denies, or the code expires. Pass `shouldCancel` to abort from the UI.
  static func pollForAccessToken(
    clientID: String,
    deviceCode: String,
    expiresAt: Date,
    baseInterval: TimeInterval,
    shouldCancel: @Sendable @escaping () -> Bool
  ) async throws -> String {
    guard !clientID.isEmpty else { throw OAuthError.missingClientID }

    var interval = baseInterval

    while Date() < expiresAt {
      if shouldCancel() {
        throw CancellationError()
      }

      try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

      if shouldCancel() {
        throw CancellationError()
      }

      var request = URLRequest(url: accessTokenURL)
      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      let grant =
        "urn:ietf:params:oauth:grant-type:device_code"
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      let encodedDevice = deviceCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceCode
      let encodedClient = clientID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientID
      let body = "client_id=\(encodedClient)&device_code=\(encodedDevice)&grant_type=\(grant)"
      request.httpBody = body.data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw OAuthError.decoding }

      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw OAuthError.decoding
      }

      if let token = json["access_token"] as? String, !token.isEmpty {
        return token
      }

      let error = json["error"] as? String ?? "unknown_error"
      let description = json["error_description"] as? String

      switch error {
      case "authorization_pending":
        continue
      case "slow_down":
        interval += 5
        continue
      case "expired_token", "token_expired":
        throw OAuthError.github(error, description)
      case "access_denied":
        throw OAuthError.github(error, description ?? "You declined access.")
      default:
        if (200 ..< 300).contains(http.statusCode) {
          throw OAuthError.github(error, description)
        }
        throw OAuthError.http(http.statusCode)
      }
    }

    throw OAuthError.github("expired_token", "The device code expired. Try signing in again.")
  }

  static func fetchLogin(accessToken: String) async throws -> String {
    var request = URLRequest(url: userAPI)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
      throw OAuthError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let login = json["login"] as? String, !login.isEmpty
    else { throw OAuthError.decoding }
    return login
  }

  static func openVerificationURL(_ url: URL) {
    NSWorkspace.shared.open(url)
  }
}
