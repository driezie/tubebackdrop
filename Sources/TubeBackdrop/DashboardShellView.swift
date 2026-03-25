import SwiftUI
import UniformTypeIdentifiers

struct DashboardShellView: View {
  @EnvironmentObject private var store: VideoStore
  @EnvironmentObject private var wallpaper: WallpaperController
  @EnvironmentObject private var chrome: AppChromeState

  @State private var dashboardImportDraft: DatabaseImportDraft?

  var body: some View {
    ZStack {
      NavigationSplitView {
        DashboardSidebar(selection: $chrome.sidebarSelection)
      } detail: {
        NavigationStack {
          detailRow
            .navigationTitle(chrome.sidebarSelection.title)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
              handleDashboardDrop(providers)
            }
            .toolbar {
              ToolbarItem(placement: .primaryAction) {
                DatabaseToolbarSearch()
              }
            }
        }
      }
      .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)

      if chrome.isGlobalSearchPresented {
        GlobalSearchPalette(
          isPresented: $chrome.isGlobalSearchPresented,
          query: $chrome.searchQuery,
          store: store,
          wallpaper: wallpaper,
          sidebarSelection: $chrome.sidebarSelection
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1)
      }
    }
    .animation(.easeOut(duration: 0.16), value: chrome.isGlobalSearchPresented)
    .background(Color(nsColor: .windowBackgroundColor))
    .preferredColorScheme(.dark)
    .sheet(item: $dashboardImportDraft) { draft in
      ImportDatabaseSheet(urls: draft.urls) {
        dashboardImportDraft = nil
      }
      .environmentObject(store)
    }
    // Single-parameter onChange is required for macOS 13 deployment; two-parameter form is macOS 14+ only.
    .onChange(of: chrome.pendingDatabaseImport) { newValue in
      guard let draft = newValue else { return }
      dashboardImportDraft = DatabaseImportDraft(urls: draft.urls)
      chrome.pendingDatabaseImport = nil
      chrome.sidebarSelection = .databases
    }
  }

  @ViewBuilder
  private var detailRow: some View {
    switch chrome.sidebarSelection {
    case .library:
      LibraryPanel()
    case .databases:
      DatabasesPanel()
    case .addVideo:
      AddVideoPanel()
    case .wallpaper:
      WallpaperPanel()
    }
  }

  private func handleDashboardDrop(_ providers: [NSItemProvider]) -> Bool {
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
      guard !unique.isEmpty else { return }
      chrome.sidebarSelection = .databases
      dashboardImportDraft = DatabaseImportDraft(urls: unique)
    }
    return true
  }
}
