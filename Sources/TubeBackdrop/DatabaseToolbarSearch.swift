import SwiftUI

/// Opens the custom command palette in database-only mode (Raycast-style overlay — not `NSPopover`).
struct DatabaseToolbarSearch: View {
  @EnvironmentObject private var chrome: AppChromeState

  var body: some View {
    Button {
      chrome.presentCommandPalette(mode: .databases)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
        Text("Search")
      }
    }
    .help("Search database files — filter by project, filename, environment, and version")
  }
}
