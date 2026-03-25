import SwiftUI

struct DatabaseImportDraft: Identifiable {
  let id = UUID()
  let urls: [URL]
}

struct ImportDatabaseSheet: View {
  @EnvironmentObject private var store: VideoStore

  let urls: [URL]
  let onDone: () -> Void

  @State private var projectName: String = ""
  @State private var displayName: String = ""
  @State private var environment: DatabaseEnvironment = .development
  @State private var selectedCategoryIds: Set<UUID> = []
  @State private var errorText: String?
  @State private var parsedHint: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(urls.count == 1 ? "Connect database file" : "Connect \(urls.count) files")
        .font(.title2.weight(.bold))

      if urls.count == 1, let u = urls.first {
        Text(u.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        if !parsedHint.isEmpty {
          Text(parsedHint)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        TextField("Project name (create or match)", text: $projectName)
          .textFieldStyle(.roundedBorder)
        TextField("Display name", text: $displayName)
          .textFieldStyle(.roundedBorder)
      } else {
        Text(
          "Each file is parsed as project_environment_date.ext when possible (e.g. "
            + "vanreeaccountants_staging_25mar.sql). Projects are created if they do not exist."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }

      Picker("Environment (fallback if not in filename)", selection: $environment) {
        ForEach(DatabaseEnvironment.allCases) { e in
          Text(e.title).tag(e)
        }
      }

      Text("Categories")
        .font(.subheadline.weight(.semibold))
      if store.categories.isEmpty {
        Text("Add categories on the Databases page first.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
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
      }

      if let errorText {
        Text(errorText)
          .foregroundStyle(.red)
          .font(.callout)
      }

      HStack {
        Spacer()
        Button("Cancel", action: onDone)
        Button("Save") { importAll() }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(22)
    .frame(minWidth: 460)
    .onAppear {
      store.ensureDefaultProject()
      if urls.count == 1, let u = urls.first {
        let fn = u.lastPathComponent
        let parsed = DatabaseFilenameParser.parse(filename: fn)
        let slug =
          parsed.projectSlug.isEmpty
          ? u.deletingPathExtension().lastPathComponent
          : parsed.projectSlug
        projectName = DatabaseFilenameParser.displayProjectName(from: slug)
        displayName = u.deletingPathExtension().lastPathComponent
        if let pe = parsed.environment {
          environment = pe
        }
        var parts: [String] = []
        if let dl = parsed.dateLabel { parts.append("date: \(dl)") }
        if !parsed.fileExtension.isEmpty { parts.append(".\(parsed.fileExtension)") }
        parsedHint = parts.isEmpty ? "" : "Detected: " + parts.joined(separator: " · ")
      }
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

  private func importAll() {
    errorText = nil
    let cats = Array(selectedCategoryIds)
    do {
      if urls.count == 1, let u = urls.first {
        let fn = u.lastPathComponent
        let parsed = DatabaseFilenameParser.parse(filename: fn)
        let pid = store.findOrCreateProject(named: projectName)
        let env = parsed.environment ?? environment
        let dateLabel = parsed.dateLabel
        let ext =
          parsed.fileExtension.isEmpty
          ? u.pathExtension.lowercased()
          : parsed.fileExtension
        let disp =
          displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? u.deletingPathExtension().lastPathComponent
          : displayName
        try store.addLinkedDatabase(
          displayName: disp,
          fileURL: u,
          projectId: pid,
          environment: env,
          categoryIds: cats,
          sourceFilename: fn,
          fileExtension: ext,
          dateLabel: dateLabel
        )
      } else {
        for u in urls {
          let fn = u.lastPathComponent
          let parsed = DatabaseFilenameParser.parse(filename: fn)
          let slug =
            parsed.projectSlug.isEmpty
            ? u.deletingPathExtension().lastPathComponent
            : parsed.projectSlug
          let pname = DatabaseFilenameParser.displayProjectName(from: slug)
          let pid = store.findOrCreateProject(named: pname)
          let env = parsed.environment ?? environment
          let ext =
            parsed.fileExtension.isEmpty
            ? u.pathExtension.lowercased()
            : parsed.fileExtension
          let disp = u.deletingPathExtension().lastPathComponent
          try store.addLinkedDatabase(
            displayName: disp,
            fileURL: u,
            projectId: pid,
            environment: env,
            categoryIds: cats,
            sourceFilename: fn,
            fileExtension: ext,
            dateLabel: parsed.dateLabel
          )
        }
      }
      onDone()
    } catch {
      errorText = error.localizedDescription
    }
  }
}
