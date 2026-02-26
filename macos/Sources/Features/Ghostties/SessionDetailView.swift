import SwiftUI

/// A single session row: status dot + name + active highlight.
///
/// Used by ProjectDisclosureRow to render sessions under each project.
struct SessionRow: View {
    let session: AgentSession
    let status: SessionStatus
    var isActive: Bool = false
    var isEditing: Bool = false
    @Binding var editingName: String
    var isRenameFocused: FocusState<Bool>.Binding
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator

            if isEditing {
                TextField("Session name", text: $editingName)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused(isRenameFocused)
                    .onSubmit { onCommitRename() }
                    .onExitCommand { onCancelRename() }
                    .onChange(of: isRenameFocused.wrappedValue) { focused in
                        // Commit on focus loss (clicking away).
                        if !focused, isEditing { onCommitRename() }
                    }
            } else {
                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 32)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name), \(statusLabel)\(isActive ? ", active" : "")")
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .exited: return Color(.tertiaryLabelColor)
        case .killed: return .red
        }
    }

    private var statusLabel: String {
        switch status {
        case .running: return "running"
        case .exited: return "exited"
        case .killed: return "killed"
        }
    }
}
