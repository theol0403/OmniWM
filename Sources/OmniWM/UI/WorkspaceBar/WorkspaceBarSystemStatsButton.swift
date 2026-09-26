// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
import SwiftUI

@MainActor
struct SystemStatsButtonView: View {
    let itemHeight: CGFloat
    var animationsEnabled = false
    let showItemBackgrounds: Bool
    let showAccentHighlights: Bool
    let accentColor: Color?
    let textColor: Color?
    let onToggle: () -> Void
    let onAnchorChange: (CGPoint?) -> Void

    @State private var isHovered = false

    private var buttonSize: CGFloat {
        max(18, itemHeight)
    }

    private var iconColor: Color {
        if isHovered, showAccentHighlights {
            return accentColor ?? .accentColor
        }
        return textColor ?? .secondary
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: max(11, itemHeight * 0.58), weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: buttonSize, height: buttonSize)
                .background {
                    if showItemBackgrounds {
                        buttonShape
                            .fill(isHovered ? .regularMaterial : .thinMaterial)
                            .overlay {
                                buttonShape.strokeBorder(
                                    Color.secondary.opacity(isHovered ? 0.3 : 0.18),
                                    lineWidth: 0.75
                                )
                            }
                    }
                }
                .contentShape(buttonShape)
                .background(WorkspaceBarAnchorReporter(onChange: onAnchorChange))
        }
        .buttonStyle(.plain)
        .animation(animationsEnabled ? .easeOut(duration: 0.12) : nil, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel("System stats")
        .help("Show system stats")
    }
}

private struct WorkspaceBarAnchorReporter: NSViewRepresentable {
    let onChange: (CGPoint?) -> Void

    func makeNSView(context: Context) -> WorkspaceBarAnchorView {
        let view = WorkspaceBarAnchorView(frame: .zero)
        view.onGeometryChange = context.coordinator.report
        return view
    }

    func updateNSView(_ nsView: WorkspaceBarAnchorView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.report(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    @MainActor
    final class Coordinator {
        private let onChange: (CGPoint?) -> Void
        private var lastAnchor: CGPoint?

        init(onChange: @escaping (CGPoint?) -> Void) {
            self.onChange = onChange
        }

        func report(_ view: NSView) {
            let anchor: CGPoint?
            if let window = view.window {
                let localFrame = view.convert(view.bounds, to: nil)
                let screenFrame = window.convertToScreen(localFrame)
                anchor = WorkspaceBarGeometry.statsButtonAnchor(buttonFrame: screenFrame)
            } else {
                anchor = nil
            }
            if anchor != lastAnchor {
                lastAnchor = anchor
                onChange(anchor)
            }
        }
    }
}

@MainActor
final class WorkspaceBarAnchorView: NSView {
    var onGeometryChange: ((NSView) -> Void)?
    private var windowObserver: WorkspaceBarWindowGeometryObserver?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObserver = window.map { window in
            WorkspaceBarWindowGeometryObserver(window: window) { [weak self] in
                self?.reportGeometry()
            }
        }
        reportGeometry()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        reportGeometry()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        reportGeometry()
    }

    override func layout() {
        super.layout()
        reportGeometry()
    }

    private func reportGeometry() {
        onGeometryChange?(self)
    }
}

@MainActor
private final class WorkspaceBarWindowGeometryObserver: NSObject {
    private let onChange: () -> Void

    init(window: NSWindow, onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reportGeometry),
                name: name,
                object: window
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reportGeometry() {
        onChange()
    }
}
