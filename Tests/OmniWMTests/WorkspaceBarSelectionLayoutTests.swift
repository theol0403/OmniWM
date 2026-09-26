// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import SwiftUI
import XCTest

@MainActor
final class WorkspaceBarSelectionLayoutTests: XCTestCase {
    func testSelectionAcrossUnequalWorkspaceWidthsPreservesBarSize() {
        let items = makeItems()
        let sizes = items.map { selected in
            measuredSize(snapshot: makeSnapshot(items: items, focused: selected.id))
        }

        for size in sizes {
            XCTAssertEqual(size.width, sizes[0].width, accuracy: 0.5)
            XCTAssertEqual(size.height, 24, accuracy: 0.5)
        }
        XCTAssertEqual(
            measuredSize(snapshot: makeSnapshot(items: items, focused: nil)).width,
            sizes[0].width,
            accuracy: 0.5
        )
    }

    func testDisabledMotionSettlesSelectionAndContentChangesImmediately() {
        let items = makeItems()
        let snapshot = makeSnapshot(items: items, focused: items[0].id)
        let model = WorkspaceBarModel(snapshot: snapshot)
        let hostingView = NSHostingView(
            rootView: WorkspaceBarView(
                model: model,
                motionPolicy: MotionPolicy(animationsEnabled: false),
                onFocusWorkspace: { _ in },
                onFocusWindow: { _ in },
                onActivateScratchpad: { _ in }
            )
        )
        hostingView.layoutSubtreeIfNeeded()

        let states = [
            makeSnapshot(items: items, focused: items[2].id),
            makeSnapshot(items: Array(items.suffix(2)), focused: items[1].id),
            makeSnapshot(items: Array(items.reversed()), focused: items[0].id),
            snapshot
        ]
        for state in states {
            model.snapshot = state
            hostingView.layoutSubtreeIfNeeded()
            let expectedSize = measuredSize(snapshot: state)
            XCTAssertEqual(hostingView.fittingSize.width, expectedSize.width, accuracy: 0.5)
            XCTAssertEqual(hostingView.fittingSize.height, expectedSize.height, accuracy: 0.5)
        }
    }

    func testSplitSelectionMeasuresOnlyItsOwnIslandAfterFocusChanges() {
        let items = makeItems()

        for selected in items {
            let snapshot = makeSnapshot(items: items, focused: selected.id)
            let active = measuredSize(snapshot: snapshot, slice: .active)
            let secondary = measuredSize(snapshot: snapshot, slice: .secondary)
            let expectedActive = measuredSize(
                snapshot: makeSnapshot(items: [selected], focused: selected.id)
            )
            let expectedSecondary = measuredSize(
                snapshot: makeSnapshot(items: items.filter { $0.id != selected.id }, focused: nil)
            )
            XCTAssertEqual(active.width, expectedActive.width, accuracy: 0.5)
            XCTAssertEqual(secondary.width, expectedSecondary.width, accuracy: 0.5)
        }
    }

    private func measuredSize(
        snapshot: WorkspaceBarSnapshot,
        slice: WorkspaceBarIslandSlice = .all
    ) -> NSSize {
        let view = NSHostingView(rootView: WorkspaceBarMeasurementView(snapshot: snapshot, slice: slice))
        view.layoutSubtreeIfNeeded()
        return view.fittingSize
    }

    private func makeItems() -> [WorkspaceBarItem] {
        ["1", "Work and messages", "Code"].enumerated().map { index, name in
            let windows = (0 ..< index).map { windowIndex in
                let token = WindowToken(pid: 42, windowId: index * 10 + windowIndex + 1)
                return WorkspaceBarWindowItem(
                    id: token,
                    handle: WindowHandle(id: token),
                    windowId: token.windowId,
                    appName: "App \(windowIndex)",
                    bundleId: nil,
                    icon: nil,
                    isFocused: false,
                    windowCount: 1,
                    hiddenWindowCount: 0,
                    allWindows: []
                )
            }
            return WorkspaceBarItem(
                id: UUID(),
                name: name,
                rawName: name,
                isFocused: false,
                tiledWindows: windows,
                floatingWindows: []
            )
        }
    }

    private func makeSnapshot(
        items: [WorkspaceBarItem],
        focused: WorkspaceDescriptor.ID?
    ) -> WorkspaceBarSnapshot {
        WorkspaceBarSnapshot(
            projection: WorkspaceBarProjection(
                items: items.map { item in
                    WorkspaceBarItem(
                        id: item.id,
                        name: item.name,
                        rawName: item.rawName,
                        isFocused: item.id == focused,
                        tiledWindows: item.tiledWindows,
                        floatingWindows: item.floatingWindows
                    )
                },
                scratchpads: []
            ),
            showLabels: true,
            showSystemStatsButton: false,
            backgroundOpacity: 0.1,
            barHeight: 24,
            accentColor: nil,
            textColor: nil
        )
    }
}
