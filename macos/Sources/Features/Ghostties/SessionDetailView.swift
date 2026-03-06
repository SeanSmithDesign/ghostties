import SwiftUI

/// A single session row: name + ghost character status indicator.
///
/// Used by ProjectDisclosureRow to render sessions under each project.
/// Ghost character appears on the right, colored by session indicator state.
/// Supports bounce animation (active), completed flash, and reduce-motion.
struct SessionRow: View {
    let session: AgentSession
    let indicatorState: SessionIndicatorState
    var ghostCharacter: GhostCharacter? = nil
    var isActive: Bool = false
    var isEditing: Bool = false
    @Binding var editingName: String
    var isRenameFocused: FocusState<Bool>.Binding
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isBouncing = false
    @State private var completedFlashActive = false

    /// Whether animations should be suppressed (Reduce Motion preference).
    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

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
        .onChange(of: indicatorState) { newState in
            updateAnimations(for: newState)
        }
        .onAppear {
            updateAnimations(for: indicatorState)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name), \(statusLabel)\(isActive ? ", active" : "")")
    }

    // MARK: - Ghost Indicator

    @ViewBuilder
    private var ghostIndicator: some View {
        let indicator = indicatorContent
            .offset(y: isBouncing && !reduceMotion ? -2 : 0)
            .animation(
                isBouncing && !reduceMotion
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: isBouncing
            )

        indicator
    }

    @ViewBuilder
    private var indicatorContent: some View {
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
        if completedFlashActive {
            return Color(nsColor: .systemGreen)
        }

        switch indicatorState {
        case .active:    return Color(nsColor: .systemGreen)
        case .waiting:   return WorkspaceLayout.waitingTerracotta
        case .completed: return Color(.tertiaryLabelColor)
        case .error:     return Color(nsColor: .systemRed)
        case .killed:    return Color(nsColor: .systemRed).opacity(0.6)
        case .exited:    return Color(.tertiaryLabelColor)
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
        switch indicatorState {
        case .active:    return "active"
        case .waiting:   return "waiting"
        case .completed: return "completed"
        case .error:     return "error"
        case .killed:    return "killed"
        case .exited:    return "exited"
        }
    }

    // MARK: - Animation Control

    private func updateAnimations(for state: SessionIndicatorState) {
        // Bounce: only when active
        isBouncing = (state == .active)

        // Completed flash: green for 1.5s then crossfade to gray
        if state == .completed && !reduceMotion {
            completedFlashActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    completedFlashActive = false
                }
            }
        } else {
            completedFlashActive = false
        }
    }
}
