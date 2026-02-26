import AppKit
import SwiftUI

/// An NSView that contains the workspace sidebar alongside the existing terminal view.
/// This replaces TerminalViewContainer as the window's contentView.
///
/// The sidebar is a SwiftUI view hierarchy (disclosure list) embedded in an
/// NSHostingView. The terminal side is the standard TerminalViewContainer, untouched.
/// Both are arranged via Auto Layout with an animated sidebar width constraint.
///
/// This container also creates and owns the `SessionCoordinator`, which bridges
/// the sidebar's SwiftUI world to the terminal controller's AppKit world.
class WorkspaceViewContainer<ViewModel: TerminalViewModel>: NSView {
    private let sidebarHostingView: NSView
    private let terminalContainer: TerminalViewContainer<ViewModel>
    private let coordinator: SessionCoordinator

    /// Stored constraint for animating sidebar show/hide.
    private var sidebarWidthConstraint: NSLayoutConstraint!

    init(ghostty: Ghostty.App, viewModel: ViewModel, delegate: (any TerminalViewDelegate)? = nil) {
        self.terminalContainer = TerminalViewContainer(
            ghostty: ghostty,
            viewModel: viewModel,
            delegate: delegate
        )

        self.coordinator = SessionCoordinator(ghostty: ghostty)

        let sidebarView = WorkspaceSidebarView()
            .environmentObject(WorkspaceStore.shared)
            .environmentObject(coordinator)
        let hostingView = NSHostingView(rootView: sidebarView)
        // Auto Layout controls the sidebar width; disable intrinsic size reporting
        // to avoid unnecessary layout computation from the hosting view.
        hostingView.sizingOptions = []
        self.sidebarHostingView = hostingView

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        // Give the coordinator a reference to this view so it can discover
        // the window controller through the responder chain.
        coordinator.containerView = self

        // The workspace sidebar replaces the native tab bar — sessions are the new "tabs".
        // Disallow native tabbing to prevent a visual conflict (tab bar + sidebar).
        window.tabbingMode = .disallowed

        // Extend content under titlebar — traffic lights appear inside the sidebar panel.
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }

    override var intrinsicContentSize: NSSize {
        let termSize = terminalContainer.intrinsicContentSize
        guard termSize.width != NSView.noIntrinsicMetric else { return termSize }
        let sidebarWidth = sidebarWidthConstraint?.constant ?? WorkspaceLayout.sidebarWidth
        return NSSize(width: termSize.width + sidebarWidth, height: termSize.height)
    }

    // MARK: - Sidebar Toggle

    /// Whether the sidebar is currently visible.
    var isSidebarVisible: Bool {
        sidebarWidthConstraint.constant > 0
    }

    /// Toggle sidebar visibility with animation.
    @objc func toggleSidebar() {
        let hiding = isSidebarVisible

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarWidthConstraint.animator().constant = hiding ? 0 : WorkspaceLayout.sidebarWidth
        }
        // Rounded leading corners when sidebar visible, square when hidden.
        terminalContainer.layer?.cornerRadius = hiding ? 0 : WorkspaceLayout.terminalCornerRadius
        WorkspaceStore.shared.sidebarVisible = !hiding
    }

    // MARK: - Layout

    private func setup() {
        // Z-order: sidebar behind, terminal on top.
        addSubview(sidebarHostingView)
        addSubview(terminalContainer)

        sidebarHostingView.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false

        // Read persisted sidebar visibility.
        let sidebarVisible = WorkspaceStore.shared.sidebarVisible
        let initialWidth: CGFloat = sidebarVisible ? WorkspaceLayout.sidebarWidth : 0

        sidebarWidthConstraint = sidebarHostingView.widthAnchor.constraint(equalToConstant: initialWidth)

        NSLayoutConstraint.activate([
            // Sidebar: flush to window edges (no insets).
            sidebarHostingView.topAnchor.constraint(equalTo: topAnchor),
            sidebarHostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarHostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidthConstraint,

            // Terminal: leading edge meets sidebar trailing, extends under titlebar.
            terminalContainer.topAnchor.constraint(equalTo: topAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: sidebarHostingView.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Terminal rounded leading corners (top-left, bottom-left).
        terminalContainer.wantsLayer = true
        terminalContainer.layer?.cornerRadius = sidebarVisible ? WorkspaceLayout.terminalCornerRadius : 0
        terminalContainer.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        terminalContainer.layer?.masksToBounds = true
    }
}
