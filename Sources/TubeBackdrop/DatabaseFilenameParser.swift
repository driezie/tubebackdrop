import Foundation

struct ParsedDatabaseFilename: Equatable {
  var projectSlug: String
  var environment: DatabaseEnvironment?
  var dateLabel: String?
  var fileExtension: String
}

enum DatabaseFilenameParser {
  /// Parses names like `vanreeaccountants_staging_25mar.sql` → project, env, date token, extension.
  static func parse(filename: String) -> ParsedDatabaseFilename {
    let ns = filename as NSString
    let base = ns.deletingPathExtension
    let ext = ns.pathExtension.lowercased()
    let parts = base.split(separator: "_").map(String.init)

    guard parts.count >= 3 else {
      return ParsedDatabaseFilename(
        projectSlug: base,
        environment: nil,
        dateLabel: nil,
        fileExtension: ext
      )
    }

    let dateCandidate = parts[parts.count - 1]
    let envCandidate = parts[parts.count - 2]
    let projectSlug = parts[0..<(parts.count - 2)].joined(separator: "_")

    let dateLabel = looksLikeDateToken(dateCandidate) ? dateCandidate.lowercased() : nil
    let env = mapEnvironment(envCandidate)

    return ParsedDatabaseFilename(
      projectSlug: projectSlug,
      environment: env,
      dateLabel: dateLabel,
      fileExtension: ext
    )
  }

  static func displayProjectName(from slug: String) -> String {
    let t = slug.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return t }
    return t.prefix(1).uppercased() + t.dropFirst()
  }

  private static func looksLikeDateToken(_ s: String) -> Bool {
    let lower = s.lowercased()
    // e.g. 25mar, 5mar, 20250325, 25-mar
    if lower.range(of: #"^\d{1,2}[a-z]{3,}$"#, options: .regularExpression) != nil { return true }
    if lower.range(of: #"^\d{8}$"#, options: .regularExpression) != nil { return true }
    if lower.range(of: #"^\d{1,2}-[a-z]{3,}$"#, options: .regularExpression) != nil { return true }
    return false
  }

  private static func mapEnvironment(_ raw: String) -> DatabaseEnvironment? {
    let k = raw.lowercased()
    switch k {
    case "localhost", "local": return .localhost
    case "dev", "development": return .development
    case "staging", "stage": return .staging
    case "live", "production", "prod": return .live
    default: return nil
    }
  }
}
