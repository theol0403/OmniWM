// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import SwiftUI
import XCTest

@MainActor
final class WorkspaceBarLeadingLayoutTests: XCTestCase {
    func testGrowingContentStaysAtTheLeadingEdgeOfAnExpandingPanel() throws {
        let initial = snapshot(firstLabel: "1")
        let expanded = snapshot(firstLabel: "1 More Applications")
        let initialWidth = try idealWidth(initial)
        let finalWidth = try idealWidth(expanded)
        XCTAssertGreaterThan(finalWidth, initialWidth + 26)
        let initialInset = try outlineLeadingEdge(initial, panelWidth: initialWidth)

        for step in 0 ... 4 {
            let panelWidth = initialWidth + (finalWidth - initialWidth) * CGFloat(step) / 4
            let inset = try outlineLeadingEdge(expanded, panelWidth: panelWidth)
            XCTAssertEqual(inset, initialInset, accuracy: 0.5, "Panel width \(panelWidth)")
            XCTAssertGreaterThan(inset, 2, "The selector's left edge must not clip against the panel")
        }
    }

    func testShrinkingContentStaysAtTheLeadingEdgeOfAContractingPanel() throws {
        let initial = snapshot(firstLabel: "1 More Applications")
        let contracted = snapshot(firstLabel: "1")
        let initialWidth = try idealWidth(initial)
        let finalWidth = try idealWidth(contracted)
        let initialInset = try outlineLeadingEdge(initial, panelWidth: initialWidth)

        for step in 0 ... 4 {
            let panelWidth = initialWidth + (finalWidth - initialWidth) * CGFloat(step) / 4
            let inset = try outlineLeadingEdge(contracted, panelWidth: panelWidth)
            XCTAssertEqual(inset, initialInset, accuracy: 0.5, "Panel width \(panelWidth)")
        }
    }

    private func outlineLeadingEdge(_ snapshot: WorkspaceBarSnapshot, panelWidth: CGFloat) throws -> CGFloat {
        let model = WorkspaceBarModel(snapshot: snapshot)
        let view = WorkspaceBarView(
            model: model,
            motionPolicy: MotionPolicy(animationsEnabled: false),
            onFocusWorkspace: { _ in },
            onFocusWindow: { _ in },
            onActivateScratchpad: { _ in }
        )
        let renderer = ImageRenderer(content: view.frame(width: panelWidth, height: 30).clipped())
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
        var minimumX: Int?
        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5, color.blueComponent > 0.8,
                      color.redComponent < 0.2, color.greenComponent < 0.2
                else { continue }
                minimumX = min(minimumX ?? x, x)
            }
        }
        return CGFloat(try XCTUnwrap(minimumX, "The real bar must render its selector")) / renderer.scale
    }

    private func idealWidth(_ snapshot: WorkspaceBarSnapshot) throws -> CGFloat {
        let renderer = ImageRenderer(content: WorkspaceBarMeasurementView(snapshot: snapshot))
        renderer.scale = 2
        return CGFloat(try XCTUnwrap(renderer.cgImage).width) / renderer.scale
    }

    private func snapshot(firstLabel: String) -> WorkspaceBarSnapshot {
        WorkspaceBarSnapshot(
            projection: WorkspaceBarProjection(
                items: [firstLabel, "2"].enumerated().map { index, label in
                    WorkspaceBarItem(
                        id: UUID(), name: label, rawName: String(index + 1), isFocused: index == 0,
                        tiledWindows: [], floatingWindows: []
                    )
                },
                scratchpads: []
            ),
            showLabels: true,
            showSystemStatsButton: false,
            backgroundOpacity: 0,
            transparentBackground: true,
            showItemBackgrounds: false,
            barHeight: 30,
            accentColor: SettingsColor(red: 0, green: 0, blue: 1, alpha: 1),
            textColor: SettingsColor(red: 1, green: 1, blue: 1, alpha: 1)
        )
    }
}
