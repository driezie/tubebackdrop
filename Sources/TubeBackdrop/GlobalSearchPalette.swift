import SwiftUI

struct GlobalSearchPalette: View {
  @Binding var isPresented: Bool
  @Binding var query: String
  @ObservedObject var store: VideoStore
  @ObservedObject var wallpaper: WallpaperController
  @Binding var sidebarSelection: SidebarSelection

  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      Color.black.opacity(0.45)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .font(.title3)
            .foregroundStyle(.secondary)
          TextField("Search library, paste URL…", text: $query)
            .textFieldStyle(.plain)
            .font(.title3.weight(.medium))
            .focused($searchFocused)
            .onSubmit { handlePrimarySubmit() }

          Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)

        Divider()

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            quickActions
            if !trimmedQuery.isEmpty, trimmedQuery.contains("youtube.com") || trimmedQuery.contains("youtu.be") {
              youtubeQuickAdd
            }
            databasesSection
            librarySection
          }
          .padding(14)
        }
        .frame(maxHeight: 360)
      }
      .frame(width: 520)
      .background {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(.ultraThickMaterial)
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(.white.opacity(0.08), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
    }
    .onAppear {
      searchFocused = true
    }
  }

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func dismiss() {
    isPresented = false
    query = ""
  }

  private func handlePrimarySubmit() {
    if trimmedQuery.contains("youtube.com") || trimmedQuery.contains("youtu.be") {
      store.addYouTubeURL(trimmedQuery)
      query = ""
      sidebarSelection = .library
      dismiss()
      return
    }
    let matches = store.itemsMatchingSearch(trimmedQuery)
    if let first = matches.first(where: { $0.isDownloaded }) {
      activateWallpaper(first)
      return
    }
    if !matches.isEmpty {
      sidebarSelection = .library
      dismiss()
    }
  }

  private var quickActions: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Quick actions")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      quickRow(icon: "plus.circle.fill", title: "Add video", subtitle: "Open add flow") {
        sidebarSelection = .addVideo
        dismiss()
      }
      quickRow(icon: "square.stack.fill", title: "Library", subtitle: "Browse downloads") {
        sidebarSelection = .library
        dismiss()
      }
      quickRow(
        icon: "display.trianglebadge.exclamationmark",
        title: "Wallpaper",
        subtitle: "Backdrop controls"
      ) {
        sidebarSelection = .wallpaper
        dismiss()
      }
      quickRow(icon: "cylinder.split.1x2", title: "Databases", subtitle: "Projects, files, environments") {
        sidebarSelection = .databases
        dismiss()
      }
      if wallpaper.isRunning {
        quickRow(icon: "stop.fill", title: "Stop video backdrop", subtitle: "Hide desktop layer") {
          wallpaper.stop()
          dismiss()
        }
      }
    }
  }

  private func quickRow(
    icon: String,
    title: String,
    subtitle: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body.weight(.medium))
          .frame(width: 28, alignment: .center)
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(.white.opacity(0.06))
      )
      .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var youtubeQuickAdd: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Add from URL")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      Button {
        store.addYouTubeURL(trimmedQuery)
        query = ""
        sidebarSelection = .library
        dismiss()
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "link.badge.plus")
            .foregroundStyle(Color.accentColor)
          VStack(alignment: .leading, spacing: 2) {
            Text("Add to library")
              .font(.body.weight(.semibold))
            Text(trimmedQuery)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.14))
        )
      }
      .buttonStyle(.plain)
    }
  }

  private var databasesSection: some View {
    let links = store.linkedDatabasesMatchingSearch(trimmedQuery)
    let projs = store.projectsMatchingSearch(trimmedQuery)
    let cats = store.categoriesMatchingSearch(trimmedQuery)

    return VStack(alignment: .leading, spacing: 8) {
      Text("Databases & organization")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      if trimmedQuery.isEmpty {
        Text("Search by project, category, environment, or connected file name.")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .padding(.vertical, 4)
      } else if projs.isEmpty && cats.isEmpty && links.isEmpty {
        EmptyView()
      } else {
        ForEach(projs) { p in
          Button {
            sidebarSelection = .databases
            dismiss()
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text(p.name)
                  .font(.body.weight(.medium))
                Text("Project")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
            )
          }
          .buttonStyle(.plain)
        }
        ForEach(cats) { c in
          Button {
            sidebarSelection = .databases
            dismiss()
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "tag.fill")
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text(c.name)
                  .font(.body.weight(.medium))
                Text("Category")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
            )
          }
          .buttonStyle(.plain)
        }
        ForEach(links) { link in
          Button {
            sidebarSelection = .databases
            dismiss()
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "cylinder.fill")
                .foregroundStyle(.cyan)
              VStack(alignment: .leading, spacing: 2) {
                Text(link.displayName)
                  .font(.body.weight(.medium))
                Text("\(store.project(for: link.projectId)?.name ?? "") · \(link.environment.title)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var librarySection: some View {
    let matches = store.itemsMatchingSearch(trimmedQuery)
    return VStack(alignment: .leading, spacing: 8) {
      Text("Library")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      if trimmedQuery.isEmpty {
        Text("Type to filter titles and URLs, or paste a YouTube link above.")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .padding(.vertical, 8)
      } else if matches.isEmpty {
        Text("No matches. Try another query or add the URL from Add video.")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .padding(.vertical, 8)
      } else {
        ForEach(matches) { item in
          libraryRow(item)
        }
      }
    }
  }

  private func libraryRow(_ item: VideoItem) -> some View {
    Button {
      if item.isDownloaded {
        activateWallpaper(item)
      } else {
        sidebarSelection = .library
        dismiss()
      }
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.isDownloaded ? "film.fill" : "arrow.down.circle")
          .foregroundStyle(item.isDownloaded ? .green : .orange)
          .frame(width: 28, alignment: .center)
        VStack(alignment: .leading, spacing: 4) {
          Text(item.displayTitle ?? shortURL(item.youtubeURL))
            .font(.body.weight(.medium))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          Text(item.youtubeURL)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          if item.isDownloaded {
            Text("Enter — set as desktop backdrop")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          } else {
            Text("Download from Library")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(.white.opacity(0.05))
      )
    }
    .buttonStyle(.plain)
  }

  private func shortURL(_ s: String) -> String {
    if s.count > 56 { return String(s.prefix(53)) + "…" }
    return s
  }

  private func activateWallpaper(_ item: VideoItem) {
    guard let file = store.resolvedFileURL(for: item) else {
      sidebarSelection = .library
      dismiss()
      return
    }
    wallpaper.playVideo(at: file)
    sidebarSelection = .wallpaper
    dismiss()
  }
}
