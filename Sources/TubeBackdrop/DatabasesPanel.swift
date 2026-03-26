import SwiftUI
import UniformTypeIdentifiers

struct DatabasesPanel: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var chrome: AppChromeState

  @State private var newProjectName = ""
  @State private var newCategoryName = ""
  @State private var importDraft: DatabaseImportDraft?
  @State private var editingLink: LinkedDatabase?
  @State private var showFileImporter = false
  @State private var listFilterText = ""
  @State private var filterProjectId: UUID?
  @State private var filterEnvironment: DatabaseEnvironment?
  @State private var filterExtension: String = ""
  @State private var sortMode: LinkedDatabaseSortMode = .addedNewest

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        projectsAndCategories
        linkedList
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
      handleDropProviders(providers)
    }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: [
        .item, .data, .json,
        UTType(filenameExtension: "sqlite") ?? .data,
        UTType(filenameExtension: "sql") ?? .data,
      ],
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let urls):
        importDraft = DatabaseImportDraft(urls: urls)
      case .failure:
        break
      }
    }
    .sheet(item: $importDraft) { draft in
      ImportDatabaseSheet(urls: draft.urls) {
        importDraft = nil
      }
      .environmentObject(store)
    }
    .sheet(item: $editingLink) { link in
      EditLinkedDatabaseSheet(link: link) {
        editingLink = nil
      }
      .environmentObject(store)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Databases")
        .font(.title.weight(.bold))
      Text("Projects, files, drag-and-drop · ⌘K")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Button {
          showFileImporter = true
        } label: {
          Label("Upload database…", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderedProminent)

        Button {
          chrome.sidebarSelection = .library
        } label: {
          Label("Open library", systemImage: "square.stack.fill")
        }
      }
    }
  }

  private var projectsAndCategories: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Projects & categories")
        .font(.headline)

      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Projects")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          HStack {
            TextField("New project name", text: $newProjectName)
              .textFieldStyle(.roundedBorder)
            Button("Add") {
              store.addProject(name: newProjectName)
              newProjectName = ""
            }
            .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          ForEach(store.projects) { p in
            HStack {
              Text(p.name)
              Spacer()
              if store.projects.count > 1 {
                Button(role: .destructive) {
                  store.removeProject(id: p.id)
                } label: {
                  Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Remove project (items move to first project)")
              }
            }
            .padding(.vertical, 4)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 8) {
          Text("Categories")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          HStack {
            TextField("New category", text: $newCategoryName)
              .textFieldStyle(.roundedBorder)
            Button("Add") {
              store.addCategory(name: newCategoryName)
              newCategoryName = ""
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          ForEach(store.categories) { c in
            HStack {
              Text(c.name)
              Spacer()
              Button(role: .destructive) {
                store.removeCategory(id: c.id)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(16)
      .background(cardBackground)
    }
  }

  private var linkedList: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Connected files")
        .font(.headline)

      if store.linkedDatabases.isEmpty {
        Text("No files yet. Upload or drag .sqlite, .json, .sql, or other data files onto this page.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(cardBackground)
      } else {
        listControls
        VStack(alignment: .leading, spacing: 0) {
          ForEach(filteredAndSortedLinks) { link in
            linkedRow(link)
            Divider()
          }
        }
        .background(cardBackground)
      }
    }
  }

  private var listControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        CustomQueryField(placeholder: "Filter by name, file, project…", text: $listFilterText)
          .frame(minWidth: 200)
        Picker("Project", selection: $filterProjectId) {
          Text("All projects").tag(nil as UUID?)
          ForEach(store.projects) { p in
            Text(p.name).tag(Optional(p.id))
          }
        }
        .frame(minWidth: 140)
        Picker("Environment", selection: $filterEnvironment) {
          Text("All").tag(nil as DatabaseEnvironment?)
          ForEach(DatabaseEnvironment.allCases) { e in
            Text(e.shortLabel).tag(Optional(e))
          }
        }
        .frame(minWidth: 100)
        CustomQueryField(
          placeholder: "Type (.sql)",
          text: $filterExtension,
          systemImage: "doc.badge.ellipsis",
          font: .system(size: 12, weight: .regular)
        )
        .frame(width: 116)
        Picker("Sort", selection: $sortMode) {
          ForEach(LinkedDatabaseSortMode.allCases) { m in
            Text(m.title).tag(m)
          }
        }
        .frame(minWidth: 160)
      }
      .font(.caption)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.quaternary.opacity(0.2))
    )
  }

  private var filteredAndSortedLinks: [LinkedDatabase] {
    let q = listFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var list = store.linkedDatabases
    if !q.isEmpty {
      list = list.filter { link in
        if link.displayName.lowercased().contains(q) { return true }
        if link.sourceFilename.lowercased().contains(q) { return true }
        if link.fileExtension.lowercased().contains(q) { return true }
        if let dl = link.dateLabel, dl.lowercased().contains(q) { return true }
        if let p = store.project(for: link.projectId), p.name.lowercased().contains(q) { return true }
        return false
      }
    }
    if let pid = filterProjectId {
      list = list.filter { $0.projectId == pid }
    }
    if let env = filterEnvironment {
      list = list.filter { $0.environment == env }
    }
    let extNeedle = filterExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      .replacingOccurrences(of: ".", with: "")
    if !extNeedle.isEmpty {
      list = list.filter { $0.fileExtension.lowercased().contains(extNeedle) }
    }
    switch sortMode {
    case .addedNewest:
      list.sort { $0.addedAt > $1.addedAt }
    case .addedOldest:
      list.sort { $0.addedAt < $1.addedAt }
    case .nameAZ:
      list.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    case .project:
      list.sort {
        let a = store.project(for: $0.projectId)?.name ?? ""
        let b = store.project(for: $1.projectId)?.name ?? ""
        return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
      }
    case .environment:
      list.sort { $0.environment.rawValue < $1.environment.rawValue }
    case .fileType:
      list.sort { $0.fileExtension.localizedCaseInsensitiveCompare($1.fileExtension) == .orderedAscending }
    }
    return list
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .fill(Color(nsColor: .controlBackgroundColor))
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
      )
  }

  private func linkedRow(_ link: LinkedDatabase) -> some View {
    let proj = store.project(for: link.projectId)?.name ?? "—"
    let cats = link.categoryIds.compactMap { store.category(for: $0)?.name }.joined(separator: ", ")
    let resolved = store.resolvedFileURL(for: link)

    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(link.displayName)
          .font(.headline)
        Spacer()
        environmentBadge(link.environment)
      }
      Text(proj)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(spacing: 10) {
        if !link.sourceFilename.isEmpty {
          Text(link.sourceFilename)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        if let dl = link.dateLabel, !dl.isEmpty {
          Text(dl)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
        }
        Text("." + (link.fileExtension.isEmpty ? "?" : link.fileExtension))
          .font(.caption2)
          .foregroundStyle(.tertiary)
        Text(link.addedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      if !cats.isEmpty {
        Text(cats)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      if resolved == nil {
        Text("File path is stale or unavailable — re-upload if needed.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
      HStack(spacing: 8) {
        if let url = resolved {
          Button {
            let suggested =
              link.sourceFilename.isEmpty
              ? "\(link.displayName).\(link.fileExtension)"
              : link.sourceFilename
            _ = LinkedDatabaseExporter.saveCopy(sourceURL: url, suggestedFilename: suggested)
          } label: {
            Label("Download…", systemImage: "square.and.arrow.down")
          }
          .buttonStyle(.borderedProminent)
        }
        Button("Edit") {
          editingLink = link
        }
        .buttonStyle(.bordered)
        Button(role: .destructive) {
          store.removeLinkedDatabase(id: link.id)
        } label: {
          Text("Remove")
        }
      }
    }
    .padding(14)
  }

  private func environmentBadge(_ env: DatabaseEnvironment) -> some View {
    Text(env.shortLabel.uppercased())
      .font(.caption2.weight(.bold))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(envColor(env).opacity(0.2), in: Capsule())
      .foregroundStyle(envColor(env))
  }

  private func envColor(_ env: DatabaseEnvironment) -> Color {
    switch env {
    case .localhost: return .cyan
    case .development: return .blue
    case .staging: return .orange
    case .live: return .green
    }
  }

  private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
    var urls: [URL] = []
    let group = DispatchGroup()
    for p in providers {
      group.enter()
      _ = p.loadObject(ofClass: URL.self) { url, _ in
        DispatchQueue.main.async {
          if let url {
            urls.append(url.standardizedFileURL)
          }
          group.leave()
        }
      }
    }
    group.notify(queue: .main) {
      let unique = Array(Dictionary(grouping: urls, by: { $0.path }).compactMapValues(\.first).values)
      if !unique.isEmpty {
        importDraft = DatabaseImportDraft(urls: unique)
      }
    }
    return true
  }
}

enum LinkedDatabaseSortMode: String, CaseIterable, Identifiable {
  case addedNewest
  case addedOldest
  case nameAZ
  case project
  case environment
  case fileType

  var id: String { rawValue }

  var title: String {
    switch self {
    case .addedNewest: return "Date added (newest)"
    case .addedOldest: return "Date added (oldest)"
    case .nameAZ: return "Name A–Z"
    case .project: return "Project"
    case .environment: return "Environment"
    case .fileType: return "File type"
    }
  }
}

// MARK: - Edit linked database

private struct EditLinkedDatabaseSheet: View {
  @EnvironmentObject private var store: VideoStore

  let link: LinkedDatabase
  let onDone: () -> Void

  @State private var displayName: String = ""
  @State private var dateLabelField: String = ""
  @State private var projectId: UUID?
  @State private var environment: DatabaseEnvironment = .development
  @State private var selectedCategoryIds: Set<UUID> = []

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Edit connection")
        .font(.title2.weight(.bold))

      if !link.sourceFilename.isEmpty {
        Text("File: \(link.sourceFilename)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      TextField("Display name", text: $displayName)
        .textFieldStyle(.roundedBorder)

      TextField("Date label (e.g. 25mar)", text: $dateLabelField)
        .textFieldStyle(.roundedBorder)

      Picker("Project", selection: $projectId) {
        ForEach(store.projects) { p in
          Text(p.name).tag(Optional(p.id))
        }
      }

      Picker("Environment", selection: $environment) {
        ForEach(DatabaseEnvironment.allCases) { e in
          Text(e.title).tag(e)
        }
      }

      Text("Categories")
        .font(.subheadline.weight(.semibold))
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(store.categories) { c in
            Toggle(isOn: bindingForCategory(c.id)) {
              Text(c.name)
            }
          }
        }
      }
      .frame(maxHeight: 160)

      HStack {
        Spacer()
        Button("Cancel", action: onDone)
        Button("Save") {
          let dl = dateLabelField.trimmingCharacters(in: .whitespacesAndNewlines)
          store.updateLinkedDatabase(
            id: link.id,
            displayName: displayName,
            projectId: projectId ?? store.projects[0].id,
            environment: environment,
            categoryIds: Array(selectedCategoryIds),
            dateLabel: dl.isEmpty ? nil : dl
          )
          onDone()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(22)
    .frame(minWidth: 420)
    .onAppear {
      displayName = link.displayName
      dateLabelField = link.dateLabel ?? ""
      projectId = link.projectId
      environment = link.environment
      selectedCategoryIds = Set(link.categoryIds)
    }
  }

  private func bindingForCategory(_ id: UUID) -> Binding<Bool> {
    Binding(
      get: { selectedCategoryIds.contains(id) },
      set: { on in
        if on { selectedCategoryIds.insert(id) }
        else { selectedCategoryIds.remove(id) }
      }
    )
  }
}
