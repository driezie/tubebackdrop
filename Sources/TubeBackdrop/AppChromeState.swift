import SwiftUI

enum SidebarSelection: String, CaseIterable, Identifiable {
  case library
  case databases
  case addVideo
  case wallpaper

  var id: String { rawValue }

  var title: String {
    switch self {
    case .library: return "Library"
    case .databases: return "Databases"
    case .addVideo: return "Add video"
    case .wallpaper: return "Wallpaper"
    }
  }

  var icon: String {
    switch self {
    case .library: return "square.stack.fill"
    case .databases: return "cylinder.split.1x2"
    case .addVideo: return "plus.circle.fill"
    case .wallpaper: return "display.trianglebadge.exclamationmark"
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
  @Published var searchQuery: String = ""
  /// Set when the user drops database files on the dashboard; presents import sheet.
  @Published var pendingDatabaseImport: PendingDatabaseImport?
}
