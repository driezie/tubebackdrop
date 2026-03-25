import Foundation

struct VideoItem: Identifiable, Codable, Equatable {
  var id: UUID
  var youtubeURL: String
  var localFilename: String?
  var displayTitle: String?
  /// Library organization — optional links to projects, categories, imported DB record, and environment.
  var categoryId: UUID?
  var projectId: UUID?
  var linkedDatabaseId: UUID?
  var environment: DatabaseEnvironment?

  var isDownloaded: Bool {
    localFilename != nil
  }

  enum CodingKeys: String, CodingKey {
    case id
    case youtubeURL
    case localFilename
    case displayTitle
    case categoryId
    case projectId
    case linkedDatabaseId
    case environment
  }

  init(
    id: UUID,
    youtubeURL: String,
    localFilename: String? = nil,
    displayTitle: String? = nil,
    categoryId: UUID? = nil,
    projectId: UUID? = nil,
    linkedDatabaseId: UUID? = nil,
    environment: DatabaseEnvironment? = nil
  ) {
    self.id = id
    self.youtubeURL = youtubeURL
    self.localFilename = localFilename
    self.displayTitle = displayTitle
    self.categoryId = categoryId
    self.projectId = projectId
    self.linkedDatabaseId = linkedDatabaseId
    self.environment = environment
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    youtubeURL = try c.decode(String.self, forKey: .youtubeURL)
    localFilename = try c.decodeIfPresent(String.self, forKey: .localFilename)
    displayTitle = try c.decodeIfPresent(String.self, forKey: .displayTitle)
    categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
    projectId = try c.decodeIfPresent(UUID.self, forKey: .projectId)
    linkedDatabaseId = try c.decodeIfPresent(UUID.self, forKey: .linkedDatabaseId)
    environment = try c.decodeIfPresent(DatabaseEnvironment.self, forKey: .environment)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(youtubeURL, forKey: .youtubeURL)
    try c.encodeIfPresent(localFilename, forKey: .localFilename)
    try c.encodeIfPresent(displayTitle, forKey: .displayTitle)
    try c.encodeIfPresent(categoryId, forKey: .categoryId)
    try c.encodeIfPresent(projectId, forKey: .projectId)
    try c.encodeIfPresent(linkedDatabaseId, forKey: .linkedDatabaseId)
    try c.encodeIfPresent(environment, forKey: .environment)
  }
}
