// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import SwiftUI
import XCTest

final class WorkspaceBarItemShapeTests: XCTestCase {
    func testGrowingFirstWorkspaceKeepsItsLeadingEdgeWhileThePanelResizes() {
        let initial = WorkspaceBarItemShape(rect: CGRect(x: 4, y: 2, width: 234, height: 26))
        let target = WorkspaceBarItemShape(rect: CGRect(x: 4, y: 2, width: 260, height: 26))

        for step in 0 ... 20 {
            let progress = Double(step) / 20
            let presented = interpolated(initial, target, progress: progress)
            for panelWidth in [489, 515, 489 + 26 * progress] {
                let bounds = presented.path(in: CGRect(x: 0, y: 0, width: panelWidth, height: 30)).boundingRect
                XCTAssertEqual(bounds.minX, 4, accuracy: 0.001)
                XCTAssertEqual(bounds.maxX, 238 + 26 * progress, accuracy: 0.001)
            }
        }
    }

    func testShrinkingFirstWorkspaceDoesNotCrossThePanelLeadingEdge() {
        let initial = WorkspaceBarItemShape(rect: CGRect(x: 4, y: 2, width: 260, height: 26))
        let target = WorkspaceBarItemShape(rect: CGRect(x: 4, y: 2, width: 234, height: 26))

        for step in 0 ... 20 {
            let progress = Double(step) / 20
            let presented = interpolated(initial, target, progress: progress)
            let bounds = presented.inset(by: 0.5)
                .path(in: CGRect(x: 0, y: 0, width: 515 - 26 * progress, height: 30)).boundingRect
            XCTAssertEqual(bounds.minX, 4.5, accuracy: 0.001)
            XCTAssertEqual(bounds.minY, 2.5, accuracy: 0.001)
            XCTAssertEqual(bounds.maxX, 263.5 - 26 * progress, accuracy: 0.001)
            XCTAssertEqual(bounds.maxY, 27.5, accuracy: 0.001)
        }
    }

    func testRetargetingUsesThePresentedRectangleAcrossUnequalWorkspaceWidths() {
        let left = WorkspaceBarItemShape(rect: CGRect(x: 4, y: 2, width: 234, height: 26))
        let right = WorkspaceBarItemShape(rect: CGRect(x: 420, y: 2, width: 64, height: 26))
        let presented = interpolated(left, right, progress: 0.4)
        let reverseTarget = WorkspaceBarItemShape(rect: CGRect(x: 252, y: 2, width: 64, height: 26))
        let newOrigin = interpolated(presented, reverseTarget, progress: 0)
        XCTAssertEqual(newOrigin.path(in: .zero).boundingRect, presented.path(in: .zero).boundingRect)

        let midpoint = interpolated(presented, reverseTarget, progress: 0.5)
        let bounds = midpoint.path(in: CGRect(x: 0, y: 0, width: 489, height: 30)).boundingRect
        XCTAssertEqual(bounds.minX, (presented.rect.minX + reverseTarget.rect.minX) / 2, accuracy: 0.001)
        XCTAssertEqual(bounds.width, (presented.rect.width + reverseTarget.rect.width) / 2, accuracy: 0.001)
    }

    private func interpolated(
        _ initial: WorkspaceBarItemShape,
        _ target: WorkspaceBarItemShape,
        progress: Double
    ) -> WorkspaceBarItemShape {
        var shape = initial
        var displacement = target.animatableData - initial.animatableData
        displacement.scale(by: progress)
        shape.animatableData = initial.animatableData + displacement
        return shape
    }
}
