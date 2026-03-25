import Foundation

enum DatabaseEnvironment: String, Codable, CaseIterable, Identifiable {
  case localhost
  case development
  case staging
  case live

  var id: String { rawValue }

  var title: String {
    switch self {
    case .localhost: return "Localhost"
    case .development: return "Development"
    case .staging: return "Staging"
    case .live: return "Live"
    }
  }

  var shortLabel: String {
    switch self {
    case .localhost: return "local"
    case .development: return "dev"
    case .staging: return "staging"
    case .live: return "live"
    }
  }
}

struct MediaProject: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
}

struct MediaCategory: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
}

/// User-imported data file (e.g. SQL dump, SQLite) with project / environment / category tags.
struct LinkedDatabase: Identifiable, Codable, Equatable {
  var id: UUID
  var displayName: String
  /// Security-scoped bookmark data for the file on disk.
  var fileBookmarkData: Data
  var projectId: UUID
  var environment: DatabaseEnvironment
  var categoryIds: [UUID]
  /// Original filename (e.g. `vanreeaccountants_staging_25mar.sql`).
  var sourceFilename: String
  /// Lowercased extension without dot (`sql`, `sqlite`, `json`, …).
  var fileExtension: String
  /// Parsed date token from filename (e.g. `25mar`).
  var dateLabel: String?
  /// When the file was added in the app (used for “latest”).
  var addedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case displayName
    case fileBookmarkData
    case projectId
    case environment
    case categoryIds
    case sourceFilename
    case fileExtension
    case dateLabel
    case addedAt
  }

  init(
    id: UUID,
    displayName: String,
    fileBookmarkData: Data,
    projectId: UUID,
    environment: DatabaseEnvironment,
    categoryIds: [UUID],
    sourceFilename: String,
    fileExtension: String,
    dateLabel: String?,
    addedAt: Date
  ) {
    self.id = id
    self.displayName = displayName
    self.fileBookmarkData = fileBookmarkData
    self.projectId = projectId
    self.environment = environment
    self.categoryIds = categoryIds
    self.sourceFilename = sourceFilename
    self.fileExtension = fileExtension
    self.dateLabel = dateLabel
    self.addedAt = addedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    displayName = try c.decode(String.self, forKey: .displayName)
    fileBookmarkData = try c.decode(Data.self, forKey: .fileBookmarkData)
    projectId = try c.decode(UUID.self, forKey: .projectId)
    environment = try c.decode(DatabaseEnvironment.self, forKey: .environment)
    categoryIds = try c.decodeIfPresent([UUID].self, forKey: .categoryIds) ?? []
    sourceFilename = try c.decodeIfPresent(String.self, forKey: .sourceFilename) ?? ""
    fileExtension = try c.decodeIfPresent(String.self, forKey: .fileExtension) ?? ""
    dateLabel = try c.decodeIfPresent(String.self, forKey: .dateLabel)
    addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(displayName, forKey: .displayName)
    try c.encode(fileBookmarkData, forKey: .fileBookmarkData)
    try c.encode(projectId, forKey: .projectId)
    try c.encode(environment, forKey: .environment)
    try c.encode(categoryIds, forKey: .categoryIds)
    try c.encode(sourceFilename, forKey: .sourceFilename)
    try c.encode(fileExtension, forKey: .fileExtension)
    try c.encodeIfPresent(dateLabel, forKey: .dateLabel)
    try c.encode(addedAt, forKey: .addedAt)
  }
}
