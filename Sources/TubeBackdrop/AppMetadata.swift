import Foundation

/// Used when `CFBundleShortVersionString` is missing (common for SwiftPM executables without Info.plist).
enum AppMetadata {
  static let marketingVersion = "1.0.0"
}
