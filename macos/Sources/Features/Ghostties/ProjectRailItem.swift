import SwiftUI

/// A single row in the icon rail: folder icon + project name (when expanded).
struct ProjectRailItem: View {
    let project: Project
    let isSelected: Bool
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    .frame(width: 36, height: 36)
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(width: 36, height: 36)

            if isExpanded {
                Text(project.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44) // 44pt minimum hit area (a11y)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name) project\(isSelected ? ", selected" : "")")
    }
}
