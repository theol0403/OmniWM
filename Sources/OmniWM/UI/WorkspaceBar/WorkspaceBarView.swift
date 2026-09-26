// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
import SwiftUI

@MainActor
struct WorkspaceBarView: View {
    let model: WorkspaceBarModel
    var slice: WorkspaceBarIslandSlice = .all
    var showsSystemStatsButton = false
    @Bindable var motionPolicy: MotionPolicy
    let onFocusWorkspace: (WorkspaceBarItem) -> Void
    let onFocusWindow: (WindowHandle) -> Void
    let onActivateScratchpad: (Int) -> Void
    var onToggleSystemStats: () -> Void = {}
    var onSystemStatsAnchorChange: (CGPoint?) -> Void = { _ in }
    var interaction: WorkspaceBarIslandInteraction?
    var dragPresentation: WorkspaceBarDragPresentation?

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        WorkspaceBarContentView(
            snapshot: model.snapshot,
            slice: slice,
            showsSystemStatsButton: showsSystemStatsButton,
            animationsEnabled: motionPolicy.animationsEnabled && !accessibilityReduceMotion,
            onFocusWorkspace: onFocusWorkspace,
            onFocusWindow: onFocusWindow,
            onActivateScratchpad: onActivateScratchpad,
            onToggleSystemStats: onToggleSystemStats,
            onSystemStatsAnchorChange: onSystemStatsAnchorChange
        )
        .environment(\.workspaceBarInteraction, interaction)
        .environment(model)
        .environment(dragPresentation)
    }
}

@MainActor
struct WorkspaceBarMeasurementView: View {
    let snapshot: WorkspaceBarSnapshot
    var slice: WorkspaceBarIslandSlice = .all
    var showsSystemStatsButton = false

    var body: some View {
        WorkspaceBarContentView(
            snapshot: snapshot,
            slice: slice,
            showsSystemStatsButton: showsSystemStatsButton,
            animationsEnabled: false,
            onFocusWorkspace: { _ in },
            onFocusWindow: { _ in },
            onActivateScratchpad: { _ in },
            onToggleSystemStats: {},
            onSystemStatsAnchorChange: { _ in }
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

@MainActor
private struct WorkspaceBarContentView: View {
    let snapshot: WorkspaceBarSnapshot
    var slice: WorkspaceBarIslandSlice = .all
    var showsSystemStatsButton = false
    let animationsEnabled: Bool
    let onFocusWorkspace: (WorkspaceBarItem) -> Void
    let onFocusWindow: (WindowHandle) -> Void
    let onActivateScratchpad: (Int) -> Void
    let onToggleSystemStats: () -> Void
    let onSystemStatsAnchorChange: (CGPoint?) -> Void

    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var animation: Animation? {
        animationsEnabled ? .spring(response: 0.28, dampingFraction: 0.9) : nil
    }

    private var itemHeight: CGFloat {
        max(16, snapshot.barHeight - 4)
    }

    private var iconSize: CGFloat {
        max(12, itemHeight - 6)
    }

    private let workspaceSpacing: CGFloat = 8
    private let windowSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 6

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(snapshot.backgroundOpacity)
            : Color.black.opacity(snapshot.backgroundOpacity * 0.5)
    }

    private var accentColor: Color? {
        snapshot.accentColor?.swiftUIColor
    }

    private var textColor: Color? {
        snapshot.textColor?.swiftUIColor
    }

    private var barShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    private func workspaceBackgrounds(_ geometries: [WorkspaceDescriptor.ID: WorkspaceItemGeometry]) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(slice.items(in: snapshot), id: \.id) { item in
                    if snapshot.showItemBackgrounds, let geometry = geometries[item.id] {
                        let frame = proxy[geometry.bounds]
                        WorkspaceBarItemShape(rect: frame, cornerRadius: cornerRadius)
                            .fill(.regularMaterial)
                            .opacity(geometry.isHovered || item.isFocused ? 1 : 0)
                            .animation(animationsEnabled ? .easeOut(duration: 0.12) : nil, value: geometry.isHovered)
                    }
                }

                if snapshot.showAccentHighlights,
                   let focusedItem = slice.items(in: snapshot).first(where: \.isFocused),
                   let geometry = geometries[focusedItem.id]
                {
                    let frame = proxy[geometry.bounds]
                    WorkspaceBarItemShape(rect: frame, cornerRadius: cornerRadius)
                        .strokeBorder(accentColor ?? .accentColor, lineWidth: 1)
                        .animation(animation, value: focusedItem.id)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    var body: some View {
        HStack(spacing: workspaceSpacing) {
            ForEach(slice.items(in: snapshot), id: \.id) { item in
                WorkspaceItemView(
                    item: item,
                    iconSize: iconSize,
                    itemHeight: itemHeight,
                    windowSpacing: windowSpacing,
                    cornerRadius: cornerRadius,
                    animationsEnabled: animationsEnabled,
                    showLabels: snapshot.showLabels,
                    showItemBackgrounds: snapshot.showItemBackgrounds,
                    showAccentHighlights: snapshot.showAccentHighlights,
                    inactiveIconOpacity: snapshot.inactiveIconOpacity,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWorkspace: { onFocusWorkspace(item) },
                    onFocusWindow: onFocusWindow
                )
                .transition(.opacity)
            }

            ForEach(slice.scratchpads(in: snapshot)) { scratchpad in
                ScratchpadPillView(
                    item: scratchpad,
                    iconSize: iconSize,
                    itemHeight: itemHeight,
                    animationsEnabled: animationsEnabled,
                    showItemBackgrounds: snapshot.showItemBackgrounds,
                    showAccentHighlights: snapshot.showAccentHighlights,
                    inactiveIconOpacity: snapshot.inactiveIconOpacity,
                    accentColor: accentColor,
                    textColor: textColor,
                    onActivateScratchpad: onActivateScratchpad
                )
                .transition(.opacity)
            }

            if showsSystemStatsButton {
                SystemStatsButtonView(
                    itemHeight: itemHeight,
                    animationsEnabled: animationsEnabled,
                    showItemBackgrounds: snapshot.showItemBackgrounds,
                    showAccentHighlights: snapshot.showAccentHighlights,
                    accentColor: accentColor,
                    textColor: textColor,
                    onToggle: onToggleSystemStats,
                    onAnchorChange: onSystemStatsAnchorChange
                )
            }
        }
        .padding(.horizontal, 4)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .frame(height: itemHeight + 4)
        .backgroundPreferenceValue(WorkspaceItemGeometryPreferenceKey.self) { geometry in
            workspaceBackgrounds(geometry)
        }
        .background {
            if snapshot.backgroundStyle == .solidBlack {
                Rectangle().fill(Color.black)
            } else if snapshot.backgroundStyle == .material {
                if accessibilityReduceTransparency {
                    barShape.fill(Color(NSColor.windowBackgroundColor).opacity(0.96))
                } else {
                    barShape
                        .fill(backgroundColor)
                        .background(.ultraThinMaterial, in: barShape)
                }

                barShape.strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.primary.opacity(0.45)
                        : Color.secondary.opacity(0.18),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(animation, value: snapshot)
        .animation(animation, value: slice)
        .animation(animation, value: showsSystemStatsButton)
        .transaction { transaction in
            if !animationsEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

private struct WorkspaceItemGeometry {
    let bounds: Anchor<CGRect>
    let isHovered: Bool
}

private struct WorkspaceItemGeometryPreferenceKey: PreferenceKey {
    static var defaultValue: [WorkspaceDescriptor.ID: WorkspaceItemGeometry] {
        [:]
    }

    static func reduce(
        value: inout [WorkspaceDescriptor.ID: WorkspaceItemGeometry],
        nextValue: () -> [WorkspaceDescriptor.ID: WorkspaceItemGeometry]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

@MainActor
private struct WorkspaceItemView: View {
    let item: WorkspaceBarItem
    let iconSize: CGFloat
    let itemHeight: CGFloat
    let windowSpacing: CGFloat
    let cornerRadius: CGFloat
    let animationsEnabled: Bool
    let showLabels: Bool
    let showItemBackgrounds: Bool
    let showAccentHighlights: Bool
    let inactiveIconOpacity: Double?
    let accentColor: Color?
    let textColor: Color?
    let onFocusWorkspace: () -> Void
    let onFocusWindow: (WindowHandle) -> Void

    @State private var isHovered = false
    @Environment(\.workspaceBarInteraction) private var interaction
    @Environment(WorkspaceBarDragPresentation.self) private var drag: WorkspaceBarDragPresentation?

    private var isDropTarget: Bool {
        drag?.highlights.contains(.workspace(item.id)) == true
    }

    private var dropGapIndex: Int? {
        drag?.highlights.lazy.compactMap { highlight -> Int? in
            guard case let .gap(workspaceId, index) = highlight, workspaceId == item.id else { return nil }
            return index
        }.first
    }

    private func reflowOffset(forIconAt index: Int) -> CGFloat {
        guard let gap = dropGapIndex else { return 0 }
        let halfGap = min(8, iconSize * 0.4) / 2
        return index < gap ? -halfGap : halfGap
    }

    var body: some View {
        HStack(spacing: windowSpacing) {
            if showLabels {
                WorkspaceLabelButton(
                    item: item,
                    showAccentHighlights: showAccentHighlights,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWorkspace: onFocusWorkspace
                )

                if !item.windows.isEmpty {
                    Divider()
                        .frame(height: iconSize)
                        .padding(.horizontal, 2)
                        .accessibilityHidden(true)
                }
            } else if item.windows.isEmpty {
                WorkspaceLabelButton(
                    item: item,
                    showAccentHighlights: showAccentHighlights,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWorkspace: onFocusWorkspace
                )
            }

            ForEach(Array(item.tiledWindows.enumerated()), id: \.element.id) { index, window in
                WindowIconView(
                    window: window,
                    workspaceId: item.id,
                    iconSize: iconSize,
                    isFocused: window.isFocused,
                    isInFocusedWorkspace: item.isFocused,
                    context: .tiled,
                    animationsEnabled: animationsEnabled,
                    showAccentHighlights: showAccentHighlights,
                    inactiveIconOpacity: inactiveIconOpacity,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWindow: onFocusWindow
                )
                .offset(x: reflowOffset(forIconAt: index))
                .animation(animationsEnabled ? .spring(duration: 0.2) : nil, value: dropGapIndex)
                .workspaceBarHitRegion(.window(item.id, window.id))
            }

            if !item.tiledWindows.isEmpty && !item.floatingWindows.isEmpty {
                Divider()
                    .frame(height: iconSize)
                    .padding(.horizontal, 2)
                    .accessibilityHidden(true)
            }

            if !item.floatingWindows.isEmpty {
                WorkspaceBarFloatingWindowsGroupView(
                    windows: item.floatingWindows,
                    workspaceId: item.id,
                    iconSize: iconSize,
                    itemHeight: itemHeight,
                    isInFocusedWorkspace: item.isFocused,
                    animationsEnabled: animationsEnabled,
                    showItemBackgrounds: showItemBackgrounds,
                    showAccentHighlights: showAccentHighlights,
                    inactiveIconOpacity: inactiveIconOpacity,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWindow: onFocusWindow
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(height: itemHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .workspaceBarHitRegion(.workspace(item.id))
        .onTapGesture(perform: onFocusWorkspace)
        .background {
            if isDropTarget {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(accentColor ?? .accentColor, lineWidth: 1.5)
            }
        }
        .anchorPreference(key: WorkspaceItemGeometryPreferenceKey.self, value: .bounds) {
            [item.id: WorkspaceItemGeometry(bounds: $0, isHovered: isHovered)]
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.showMenu) {
            interaction?.onShowMenu(.workspace(item.id))
        }
    }
}

@MainActor
private struct WorkspaceLabelButton: View {
    let item: WorkspaceBarItem
    let showAccentHighlights: Bool
    let accentColor: Color?
    let textColor: Color?
    let onFocusWorkspace: () -> Void

    private var resolvedAccentColor: Color {
        accentColor ?? .accentColor
    }

    private var resolvedLabelColor: Color {
        if let textColor {
            return textColor
        }
        return item.isFocused && showAccentHighlights ? resolvedAccentColor : .secondary
    }

    var body: some View {
        Button(action: onFocusWorkspace) {
            Text(item.name)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundColor(resolvedLabelColor)
                .lineLimit(1)
                .frame(minWidth: 16)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .workspaceBarLabelRegion(item.id)
        .accessibilityLabel("Workspace \(item.name)")
        .accessibilityValue(item.isFocused ? String(localized: "Focused") : "")
        .help("Focus workspace \(item.name)")
    }
}
