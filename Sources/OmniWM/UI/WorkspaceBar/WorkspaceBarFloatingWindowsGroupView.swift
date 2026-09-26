// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import SwiftUI

@MainActor
struct WorkspaceBarFloatingWindowsGroupView: View {
    let windows: [WorkspaceBarWindowItem]
    let workspaceId: WorkspaceDescriptor.ID
    let iconSize: CGFloat
    let itemHeight: CGFloat
    let isInFocusedWorkspace: Bool
    let animationsEnabled: Bool
    let showItemBackgrounds: Bool
    let showAccentHighlights: Bool
    let inactiveIconOpacity: Double?
    let accentColor: Color?
    let textColor: Color?
    let onFocusWindow: (WindowHandle) -> Void

    private var resolvedSecondaryTextColor: Color {
        textColor ?? .secondary
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: max(10, iconSize * 0.58), weight: .medium))
                .foregroundStyle(resolvedSecondaryTextColor)
                .accessibilityHidden(true)

            ForEach(windows, id: \.id) { window in
                WindowIconView(
                    window: window,
                    workspaceId: workspaceId,
                    iconSize: iconSize,
                    isFocused: window.isFocused,
                    isInFocusedWorkspace: isInFocusedWorkspace,
                    context: .floating,
                    animationsEnabled: animationsEnabled,
                    showAccentHighlights: showAccentHighlights,
                    inactiveIconOpacity: inactiveIconOpacity,
                    accentColor: accentColor,
                    textColor: textColor,
                    onFocusWindow: onFocusWindow
                )
                .workspaceBarHitRegion(.window(workspaceId, window.id))
            }
        }
        .padding(.horizontal, 5)
        .frame(height: max(16, itemHeight - 2))
        .background {
            if showItemBackgrounds {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.24), lineWidth: 0.75)
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Floating windows")
    }
}
