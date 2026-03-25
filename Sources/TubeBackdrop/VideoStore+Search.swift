import Foundation

extension VideoStore {
  func itemsMatchingSearch(_ query: String) -> [VideoItem] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return [] }
    return items.filter { item in
      matchesVideoItem(item, query: q)
    }
  }

  private func matchesVideoItem(_ item: VideoItem, query q: String) -> Bool {
    if (item.displayTitle ?? "").lowercased().contains(q) { return true }
    if item.youtubeURL.lowercased().contains(q) { return true }
    if let cid = item.categoryId, let cat = category(for: cid), cat.name.lowercased().contains(q) {
      return true
    }
    if let pid = item.projectId, let proj = project(for: pid), proj.name.lowercased().contains(q) {
      return true
    }
    if let env = item.environment, env.title.lowercased().contains(q) { return true }
    if let env = item.environment, env.rawValue.contains(q) { return true }
    if let lid = item.linkedDatabaseId,
       let link = linkedDatabases.first(where: { $0.id == lid }),
       link.displayName.lowercased().contains(q)
    {
      return true
    }
    return false
  }

  func linkedDatabasesMatchingSearch(_ query: String) -> [LinkedDatabase] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return [] }
    return linkedDatabases.filter { link in
      if link.displayName.lowercased().contains(q) { return true }
      if link.sourceFilename.lowercased().contains(q) { return true }
      if link.fileExtension.lowercased().contains(q) { return true }
      if let dl = link.dateLabel, dl.lowercased().contains(q) { return true }
      if link.environment.title.lowercased().contains(q) { return true }
      if link.environment.rawValue.contains(q) { return true }
      if let proj = project(for: link.projectId), proj.name.lowercased().contains(q) { return true }
      for cid in link.categoryIds {
        if let cat = category(for: cid), cat.name.lowercased().contains(q) { return true }
      }
      return false
    }
  }

  func projectsMatchingSearch(_ query: String) -> [MediaProject] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return [] }
    return projects.filter { $0.name.lowercased().contains(q) }
  }

  func categoriesMatchingSearch(_ query: String) -> [MediaCategory] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return [] }
    return categories.filter { $0.name.lowercased().contains(q) }
  }
}
