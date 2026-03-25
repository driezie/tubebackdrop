import SwiftUI

struct DatabaseToolbarSearch: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var chrome: AppChromeState

  @State private var isPresented = false
  @State private var nameQuery = ""
  @State private var environmentFilter: DatabaseEnvironment? = nil
  @State private var dateToken = "__latest__"
  @FocusState private var focusedName: Bool

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
        Text("Search")
      }
    }
    .help("Search database files by project name, filename, or type")
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      popoverContent
        .frame(width: 380)
        .padding(16)
    }
  }

  private var baseForDateLabels: [LinkedDatabase] {
    let q = nameQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var list = store.linkedDatabases
    if !q.isEmpty {
      list = list.filter { link in
        if link.displayName.lowercased().contains(q) { return true }
        if link.sourceFilename.lowercased().contains(q) { return true }
        if link.fileExtension.lowercased().contains(q) { return true }
        if let proj = store.project(for: link.projectId), proj.name.lowercased().contains(q) { return true }
        return false
      }
    }
    if let env = environmentFilter {
      list = list.filter { $0.environment == env }
    }
    return list
  }

  private var dateLabelOptions: [String] {
    store.distinctDateLabels(in: baseForDateLabels)
  }

  private var results: [LinkedDatabase] {
    store.toolbarDatabaseMatches(
      nameQuery: nameQuery,
      environment: environmentFilter,
      dateToken: dateToken
    )
  }

  private var popoverContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Database files")
        .font(.headline)

      TextField("Project, filename, or type…", text: $nameQuery)
        .textFieldStyle(.roundedBorder)
        .focused($focusedName)

      LabeledContent("Environment") {
        Picker("Environment", selection: $environmentFilter) {
          Text("Any").tag(nil as DatabaseEnvironment?)
          ForEach(DatabaseEnvironment.allCases) { e in
            Text(e.title).tag(Optional(e))
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      LabeledContent("Date / version") {
        Picker("Date / version", selection: $dateToken) {
          Text("Latest").tag("__latest__")
          Text("All versions").tag("__all__")
          ForEach(dateLabelOptions, id: \.self) { label in
            Text(label).tag(label)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Text("Tab moves from name → environment → date. Results update as you type.")
        .font(.caption2)
        .foregroundStyle(.tertiary)

      Divider()

      if results.isEmpty {
        Text("No matches.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(results) { link in
              resultRow(link)
            }
          }
        }
        .frame(maxHeight: 220)
      }
    }
    .onAppear {
      focusedName = true
    }
    .onChange(of: nameQuery) { _ in
      normalizeDateTokenIfNeeded()
    }
    .onChange(of: environmentFilter) { _ in
      normalizeDateTokenIfNeeded()
    }
  }

  private func normalizeDateTokenIfNeeded() {
    guard dateToken != "__latest__", dateToken != "__all__" else { return }
    if !dateLabelOptions.contains(dateToken) {
      dateToken = "__latest__"
    }
  }

  private func resultRow(_ link: LinkedDatabase) -> some View {
    let proj = store.project(for: link.projectId)?.name ?? "—"
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(link.displayName)
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(link.environment.shortLabel.uppercased())
          .font(.caption2.weight(.bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.quaternary.opacity(0.5), in: Capsule())
      }
      Text(proj)
        .font(.caption2)
        .foregroundStyle(.secondary)
      HStack(spacing: 8) {
        Text(link.sourceFilename.isEmpty ? "—" : link.sourceFilename)
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
        if let dl = link.dateLabel, !dl.isEmpty {
          Text(dl)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Text("." + (link.fileExtension.isEmpty ? "?" : link.fileExtension))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      HStack(spacing: 8) {
        Button("Show in Databases") {
          chrome.sidebarSelection = .databases
          isPresented = false
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        if let url = store.resolvedFileURL(for: link) {
          Button("Download…") {
            let suggested =
              link.sourceFilename.isEmpty
              ? "\(link.displayName).\(link.fileExtension)"
              : link.sourceFilename
            _ = LinkedDatabaseExporter.saveCopy(sourceURL: url, suggestedFilename: suggested)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.25)))
  }
}
