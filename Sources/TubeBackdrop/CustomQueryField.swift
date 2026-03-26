import SwiftUI

/// Inline filter / query control with custom chrome (no `.roundedBorder` / system search field styling).
struct CustomQueryField: View {
  var placeholder: String
  @Binding var text: String
  /// Leading symbol; pass `nil` for a compact extension-style field.
  var systemImage: String? = "magnifyingglass"
  var font: Font = .system(size: 13, weight: .regular)

  var body: some View {
    HStack(spacing: 8) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .font(font)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
    )
  }
}
