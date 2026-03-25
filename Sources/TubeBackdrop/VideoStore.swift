import Foundation

@MainActor
final class VideoStore: ObservableObject {
  @Published private(set) var items: [VideoItem] = []
  @Published private(set) var projects: [MediaProject] = []
  @Published private(set) var categories: [MediaCategory] = []
  @Published private(set) var linkedDatabases: [LinkedDatabase] = []
  @Published var downloadMessage: String?
  /// 0...1 while a download is active; `nil` when idle.
  @Published var downloadProgress: Double?

  private let fileManager = FileManager.default
  private var libraryDir: URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = base.appendingPathComponent("TubeBackdrop", isDirectory: true)
    try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private var metaURL: URL {
    libraryDir.appendingPathComponent("library.json")
  }

  private var organizationURL: URL {
    libraryDir.appendingPathComponent("organization.json")
  }

  init() {
    load()
    loadOrganization()
    ensureDefaultProject()
  }

  func videosDirectory() -> URL {
    let v = libraryDir.appendingPathComponent("videos", isDirectory: true)
    try? fileManager.createDirectory(at: v, withIntermediateDirectories: true)
    return v
  }

  func resolvedFileURL(for item: VideoItem) -> URL? {
    guard let name = item.localFilename else { return nil }
    let url = videosDirectory().appendingPathComponent(name)
    return fileManager.fileExists(atPath: url.path) ? url : nil
  }

  func addYouTubeURL(_ raw: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let item = VideoItem(id: UUID(), youtubeURL: trimmed, localFilename: nil, displayTitle: nil)
    items.append(item)
    save()
  }

  func remove(_ item: VideoItem) {
    items.removeAll { $0.id == item.id }
    save()
  }

  func refreshDownloadedState() {
    for i in items.indices {
      if let name = items[i].localFilename {
        let path = videosDirectory().appendingPathComponent(name).path
        if !fileManager.fileExists(atPath: path) {
          items[i].localFilename = nil
        }
      }
    }
    save()
  }

  func markDownloaded(id: UUID, filename: String, title: String?) {
    guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
    items[idx].localFilename = filename
    if let title, !title.isEmpty { items[idx].displayTitle = title }
    save()
  }

  private func load() {
    guard let data = try? Data(contentsOf: metaURL),
          let decoded = try? JSONDecoder().decode([VideoItem].self, from: data)
    else { return }
    items = decoded
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(items) else { return }
    try? data.write(to: metaURL)
  }

  // MARK: - Organization

  func ensureDefaultProject() {
    if projects.isEmpty {
      projects = [MediaProject(id: UUID(), name: "Default")]
      saveOrganization()
    }
  }

  func addProject(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    projects.append(MediaProject(id: UUID(), name: trimmed))
    saveOrganization()
  }

  /// Returns existing project id (case-insensitive match) or creates a new project.
  func findOrCreateProject(named raw: String) -> UUID {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = trimmed.isEmpty ? "Imported" : trimmed
    if let existing = projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
      return existing.id
    }
    let p = MediaProject(id: UUID(), name: name)
    projects.append(p)
    saveOrganization()
    return p.id
  }

  func removeProject(id: UUID) {
    guard projects.contains(where: { $0.id == id }) else { return }
    projects.removeAll { $0.id == id }
    if projects.isEmpty {
      projects = [MediaProject(id: UUID(), name: "Default")]
    }
    let target = projects[0].id
    for i in items.indices where items[i].projectId == id {
      items[i].projectId = target
    }
    for i in linkedDatabases.indices where linkedDatabases[i].projectId == id {
      linkedDatabases[i].projectId = target
    }
    saveOrganization()
    save()
  }

  func addCategory(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    categories.append(MediaCategory(id: UUID(), name: trimmed))
    saveOrganization()
  }

  func removeCategory(id: UUID) {
    categories.removeAll { $0.id == id }
    for i in items.indices where items[i].categoryId == id {
      items[i].categoryId = nil
    }
    for i in linkedDatabases.indices {
      linkedDatabases[i].categoryIds.removeAll { $0 == id }
    }
    saveOrganization()
    save()
  }

  func project(for id: UUID?) -> MediaProject? {
    guard let id else { return nil }
    return projects.first { $0.id == id }
  }

  func category(for id: UUID?) -> MediaCategory? {
    guard let id else { return nil }
    return categories.first { $0.id == id }
  }

  func setVideoOrganization(
    itemId: UUID,
    categoryId: UUID?,
    projectId: UUID?,
    linkedDatabaseId: UUID?,
    environment: DatabaseEnvironment?
  ) {
    guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
    items[idx].categoryId = categoryId
    items[idx].projectId = projectId
    items[idx].linkedDatabaseId = linkedDatabaseId
    items[idx].environment = environment
    save()
  }

  func addLinkedDatabase(
    displayName: String,
    fileURL: URL,
    projectId: UUID,
    environment: DatabaseEnvironment,
    categoryIds: [UUID],
    sourceFilename: String,
    fileExtension: String,
    dateLabel: String?
  ) throws {
    let didStart = fileURL.startAccessingSecurityScopedResource()
    defer {
      if didStart { fileURL.stopAccessingSecurityScopedResource() }
    }
    let data = try fileURL.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = trimmed.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : trimmed
    let src = sourceFilename.isEmpty ? fileURL.lastPathComponent : sourceFilename
    let ext =
      fileExtension.isEmpty
      ? (fileURL.pathExtension.lowercased())
      : fileExtension.lowercased()
    linkedDatabases.append(
      LinkedDatabase(
        id: UUID(),
        displayName: name,
        fileBookmarkData: data,
        projectId: projectId,
        environment: environment,
        categoryIds: categoryIds,
        sourceFilename: src,
        fileExtension: ext,
        dateLabel: dateLabel,
        addedAt: Date()
      )
    )
    saveOrganization()
  }

  func removeLinkedDatabase(id: UUID) {
    linkedDatabases.removeAll { $0.id == id }
    for i in items.indices where items[i].linkedDatabaseId == id {
      items[i].linkedDatabaseId = nil
    }
    saveOrganization()
    save()
  }

  func updateLinkedDatabase(
    id: UUID,
    displayName: String,
    projectId: UUID,
    environment: DatabaseEnvironment,
    categoryIds: [UUID],
    dateLabel: String?
  ) {
    guard let idx = linkedDatabases.firstIndex(where: { $0.id == id }) else { return }
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { linkedDatabases[idx].displayName = trimmed }
    linkedDatabases[idx].projectId = projectId
    linkedDatabases[idx].environment = environment
    linkedDatabases[idx].categoryIds = categoryIds
    linkedDatabases[idx].dateLabel = dateLabel
    saveOrganization()
  }

  /// Name filter (display, source filename, project name, extension), optional environment, then date handling.
  func toolbarDatabaseMatches(
    nameQuery: String,
    environment: DatabaseEnvironment?,
    dateToken: String
  ) -> [LinkedDatabase] {
    let q = nameQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var list = linkedDatabases
    if !q.isEmpty {
      list = list.filter { link in
        if link.displayName.lowercased().contains(q) { return true }
        if link.sourceFilename.lowercased().contains(q) { return true }
        if link.fileExtension.lowercased().contains(q) { return true }
        if let proj = project(for: link.projectId), proj.name.lowercased().contains(q) { return true }
        if let dl = link.dateLabel, dl.lowercased().contains(q) { return true }
        return false
      }
    }
    if let env = environment {
      list = list.filter { $0.environment == env }
    }
    switch dateToken {
    case "__all__":
      return list.sorted { $0.addedAt > $1.addedAt }
    case "__latest__":
      var best: [String: LinkedDatabase] = [:]
      for link in list {
        let k = "\(link.projectId.uuidString)|\(link.environment.rawValue)"
        if let cur = best[k] {
          if link.addedAt > cur.addedAt { best[k] = link }
        } else {
          best[k] = link
        }
      }
      return Array(best.values).sorted { $0.addedAt > $1.addedAt }
    default:
      let want = dateToken.lowercased()
      return list
        .filter { ($0.dateLabel ?? "").lowercased() == want }
        .sorted { $0.addedAt > $1.addedAt }
    }
  }

  /// Distinct non-empty date labels among links (e.g. for picker), sorted lexicographically.
  func distinctDateLabels(in links: [LinkedDatabase]) -> [String] {
    let labels = links.compactMap(\.dateLabel).filter { !$0.isEmpty }
    return Array(Set(labels)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  func resolvedFileURL(for linked: LinkedDatabase) -> URL? {
    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: linked.fileBookmarkData,
        options: [.withSecurityScope, .withoutUI],
        bookmarkDataIsStale: &stale
      )
    else { return nil }
    if stale {
      // Bookmark stale — user may need to re-pick file; still try returning url
    }
    return url
  }

  private func loadOrganization() {
    guard let data = try? Data(contentsOf: organizationURL),
          let decoded = try? JSONDecoder().decode(OrganizationSnapshot.self, from: data)
    else { return }
    projects = decoded.projects
    categories = decoded.categories
    linkedDatabases = decoded.linkedDatabases
  }

  private func saveOrganization() {
    let snap = OrganizationSnapshot(
      projects: projects,
      categories: categories,
      linkedDatabases: linkedDatabases
    )
    guard let data = try? JSONEncoder().encode(snap) else { return }
    try? data.write(to: organizationURL)
  }
}
