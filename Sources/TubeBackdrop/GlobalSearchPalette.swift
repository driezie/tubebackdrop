import AppKit
import SwiftUI

// MARK: - Raycast-style chrome (custom overlay, not NSSearchField / NSPopover)

private enum PalettePalette {
  static let panelWidth: CGFloat = 640
  static let panelCorner: CGFloat = 18
  static let maxResultsHeight: CGFloat = 380
  static let rowCorner: CGFloat = 10
}

// MARK: - Key routing (↑↓ ↩ esc) while the palette is open

private struct CommandPaletteKeyMonitor: NSViewRepresentable {
  var isActive: Bool
  var onArrowUp: () -> Void
  var onArrowDown: () -> Void
  var onActivate: () -> Void
  var onEscape: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let v = NSView(frame: .zero)
    v.isHidden = true
    return v
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.onArrowUp = onArrowUp
    context.coordinator.onArrowDown = onArrowDown
    context.coordinator.onActivate = onActivate
    context.coordinator.onEscape = onEscape
    if isActive {
      context.coordinator.install()
    } else {
      context.coordinator.remove()
    }
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.remove()
  }

  final class Coordinator {
    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}
    var onActivate: () -> Void = {}
    var onEscape: () -> Void = {}
    private var monitor: Any?

    func install() {
      remove()
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self else { return event }
        switch event.keyCode {
        case 126: // up
          self.onArrowUp()
          return nil
        case 125: // down
          self.onArrowDown()
          return nil
        case 36, 76: // return, keypad enter
          self.onActivate()
          return nil
        case 53: // escape
          self.onEscape()
          return nil
        default:
          return event
        }
      }
    }

    func remove() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }
  }
}

// MARK: - HUD material panel

private struct HUDPanelBackground: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = .hudWindow
    v.blendingMode = .withinWindow
    v.state = .active
    v.wantsLayer = true
    v.layer?.cornerRadius = PalettePalette.panelCorner
    v.layer?.cornerCurve = .continuous
    v.layer?.masksToBounds = true
    return v
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Global row model

private struct CommandRow: Identifiable {
  enum Kind {
    case quickAction(icon: String, title: String, subtitle: String)
    case youtubeAdd(url: String)
    case project(MediaProject)
    case category(MediaCategory)
    case linkedDB(LinkedDatabase)
    case libraryVideo(VideoItem)
  }

  let id: String
  let kind: Kind
}

struct GlobalSearchPalette: View {
  @EnvironmentObject private var chrome: AppChromeState
  @Binding var isPresented: Bool
  @Binding var query: String
  @ObservedObject var store: VideoStore
  @ObservedObject var wallpaper: WallpaperController
  @Binding var sidebarSelection: SidebarSelection

  @FocusState private var searchFocused: Bool
  @State private var selectedIndex: Int = 0

  // Database palette filters (toolbar path — custom overlay, not NSPopover)
  @State private var databaseEnvironmentFilter: DatabaseEnvironment? = nil
  @State private var databaseDateToken: String = "__latest__"

  var body: some View {
    ZStack {
      Color.black.opacity(0.42)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      VStack(spacing: 0) {
        if chrome.commandPaletteMode == .databases {
          databasePaletteContent
        } else {
          globalPaletteContent
        }
      }
      .frame(width: PalettePalette.panelWidth)
      .background {
        ZStack {
          HUDPanelBackground()
          RoundedRectangle(cornerRadius: PalettePalette.panelCorner, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
      }
      .shadow(color: .black.opacity(0.55), radius: 40, y: 22)
      .overlay {
        CommandPaletteKeyMonitor(
          isActive: isPresented,
          onArrowUp: { moveSelection(-1) },
          onArrowDown: { moveSelection(1) },
          onActivate: { activateSelection() },
          onEscape: { dismiss() }
        )
        .frame(width: 0, height: 0)
      }
    }
    .onAppear {
      searchFocused = true
      if chrome.commandPaletteMode == .databases {
        databaseEnvironmentFilter = nil
        databaseDateToken = "__latest__"
      }
      selectedIndex = 0
      clampSelection()
    }
    .onChange(of: query) { _ in
      selectedIndex = 0
      normalizeDatabaseDateTokenIfNeeded()
    }
    .onChange(of: databaseEnvironmentFilter) { _ in
      selectedIndex = 0
      normalizeDatabaseDateTokenIfNeeded()
    }
    .onChange(of: chrome.commandPaletteMode) { _ in
      selectedIndex = 0
      if chrome.commandPaletteMode == .databases {
        databaseEnvironmentFilter = nil
        databaseDateToken = "__latest__"
      }
    }
  }

  // MARK: - Global mode

  private var globalPaletteContent: some View {
    VStack(spacing: 0) {
      searchHeader(placeholder: "Search or type a command…")
      Divider().opacity(0.35)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            if globalRows.isEmpty {
              emptyGlobalHint
            } else {
              ForEach(Array(globalRows.enumerated()), id: \.element.id) { index, row in
                globalRowView(row, index: index)
                  .id(row.id)
              }
            }
          }
          .padding(10)
        }
        .frame(maxHeight: PalettePalette.maxResultsHeight)
        .onChange(of: selectedIndex) { newValue in
          guard newValue >= 0, newValue < globalRows.count else { return }
          withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(globalRows[newValue].id, anchor: .center)
          }
        }
      }
      paletteFooter(hint: "↑↓ select  ·  ↩ run  ·  esc close")
    }
  }

  private var emptyGlobalHint: some View {
    Text("No matches. Try a title, URL, project, or paste a YouTube link.")
      .font(.callout)
      .foregroundStyle(.tertiary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 28)
      .padding(.horizontal, 16)
  }

  private func searchHeader(placeholder: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 22, weight: .regular))
        .focused($searchFocused)
      Button(action: { dismiss() }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 18))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }

  private func paletteFooter(hint: String) -> some View {
    Text(hint)
      .font(.caption)
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .padding(.horizontal, 16)
      .background(Color.white.opacity(0.04))
  }

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var globalRows: [CommandRow] {
    let q = trimmedQuery.lowercased()
    var rows: [CommandRow] = []

    func matchesQuick(_ title: String, _ subtitle: String) -> Bool {
      q.isEmpty
        || title.lowercased().contains(q)
        || subtitle.lowercased().contains(q)
    }

    if matchesQuick("Add video", "Open add flow") {
      rows.append(
        CommandRow(
          id: "qa-add",
          kind: .quickAction(icon: "plus.circle.fill", title: "Add video", subtitle: "Open add flow")
        ))
    }
    if matchesQuick("Library", "Browse downloads") {
      rows.append(
        CommandRow(
          id: "qa-lib",
          kind: .quickAction(icon: "square.stack.fill", title: "Library", subtitle: "Browse downloads")
        ))
    }
    if matchesQuick("Wallpaper", "Backdrop controls") {
      rows.append(
        CommandRow(
          id: "qa-wall",
          kind: .quickAction(
            icon: "display.trianglebadge.exclamationmark",
            title: "Wallpaper",
            subtitle: "Backdrop controls"
          )
        ))
    }
    if matchesQuick("Databases", "Projects, files, environments") {
      rows.append(
        CommandRow(
          id: "qa-db",
          kind: .quickAction(
            icon: "cylinder.split.1x2",
            title: "Databases",
            subtitle: "Projects, files, environments"
          )
        ))
    }
    if wallpaper.isRunning, matchesQuick("Stop video backdrop", "Hide desktop layer") {
      rows.append(
        CommandRow(
          id: "qa-stop",
          kind: .quickAction(icon: "stop.fill", title: "Stop video backdrop", subtitle: "Hide desktop layer")
        ))
    }

    if !trimmedQuery.isEmpty,
       trimmedQuery.contains("youtube.com") || trimmedQuery.contains("youtu.be")
    {
      rows.append(CommandRow(id: "yt-add", kind: .youtubeAdd(url: trimmedQuery)))
    }

    if !trimmedQuery.isEmpty {
      for p in store.projectsMatchingSearch(trimmedQuery) {
        rows.append(CommandRow(id: "proj-\(p.id.uuidString)", kind: .project(p)))
      }
      for c in store.categoriesMatchingSearch(trimmedQuery) {
        rows.append(CommandRow(id: "cat-\(c.id.uuidString)", kind: .category(c)))
      }
      for link in store.linkedDatabasesMatchingSearch(trimmedQuery) {
        rows.append(CommandRow(id: "link-\(link.id.uuidString)", kind: .linkedDB(link)))
      }
      for item in store.itemsMatchingSearch(trimmedQuery) {
        rows.append(CommandRow(id: "vid-\(item.id.uuidString)", kind: .libraryVideo(item)))
      }
    }

    return rows
  }

  @ViewBuilder
  private func globalRowView(_ row: CommandRow, index: Int) -> some View {
    let selected = index == selectedIndex
    switch row.kind {
    case let .quickAction(icon, title, subtitle):
      raycastRow(
        selected: selected,
        icon: icon,
        iconTint: .secondary,
        title: title,
        subtitle: subtitle,
        trailing: nil
      ) {
        handleQuickAction(id: row.id)
      }
    case let .youtubeAdd(url):
      raycastRow(
        selected: selected,
        icon: "link.badge.plus",
        iconTint: Color.accentColor,
        title: "Add to library",
        subtitle: url,
        trailing: "↩"
      ) {
        store.addYouTubeURL(url)
        query = ""
        sidebarSelection = .library
        dismiss()
      }
    case let .project(p):
      raycastRow(
        selected: selected,
        icon: "folder.fill",
        iconTint: .secondary,
        title: p.name,
        subtitle: "Project",
        trailing: nil
      ) {
        sidebarSelection = .databases
        dismiss()
      }
    case let .category(c):
      raycastRow(
        selected: selected,
        icon: "tag.fill",
        iconTint: .secondary,
        title: c.name,
        subtitle: "Category",
        trailing: nil
      ) {
        sidebarSelection = .databases
        dismiss()
      }
    case let .linkedDB(link):
      let proj = store.project(for: link.projectId)?.name ?? ""
      raycastRow(
        selected: selected,
        icon: "cylinder.fill",
        iconTint: .cyan,
        title: link.displayName,
        subtitle: "\(proj) · \(link.environment.title)",
        trailing: nil
      ) {
        sidebarSelection = .databases
        dismiss()
      }
    case let .libraryVideo(item):
      raycastRow(
        selected: selected,
        icon: item.isDownloaded ? "film.fill" : "arrow.down.circle",
        iconTint: item.isDownloaded ? .green : .orange,
        title: item.displayTitle ?? shortURL(item.youtubeURL),
        subtitle: item.isDownloaded
          ? item.youtubeURL
          : "Not downloaded — open Library",
        trailing: item.isDownloaded ? nil : nil
      ) {
        if item.isDownloaded {
          activateWallpaper(item)
        } else {
          sidebarSelection = .library
          dismiss()
        }
      }
    }
  }

  private func handleQuickAction(id: String) {
    switch id {
    case "qa-add":
      sidebarSelection = .addVideo
    case "qa-lib":
      sidebarSelection = .library
    case "qa-wall":
      sidebarSelection = .wallpaper
    case "qa-db":
      sidebarSelection = .databases
    case "qa-stop":
      wallpaper.stop()
    default:
      break
    }
    dismiss()
  }

  // MARK: - Database mode (replaces toolbar NSPopover)

  private var databasePaletteContent: some View {
    VStack(spacing: 0) {
      searchHeader(placeholder: "Filter by project, file, or type…")
      databaseFilterBar
      Divider().opacity(0.35)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            if databaseResults.isEmpty {
              Text("No database files match.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
              ForEach(Array(databaseResults.enumerated()), id: \.element.id) { index, link in
                databaseResultRow(link, index: index)
                  .id(link.id.uuidString)
              }
            }
          }
          .padding(10)
        }
        .frame(maxHeight: PalettePalette.maxResultsHeight)
        .onChange(of: selectedIndex) { newValue in
          guard newValue >= 0, newValue < databaseResults.count else { return }
          let id = databaseResults[newValue].id.uuidString
          withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
      paletteFooter(hint: "↑↓ select  ·  ↩ show in Databases  ·  esc close")
    }
  }

  private var databaseFilterBar: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("Environment")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            filterChip(title: "Any", selected: databaseEnvironmentFilter == nil) {
              databaseEnvironmentFilter = nil
            }
            ForEach(DatabaseEnvironment.allCases) { env in
              filterChip(title: env.title, selected: databaseEnvironmentFilter == env) {
                databaseEnvironmentFilter = env
              }
            }
          }
        }
      }
      HStack(spacing: 8) {
        Text("Version")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            filterChip(title: "Latest", selected: databaseDateToken == "__latest__") {
              databaseDateToken = "__latest__"
            }
            filterChip(title: "All", selected: databaseDateToken == "__all__") {
              databaseDateToken = "__all__"
            }
            ForEach(databaseDateLabelOptions, id: \.self) { label in
              filterChip(title: label, selected: databaseDateToken == label) {
                databaseDateToken = label
              }
            }
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.white.opacity(0.03))
  }

  private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.caption.weight(selected ? .semibold : .regular))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
          Capsule(style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08))
        )
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(Color.white.opacity(selected ? 0.2 : 0.06), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  private var databaseBaseForDateLabels: [LinkedDatabase] {
    let q = trimmedQuery.lowercased()
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
    if let env = databaseEnvironmentFilter {
      list = list.filter { $0.environment == env }
    }
    return list
  }

  private var databaseDateLabelOptions: [String] {
    store.distinctDateLabels(in: databaseBaseForDateLabels)
  }

  private var databaseResults: [LinkedDatabase] {
    store.toolbarDatabaseMatches(
      nameQuery: query,
      environment: databaseEnvironmentFilter,
      dateToken: databaseDateToken
    )
  }

  private func databaseResultRow(_ link: LinkedDatabase, index: Int) -> some View {
    let selected = index == selectedIndex
    let proj = store.project(for: link.projectId)?.name ?? "—"
    return VStack(alignment: .leading, spacing: 0) {
      raycastRow(
        selected: selected,
        icon: "cylinder.fill",
        iconTint: .cyan,
        title: link.displayName,
        subtitle: "\(proj)  ·  \(link.environment.title)"
          + (link.dateLabel.map { "  ·  \($0)" } ?? ""),
        trailing: "↩"
      ) {
        sidebarSelection = .databases
        dismiss()
      }
      if selected {
        HStack(spacing: 8) {
          if let url = store.resolvedFileURL(for: link) {
            let suggested =
              link.sourceFilename.isEmpty
              ? "\(link.displayName).\(link.fileExtension)"
              : link.sourceFilename
            Button("Save copy…") {
              _ = LinkedDatabaseExporter.saveCopy(sourceURL: url, suggestedFilename: suggested)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
        .padding(.leading, 56)
        .padding(.trailing, 12)
        .padding(.bottom, 8)
      }
    }
  }

  // MARK: - Shared row chrome

  private func raycastRow(
    selected: Bool,
    icon: String,
    iconTint: Color,
    title: String,
    subtitle: String,
    trailing: String?,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(width: 36, height: 36)
          Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(iconTint)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer(minLength: 0)
        if let trailing {
          Text(trailing)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: PalettePalette.rowCorner, style: .continuous)
          .fill(selected ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
      )
      .overlay(
        RoundedRectangle(cornerRadius: PalettePalette.rowCorner, style: .continuous)
          .strokeBorder(
            selected ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.04),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Actions

  private func dismiss() {
    isPresented = false
    query = ""
    chrome.commandPaletteMode = .global
    selectedIndex = 0
  }

  private func moveSelection(_ delta: Int) {
    let count = chrome.commandPaletteMode == .databases ? databaseResults.count : globalRows.count
    guard count > 0 else { return }
    selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
  }

  private func activateSelection() {
    if chrome.commandPaletteMode == .databases {
      guard selectedIndex >= 0, selectedIndex < databaseResults.count else { return }
      sidebarSelection = .databases
      dismiss()
      return
    }
    guard selectedIndex >= 0, selectedIndex < globalRows.count else { return }
    let row = globalRows[selectedIndex]
    switch row.kind {
    case .quickAction:
      handleQuickAction(id: row.id)
    case let .youtubeAdd(url):
      store.addYouTubeURL(url)
      query = ""
      sidebarSelection = .library
      dismiss()
    case .project:
      sidebarSelection = .databases
      dismiss()
    case .category:
      sidebarSelection = .databases
      dismiss()
    case .linkedDB:
      sidebarSelection = .databases
      dismiss()
    case let .libraryVideo(item):
      if item.isDownloaded {
        activateWallpaper(item)
      } else {
        sidebarSelection = .library
        dismiss()
      }
    }
  }

  private func clampSelection() {
    let count = chrome.commandPaletteMode == .databases ? databaseResults.count : globalRows.count
    if count == 0 {
      selectedIndex = 0
    } else {
      selectedIndex = min(max(0, selectedIndex), count - 1)
    }
  }

  private func normalizeDatabaseDateTokenIfNeeded() {
    guard databaseDateToken != "__latest__", databaseDateToken != "__all__" else { return }
    if !databaseDateLabelOptions.contains(databaseDateToken) {
      databaseDateToken = "__latest__"
    }
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
