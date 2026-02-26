import AppKit
import Combine
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
    private let backgroundEffectView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let sidebarHostingView: NSView
    private let terminalContainer: TerminalViewContainer<ViewModel>
    private let coordinator: SessionCoordinator

    /// Shadow host wraps the terminal container so the drop shadow renders
    /// outside `masksToBounds` clipping. The shadow host carries the shadow;
    /// the inner terminal container clips its corners.
    private let terminalShadowHost: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Session name centered at the top of the terminal card (titlebar region).
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var cancellables = Set<AnyCancellable>()

    /// Stored constraints for animating sidebar show/hide and terminal insets.
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var shadowHostTopConstraint: NSLayoutConstraint!
    private var shadowHostLeadingConstraint: NSLayoutConstraint!
    private var shadowHostTrailingConstraint: NSLayoutConstraint!
    private var shadowHostBottomConstraint: NSLayoutConstraint!

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

        // The session title label replaces the macOS window title. Hide the native
        // titlebar text field directly — titleVisibility alone isn't reliable because
        // TerminalWindow's titlebar management can re-show it.
        DispatchQueue.main.async {
            window.contentView?
                .firstViewFromRoot(withClassName: "NSTitlebarContainerView")?
                .firstDescendant(withClassName: "NSTitlebarView")?
                .firstDescendant(withClassName: "NSTextField")?
                .isHidden = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let termSize = terminalContainer.intrinsicContentSize
        guard termSize.width != NSView.noIntrinsicMetric else { return termSize }
        let sidebarWidth = sidebarWidthConstraint?.constant ?? WorkspaceLayout.sidebarWidth
        let inset = isSidebarVisible ? WorkspaceLayout.terminalInset : 0
        return NSSize(
            width: termSize.width + sidebarWidth + inset * 2,
            height: termSize.height + inset * 2
        )
    }

    // MARK: - Sidebar Toggle

    /// Whether the sidebar is currently visible.
    var isSidebarVisible: Bool {
        sidebarWidthConstraint.constant > 0
    }

    /// Toggle sidebar visibility with animation.
    @objc func toggleSidebar() {
        let hiding = isSidebarVisible
        let inset = WorkspaceLayout.terminalInset

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarWidthConstraint.animator().constant = hiding ? 0 : WorkspaceLayout.sidebarWidth
            shadowHostTopConstraint.animator().constant = hiding ? 0 : inset
            shadowHostLeadingConstraint.animator().constant = hiding ? 0 : inset
            shadowHostTrailingConstraint.animator().constant = hiding ? 0 : -inset
            shadowHostBottomConstraint.animator().constant = hiding ? 0 : -inset
            titleLabel.animator().alphaValue = hiding ? 0 : 1
        }
        terminalContainer.layer?.cornerRadius = hiding ? 0 : WorkspaceLayout.terminalCornerRadius
        terminalShadowHost.layer?.shadowOpacity = hiding ? 0 : 0.15
        WorkspaceStore.shared.sidebarVisible = !hiding
    }

    // MARK: - Layout

    private func setup() {
        // Z-order: background material → sidebar → shadow host (with terminal inside).
        addSubview(backgroundEffectView)
        addSubview(sidebarHostingView)
        addSubview(terminalShadowHost)

        sidebarHostingView.translatesAutoresizingMaskIntoConstraints = false

        // Terminal lives inside the shadow host. The host carries the shadow;
        // the terminal clips its own corners via masksToBounds.
        terminalShadowHost.addSubview(terminalContainer)
        terminalShadowHost.addSubview(titleLabel)
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false

        // Read persisted sidebar visibility.
        let sidebarVisible = WorkspaceStore.shared.sidebarVisible
        let initialWidth: CGFloat = sidebarVisible ? WorkspaceLayout.sidebarWidth : 0

        sidebarWidthConstraint = sidebarHostingView.widthAnchor.constraint(equalToConstant: initialWidth)

        let inset: CGFloat = sidebarVisible ? WorkspaceLayout.terminalInset : 0

        // Inset constraints target the shadow host, not the terminal directly.
        shadowHostTopConstraint = terminalShadowHost.topAnchor.constraint(
            equalTo: topAnchor, constant: inset)
        shadowHostLeadingConstraint = terminalShadowHost.leadingAnchor.constraint(
            equalTo: sidebarHostingView.trailingAnchor, constant: inset)
        shadowHostTrailingConstraint = terminalShadowHost.trailingAnchor.constraint(
            equalTo: trailingAnchor, constant: -inset)
        shadowHostBottomConstraint = terminalShadowHost.bottomAnchor.constraint(
            equalTo: bottomAnchor, constant: -inset)

        NSLayoutConstraint.activate([
            backgroundEffectView.topAnchor.constraint(equalTo: topAnchor),
            backgroundEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            sidebarHostingView.topAnchor.constraint(equalTo: topAnchor),
            sidebarHostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarHostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidthConstraint,

            shadowHostTopConstraint,
            shadowHostLeadingConstraint,
            shadowHostBottomConstraint,
            shadowHostTrailingConstraint,

            // Terminal fills the shadow host.
            terminalContainer.topAnchor.constraint(equalTo: terminalShadowHost.topAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: terminalShadowHost.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: terminalShadowHost.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: terminalShadowHost.bottomAnchor),

            // Title label centered in the titlebar region of the card.
            titleLabel.centerXAnchor.constraint(equalTo: terminalShadowHost.centerXAnchor),
            titleLabel.topAnchor.constraint(
                equalTo: terminalShadowHost.topAnchor,
                constant: (WorkspaceLayout.titlebarSpacerHeight - 16) / 2),
        ])

        // Terminal floating card: all four corners rounded when sidebar visible.
        terminalContainer.wantsLayer = true
        terminalContainer.layer?.cornerRadius = sidebarVisible ? WorkspaceLayout.terminalCornerRadius : 0
        terminalContainer.layer?.masksToBounds = true

        // Configure shadow on the host layer. Must happen after addSubview so the
        // layer exists (wantsLayer in a property closure may not create it in time).
        terminalShadowHost.wantsLayer = true
        terminalShadowHost.layer?.shadowColor = NSColor.black.cgColor
        terminalShadowHost.layer?.shadowOpacity = sidebarVisible ? 0.15 : 0
        terminalShadowHost.layer?.shadowRadius = 8
        terminalShadowHost.layer?.shadowOffset = CGSize(width: 0, height: -2)

        // Hide title when sidebar starts collapsed.
        if !sidebarVisible {
            titleLabel.alphaValue = 0
        }

        // Bind title label to the active session name.
        coordinator.$activeSessionId
            .combineLatest(WorkspaceStore.shared.$sessions)
            .map { activeId, sessions -> String in
                guard let id = activeId,
                      let session = sessions.first(where: { $0.id == id })
                else { return "" }
                return session.name
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.titleLabel.stringValue = name
            }
            .store(in: &cancellables)
    }
}
