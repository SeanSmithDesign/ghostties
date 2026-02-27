import SwiftUI

/// A single session row: name + ghost character status indicator.
///
/// Used by ProjectDisclosureRow to render sessions under each project.
/// Ghost character appears on the right, colored by session status.
struct SessionRow: View {
    let session: AgentSession
    let status: SessionStatus
    var ghostCharacter: GhostCharacter? = nil
    var isActive: Bool = false
    var isEditing: Bool = false
    @Binding var editingName: String
    var isRenameFocused: FocusState<Bool>.Binding
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("Session name", text: $editingName)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused(isRenameFocused)
                    .onSubmit { onCommitRename() }
                    .onExitCommand { onCancelRename() }
                    .onChange(of: isRenameFocused.wrappedValue) { focused in
                        if !focused, isEditing { onCommitRename() }
                    }
            } else {
                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .primary : inactiveTextColor)
                    .lineLimit(1)
            }

            Spacer()

            ghostIndicator
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .shadow(
            color: isActive ? Color.black.opacity(0.1) : .clear,
            radius: 2, x: 0, y: 1
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name), \(statusLabel)\(isActive ? ", active" : "")")
    }

    // MARK: - Ghost Indicator

    @ViewBuilder
    private var ghostIndicator: some View {
        if let ghost = ghostCharacter {
            GhostCharacterView(character: ghost, color: statusColor)
                .frame(width: 12, height: 12)
                .frame(width: 16, height: 16)
        } else {
            Text(String(session.name.prefix(1)).uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(statusColor)
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Colors

    private var statusColor: Color {
        switch status {
        case .running: return Color(nsColor: .systemGreen)
        case .exited: return Color(.tertiaryLabelColor)
        case .killed: return Color(nsColor: .systemRed)
        }
    }

    private var inactiveTextColor: Color {
        Color(.secondaryLabelColor)
    }

    private var rowBackground: Color {
        if isActive {
            return colorScheme == .dark
                ? WorkspaceLayout.activeRowDark
                : WorkspaceLayout.activeRowLight
        }
        if isHovered {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }

    private var statusLabel: String {
        switch status {
        case .running: return "running"
        case .exited: return "exited"
        case .killed: return "killed"
        }
    }
}
