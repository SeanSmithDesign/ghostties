import AppKit
import SwiftUI

/// An NSView that contains the workspace sidebar alongside the existing terminal view.
/// This replaces TerminalViewContainer as the window's contentView.
///
/// Phase 1: The sidebar is a static placeholder. The terminal side is a standard
/// TerminalViewContainer, completely untouched.
class WorkspaceViewContainer<ViewModel: TerminalViewModel>: NSView {
    private let sidebarHostingView: NSView
    private let terminalContainer: TerminalViewContainer<ViewModel>

    init(ghostty: Ghostty.App, viewModel: ViewModel, delegate: (any TerminalViewDelegate)? = nil) {
        self.terminalContainer = TerminalViewContainer(
            ghostty: ghostty,
            viewModel: viewModel,
            delegate: delegate
        )

        let sidebarView = WorkspaceSidebarView()
        let hostingView = NSHostingView(rootView: sidebarView)
        hostingView.sizingOptions = [.minSize]
        self.sidebarHostingView = hostingView

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        terminalContainer.intrinsicContentSize
    }

    private func setup() {
        addSubview(sidebarHostingView)
        addSubview(terminalContainer)

        sidebarHostingView.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Sidebar: pinned to leading edge, full height
            sidebarHostingView.topAnchor.constraint(equalTo: topAnchor),
            sidebarHostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarHostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarHostingView.widthAnchor.constraint(equalToConstant: 220),

            // Terminal: fills remaining space
            terminalContainer.topAnchor.constraint(equalTo: topAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: sidebarHostingView.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}
