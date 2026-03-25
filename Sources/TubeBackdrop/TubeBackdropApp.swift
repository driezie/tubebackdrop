import SwiftUI

@main
struct TubeBackdropApp: App {
  #if canImport(Sparkle)
  @NSApplicationDelegateAdaptor(SparkleAppDelegate.self) private var appDelegate
  #endif

  @StateObject private var store = VideoStore()
  @StateObject private var wallpaper = WallpaperController()
  @StateObject private var chrome = AppChromeState()

  var body: some Scene {
    WindowGroup {
      DashboardShellView()
        .environmentObject(store)
        .environmentObject(wallpaper)
        .environmentObject(chrome)
        .frame(minWidth: 880, minHeight: 560)
    }
    .windowStyle(.automatic)
    .commands {
      CommandGroup(replacing: .newItem) {}

      CommandMenu("Go") {
        Button("Library") {
          chrome.sidebarSelection = .library
        }
        .keyboardShortcut("1", modifiers: [.command])

        Button("Databases") {
          chrome.sidebarSelection = .databases
        }
        .keyboardShortcut("2", modifiers: [.command])

        Button("Add video") {
          chrome.sidebarSelection = .addVideo
        }
        .keyboardShortcut("3", modifiers: [.command])

        Button("Wallpaper") {
          chrome.sidebarSelection = .wallpaper
        }
        .keyboardShortcut("4", modifiers: [.command])
      }

      CommandGroup(after: .toolbar) {
        Button("Search Library…") {
          chrome.isGlobalSearchPresented = true
        }
        .keyboardShortcut("k", modifiers: .command)
      }

      #if canImport(Sparkle)
      CommandGroup(after: .appInfo) {
        Button("Check for Updates…") {
          SparkleUpdateMenu.checkForUpdates()
        }
      }
      #endif
    }
  }
}
