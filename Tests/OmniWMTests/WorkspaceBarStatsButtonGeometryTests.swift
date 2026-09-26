// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

final class WorkspaceBarStatsButtonGeometryTests: XCTestCase {
    func testStatsButtonAnchorUsesBottomCenterOfInlineButton() {
        let buttonFrame = CGRect(x: 628, y: 950, width: 22, height: 20)

        let anchor = WorkspaceBarGeometry.statsButtonAnchor(buttonFrame: buttonFrame)

        XCTAssertEqual(anchor, CGPoint(x: 639, y: 950))
    }

    func testStatsButtonAnchorTracksMovedInlineButton() {
        let first = WorkspaceBarGeometry.statsButtonAnchor(
            buttonFrame: CGRect(x: 628, y: 950, width: 22, height: 20)
        )
        let moved = WorkspaceBarGeometry.statsButtonAnchor(
            buttonFrame: CGRect(x: 700, y: 926, width: 22, height: 20)
        )

        XCTAssertEqual(moved.x - first.x, 72)
        XCTAssertEqual(moved.y, 926)
    }

    @MainActor
    func testAnchorReporterTracksWindowAndButtonMovementWithoutASwiftUIUpdate() throws {
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.setFrame(CGRect(x: 100, y: 300, width: 300, height: 24), display: false)
        defer { panel.close() }
        let view = WorkspaceBarAnchorView(frame: CGRect(x: 270, y: 2, width: 20, height: 20))
        var lastAnchor: CGPoint?
        view.onGeometryChange = { view in
            lastAnchor = view.window.map { window in
                WorkspaceBarGeometry.statsButtonAnchor(
                    buttonFrame: window.convertToScreen(view.convert(view.bounds, to: nil))
                )
            }
        }
        panel.contentView?.addSubview(view)
        let initial = try XCTUnwrap(lastAnchor)
        let initialOrigin = panel.frame.origin

        panel.setFrameOrigin(CGPoint(x: initialOrigin.x + 70, y: initialOrigin.y - 30))
        let moved = try XCTUnwrap(lastAnchor)
        XCTAssertEqual(moved.x - initial.x, panel.frame.minX - initialOrigin.x, accuracy: 0.5)
        XCTAssertEqual(moved.y - initial.y, panel.frame.minY - initialOrigin.y, accuracy: 0.5)

        view.setFrameOrigin(CGPoint(x: 220, y: 2))
        XCTAssertEqual(try XCTUnwrap(lastAnchor).x, moved.x - 50, accuracy: 0.5)

        view.removeFromSuperview()
        XCTAssertNil(lastAnchor)
    }
}
