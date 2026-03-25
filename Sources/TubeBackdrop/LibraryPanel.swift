import SwiftUI

struct LibraryPanel: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var wallpaper: WallpaperController

  @State private var busyId: UUID?
  @State private var errorText: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        if let errorText {
          Text(errorText)
            .font(.callout)
            .foregroundStyle(.red)
        }
        listCard
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      store.ensureDefaultProject()
      store.refreshDownloadedState()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Library")
        .font(.title.weight(.bold))
      Text("Videos and downloads · ⌘K to search")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func organizationRow(for item: VideoItem) -> some View {
    let projectBinding = Binding<UUID>(
      get: {
        if let p = item.projectId, store.projects.contains(where: { $0.id == p }) {
          return p
        }
        return store.projects.first!.id
      },
      set: {
        store.setVideoOrganization(
          itemId: item.id,
          categoryId: item.categoryId,
          projectId: $0,
          linkedDatabaseId: item.linkedDatabaseId,
          environment: item.environment
        )
      }
    )
    let categoryBinding = Binding<UUID?>(
      get: { item.categoryId },
      set: {
        store.setVideoOrganization(
          itemId: item.id,
          categoryId: $0,
          projectId: item.projectId,
          linkedDatabaseId: item.linkedDatabaseId,
          environment: item.environment
        )
      }
    )
    let envBinding = Binding<DatabaseEnvironment?>(
      get: { item.environment },
      set: {
        store.setVideoOrganization(
          itemId: item.id,
          categoryId: item.categoryId,
          projectId: item.projectId,
          linkedDatabaseId: item.linkedDatabaseId,
          environment: $0
        )
      }
    )
    let dbBinding = Binding<UUID?>(
      get: { item.linkedDatabaseId },
      set: {
        store.setVideoOrganization(
          itemId: item.id,
          categoryId: item.categoryId,
          projectId: item.projectId,
          linkedDatabaseId: $0,
          environment: item.environment
        )
      }
    )

    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 12) {
        Picker("Project", selection: projectBinding) {
          ForEach(store.projects) { p in
            Text(p.name).tag(p.id)
          }
        }
        .labelsHidden()
        .frame(minWidth: 120, alignment: .leading)

        Picker("Category", selection: categoryBinding) {
          Text("None").tag(nil as UUID?)
          ForEach(store.categories) { c in
            Text(c.name).tag(Optional(c.id))
          }
        }
        .labelsHidden()
        .frame(minWidth: 100, alignment: .leading)

        Picker("Environment", selection: envBinding) {
          Text("—").tag(nil as DatabaseEnvironment?)
          ForEach(DatabaseEnvironment.allCases) { e in
            Text(e.shortLabel).tag(Optional(e))
          }
        }
        .labelsHidden()
        .frame(minWidth: 88, alignment: .leading)

        Picker("Database file", selection: dbBinding) {
          Text("None").tag(nil as UUID?)
          ForEach(store.linkedDatabases) { db in
            Text(db.displayName).tag(Optional(db.id))
          }
        }
        .labelsHidden()
        .frame(minWidth: 140, alignment: .leading)
      }
      .font(.caption)
    }
  }

  private var listCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      if store.items.isEmpty {
        Text("No items yet. Use Add video or ⌘K to paste a link.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(20)
      } else {
        List {
          ForEach(store.items) { item in
            VStack(alignment: .leading, spacing: 8) {
              Text(item.displayTitle ?? shortURL(item.youtubeURL))
                .font(.headline)
                .lineLimit(2)
              Text(item.youtubeURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              organizationRow(for: item)
              HStack(spacing: 8) {
                if item.isDownloaded {
                  Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                  Button("Set as backdrop") {
                    useBackground(item)
                  }
                  .buttonStyle(.borderedProminent)
                } else {
                  Button(busyId == item.id ? "Downloading…" : "Download") {
                    Task { await download(item) }
                  }
                  .disabled(busyId != nil)
                }
              }
            }
            .padding(.vertical, 6)
          }
          .onDelete { indexSet in
            for i in indexSet {
              store.remove(store.items[i])
            }
          }
        }
        // `.inset(alternatesRowBackgrounds:)` is macOS 14+; deployment target is 13.
        .listStyle(.inset)
        .frame(minHeight: 280)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
    )
  }

  private func shortURL(_ s: String) -> String {
    if s.count > 60 { return String(s.prefix(57)) + "…" }
    return s
  }

  private func download(_ item: VideoItem) async {
    errorText = nil
    busyId = item.id
    store.downloadMessage = nil
    store.downloadProgress = 0
    defer {
      busyId = nil
      store.downloadProgress = nil
    }

    let dir = store.videosDirectory()
    do {
      let result = try await YouTubeDownloader.download(
        youtubeURL: item.youtubeURL,
        outputDir: dir,
        id: item.id
      ) { line, fraction in
        Task { @MainActor in
          store.downloadMessage = line
          if let fraction {
            store.downloadProgress = fraction
          }
        }
      }
      let name = result.outputPath.lastPathComponent
      store.markDownloaded(id: item.id, filename: name, title: result.title)
      store.refreshDownloadedState()
      store.downloadProgress = 1
      store.downloadMessage = "Done: \(name)"
    } catch {
      errorText = error.localizedDescription
    }
  }

  private func useBackground(_ item: VideoItem) {
    errorText = nil
    guard let file = store.resolvedFileURL(for: item) else {
      errorText = "Missing file on disk."
      store.refreshDownloadedState()
      return
    }
    wallpaper.playVideo(at: file)
  }
}
