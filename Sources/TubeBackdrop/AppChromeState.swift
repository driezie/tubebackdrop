import SwiftUI

/// Which surface the command palette focuses when opened (⌘K vs toolbar Search).
enum CommandPaletteMode: Equatable {
  case global
  case databases
}

enum SidebarSelection: String, Identifiable {
  case library
  case databases
  case addVideo
  case wallpaper
  case settings

  var id: String { rawValue }

  /// Main navigation items (top of sidebar). Settings is pinned at the bottom separately.
  static let primarySections: [SidebarSelection] = [.library, .databases, .addVideo, .wallpaper]

  var title: String {
    switch self {
    case .library: return "Library"
    case .databases: return "Databases"
    case .addVideo: return "Add video"
    case .wallpaper: return "Wallpaper"
    case .settings: return "Settings"
    }
  }

  var icon: String {
    switch self {
    case .library: return "square.stack.fill"
    case .databases: return "cylinder.split.1x2"
    case .addVideo: return "plus.circle.fill"
    case .wallpaper: return "display.trianglebadge.exclamationmark"
    case .settings: return "gearshape.fill"
    }
  }
}

struct PendingDatabaseImport: Identifiable, Equatable {
  let id = UUID()
  let urls: [URL]

  static func == (lhs: PendingDatabaseImport, rhs: PendingDatabaseImport) -> Bool {
    lhs.id == rhs.id
  }
}

@MainActor
final class AppChromeState: ObservableObject {
  @Published var sidebarSelection: SidebarSelection = .library
  @Published var isGlobalSearchPresented = false
  @Published var commandPaletteMode: CommandPaletteMode = .global
  @Published var searchQuery: String = ""

  func presentCommandPalette(mode: CommandPaletteMode = .global) {
    commandPaletteMode = mode
    if mode == .databases {
      searchQuery = ""
    }
    isGlobalSearchPresented = true
  }
  /// Set when the user drops database files on the dashboard; presents import sheet.
  @Published var pendingDatabaseImport: PendingDatabaseImport?
}
