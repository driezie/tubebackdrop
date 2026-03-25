import AppKit
import Foundation

enum LinkedDatabaseExporter {
  /// Copies the linked file to a user-chosen path. Returns false if cancelled or failed.
  @MainActor
  static func saveCopy(sourceURL: URL, suggestedFilename: String) -> Bool {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = suggestedFilename
    panel.title = "Download database file"
    panel.message = "Choose where to save a copy of this file."

    guard panel.runModal() == .OK, let dest = panel.url else { return false }

    let didStart = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if didStart { sourceURL.stopAccessingSecurityScopedResource() }
    }

    let fm = FileManager.default
    if fm.fileExists(atPath: dest.path) {
      try? fm.removeItem(at: dest)
    }

    do {
      try fm.copyItem(at: sourceURL, to: dest)
      return true
    } catch {
      return false
    }
  }
}
