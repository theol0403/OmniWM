// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import SwiftUI
import XCTest

@MainActor
final class WorkspaceBarAnimatedInteractionTests: XCTestCase {
    private let firstId = WorkspaceDescriptor.ID()
    private let secondId = WorkspaceDescriptor.ID()

    private struct Fixture {
        let model: WorkspaceBarModel
        let island: WorkspaceBarIslandPanel
    }

    func testTiledFloatingAndLabelRegionsFollowContentFocusAndPanelWidthChanges() async throws {
        let fixture = makeFixture(animationsEnabled: true)
        let panel = fixture.island.panel
        defer { panel.close() }
        panel.orderFrontRegardless()
        let initialItems = items()
        fixture.island.hostingView.layoutSubtreeIfNeeded()
        try assertRegions(in: fixture, items: initialItems)
        let initialSecond = try XCTUnwrap(fixture.island.interaction.frames[.workspace(secondId)])

        let expanded = items(extraFloatingWindow: true)
        fixture.model.snapshot = snapshot(items: expanded, focused: secondId)
        fixture.island.applyFrame(CGRect(x: 160, y: 700, width: 840, height: 30), using: applyFrame)
        try await settleHostedLayout(fixture)
        try assertRegions(in: fixture, items: expanded)
        let expandedSecond = try XCTUnwrap(fixture.island.interaction.frames[.workspace(secondId)])
        XCTAssertGreaterThan(expandedSecond.minX, initialSecond.minX)

        fixture.model.snapshot = snapshot(items: Array(initialItems.reversed()), focused: firstId)
        fixture.island.applyFrame(CGRect(x: 230, y: 700, width: 660, height: 30), using: applyFrame)
        try await settleHostedLayout(fixture)
        try assertRegions(in: fixture, items: initialItems)
        let first = try XCTUnwrap(fixture.island.interaction.frames[.workspace(firstId)])
        let second = try XCTUnwrap(fixture.island.interaction.frames[.workspace(secondId)])
        XCTAssertLessThan(second.maxX, first.minX)
        XCTAssertNil(fixture.island.interaction.frames[.window(firstId, window(3).id)])
    }

    func testNativePanelTranslationRefreshesCachedDragDropGeometry() throws {
        let fixture = makeFixture(animationsEnabled: false)
        defer { fixture.island.panel.close() }
        let interaction = fixture.island.interaction
        fixture.island.hostingView.layoutSubtreeIfNeeded()
        let localFrames = interaction.frames
        let source = WorkspaceBarDragSource(tokens: [window(1).id], workspaceId: firstId, isFloating: false)
        let initialFrame = fixture.island.panel.frame

        for dropAtNewPosition in [true, false] {
            fixture.island.applyFrame(initialFrame, using: applyFrame)
            let controller = WorkspaceBarDragController()
            defer { controller.cancel() }
            var geometryBuilds = 0
            var committed: [WorkspaceBarDropAction] = []
            controller.geometryVersion = { interaction.generation }
            controller.geometryProvider = { [self] in
                geometryBuilds += 1
                return dropGeometry(in: fixture)
            }
            controller.commit = { action, _ in committed.append(action)
                return true
            }
            let oldDestination = try screenFrame(.workspace(secondId), in: fixture)
            let sourceFrame = try screenFrame(.workspace(firstId), in: fixture)
            controller.begin(source: source, icon: nil, at: midpoint(sourceFrame))
            let oldGeneration = interaction.generation

            fixture.island.applyFrame(initialFrame.offsetBy(dx: 600, dy: 0), using: applyFrame)
            fixture.island.hostingView.layoutSubtreeIfNeeded()
            XCTAssertEqual(
                interaction.frames,
                localFrames,
                "Local geometry does not change when the native panel translates"
            )
            XCTAssertGreaterThan(interaction.generation, oldGeneration)
            let newDestination = try screenFrame(.workspace(secondId), in: fixture)
            XCTAssertEqual(newDestination.minX - oldDestination.minX, 600, accuracy: 0.5)

            let point = midpoint(dropAtNewPosition ? newDestination : oldDestination)
            XCTAssertEqual(controller.end(at: point), dropAtNewPosition)
            XCTAssertEqual(committed, dropAtNewPosition ? [.moveToWorkspace(secondId)] : [])
            XCTAssertEqual(geometryBuilds, 2, "The drag must refresh its cached screen geometry after panel movement")
        }
    }

    func testSystemReduceMotionSettlesAnActiveNativeFrameAnimationAndPreservesUserChoice() async throws {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            throw XCTSkip(
                "A native frame animation cannot start while the real system Reduce Motion setting is enabled"
            )
        }
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        defer { panel.close() }
        let policy = MotionPolicy(animationsEnabled: true)
        let motion = WorkspaceBarFrameMotion(panel: panel, motionPolicy: policy)
        let initial = CGRect(x: 100, y: 700, width: 400, height: 30)
        var frames: [CGRect] = []
        let setter: (WorkspaceBarPanel, CGRect) -> Void = { panel, frame in
            frames.append(frame)
            panel.setFrame(frame, display: false)
        }
        motion.apply(initial, using: setter)
        panel.orderFrontRegardless()

        for target in [initial.offsetBy(dx: 160, dy: 0), initial] {
            policy.systemReducesMotion = false
            motion.apply(target, using: setter)
            XCTAssertTrue(motion.isAnimating)
            policy.systemReducesMotion = true
            for _ in 0 ..< 20 where motion.isAnimating {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertFalse(motion.isAnimating)
            XCTAssertEqual(panel.frame, target)
            XCTAssertEqual(frames.last, target)
            XCTAssertTrue(
                policy.userAnimationsEnabled,
                "System preference must not overwrite the user's animation choice"
            )
            let settledCount = frames.count
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertEqual(frames.count, settledCount, "A settled display link must not write more frames")
        }
    }

    func testOrderingPanelOutSettlesInFlightFrameWithoutAnotherApply() async throws {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            throw XCTSkip(
                "A native frame animation cannot start while the real system Reduce Motion setting is enabled"
            )
        }
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        defer { panel.close() }
        let motion = WorkspaceBarFrameMotion(panel: panel, motionPolicy: MotionPolicy())
        let initial = CGRect(x: 100, y: 700, width: 400, height: 30)
        let target = CGRect(x: 260, y: 700, width: 500, height: 30)
        var frames: [CGRect] = []
        let setter: (WorkspaceBarPanel, CGRect) -> Void = { panel, frame in
            frames.append(frame)
            panel.setFrame(frame, display: false)
        }
        motion.apply(initial, using: setter)
        panel.orderFrontRegardless()
        motion.apply(target, using: setter)
        XCTAssertTrue(motion.isAnimating)

        panel.orderOut(nil)

        XCTAssertFalse(motion.isAnimating, "The visibility transition must stop the link without a new layout request")
        XCTAssertEqual(panel.frame, target)
        XCTAssertEqual(frames.last, target)
        let settledCount = frames.count
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(frames.count, settledCount)
    }

    private func assertRegions(in fixture: Fixture, items: [WorkspaceBarItem]) throws {
        let interaction = fixture.island.interaction
        var expectedTargets = Set<WorkspaceBarHitTarget>()
        for item in items {
            expectedTargets.insert(.workspace(item.id))
            let workspace = try XCTUnwrap(interaction.frames[.workspace(item.id)])
            let label = try XCTUnwrap(interaction.labelFrames[item.id])
            XCTAssertGreaterThan(label.width, 0)
            XCTAssertTrue(workspace.contains(label))
            XCTAssertEqual(interaction.target(at: midpoint(label)), .workspace(item.id))
            for window in item.tiledWindows + item.floatingWindows {
                let target = WorkspaceBarHitTarget.window(item.id, window.id)
                expectedTargets.insert(target)
                let icon = try XCTUnwrap(interaction.frames[target])
                XCTAssertGreaterThan(icon.width, 0)
                XCTAssertTrue(
                    workspace.contains(icon),
                    "Both tiled and floating icons must remain in their own workspace"
                )
                XCTAssertEqual(interaction.target(at: midpoint(icon)), target)
                let screen = try screenFrame(target, in: fixture)
                XCTAssertTrue(fixture.island.panel.frame.contains(screen))
                let windowPoint = fixture.island.panel.convertPoint(fromScreen: midpoint(screen))
                let local = fixture.island.hostingView.workspaceBarLocalPoint(forWindowPoint: windowPoint)
                XCTAssertEqual(interaction.target(at: local), target)
            }
        }
        XCTAssertEqual(Set(interaction.frames.keys), expectedTargets)
        XCTAssertEqual(Set(interaction.labelFrames.keys), Set(items.map(\.id)))
    }

    private func settleHostedLayout(_ fixture: Fixture) async throws {
        for _ in 0 ..< 50 {
            try await Task.sleep(for: .milliseconds(10))
            fixture.island.hostingView.layoutSubtreeIfNeeded()
        }
    }

    private func screenFrame(_ target: WorkspaceBarHitTarget, in fixture: Fixture) throws -> CGRect {
        let local = try XCTUnwrap(fixture.island.interaction.frames[target])
        return try XCTUnwrap(fixture.island.hostingView.workspaceBarScreenRect(forLocalRect: local))
    }

    private func dropGeometry(in fixture: Fixture) -> WorkspaceBarDropGeometry {
        WorkspaceBarDropGeometry(workspaces: [firstId, secondId].compactMap { id in
            guard let frame = try? screenFrame(.workspace(id), in: fixture) else { return nil }
            return .init(
                id: id,
                name: id == firstId ? "1" : "2",
                layout: .niri,
                hitFrame: frame,
                icons: [],
                columnCount: 1
            )
        })
    }

    private func makeFixture(animationsEnabled: Bool) -> Fixture {
        let model = WorkspaceBarModel(snapshot: snapshot(items: items(), focused: firstId))
        let policy = MotionPolicy(animationsEnabled: animationsEnabled)
        let interaction = WorkspaceBarIslandInteraction()
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        let monitor = Monitor(
            id: Monitor.ID(displayId: 1),
            displayId: 1,
            frame: CGRect(x: 0, y: 0, width: 1500, height: 950),
            visibleFrame: CGRect(x: 0, y: 0, width: 1500, height: 920),
            hasNotch: false,
            name: "Fixture"
        )
        let island = WorkspaceBarIslandPanel(
            panel: panel,
            rootView: WorkspaceBarView(
                model: model,
                motionPolicy: policy,
                onFocusWorkspace: { _ in },
                onFocusWindow: { _ in },
                onActivateScratchpad: { _ in },
                interaction: interaction
            ),
            interaction: interaction,
            resolved: WorkspaceBarSettings().resolved(for: monitor)
        )
        island.applyFrame(CGRect(x: 100, y: 700, width: 680, height: 30), using: applyFrame)
        island.hostingView.layoutSubtreeIfNeeded()
        return Fixture(model: model, island: island)
    }

    private func items(extraFloatingWindow: Bool = false) -> [WorkspaceBarItem] {
        [
            WorkspaceBarItem(
                id: firstId,
                name: "Work and messages",
                rawName: "1",
                isFocused: true,
                tiledWindows: [window(1)],
                floatingWindows: extraFloatingWindow ? [window(2), window(3)] : [window(2)]
            ),
            WorkspaceBarItem(
                id: secondId,
                name: "Code",
                rawName: "2",
                isFocused: false,
                tiledWindows: [window(11)],
                floatingWindows: [window(12)]
            )
        ]
    }

    private func window(_ index: Int) -> WorkspaceBarWindowItem {
        let token = WindowToken(pid: 71, windowId: index)
        return WorkspaceBarWindowItem(
            id: token,
            handle: WindowHandle(id: token),
            windowId: index,
            appName: "App \(index)",
            bundleId: nil,
            icon: nil,
            isFocused: false,
            windowCount: 1,
            hiddenWindowCount: 0,
            allWindows: []
        )
    }

    private func snapshot(items: [WorkspaceBarItem], focused: WorkspaceDescriptor.ID) -> WorkspaceBarSnapshot {
        let focusedItems = items.map { item in
            WorkspaceBarItem(
                id: item.id,
                name: item.name,
                rawName: item.rawName,
                isFocused: item.id == focused,
                tiledWindows: item.tiledWindows,
                floatingWindows: item.floatingWindows
            )
        }
        return WorkspaceBarSnapshot(
            projection: .init(items: focusedItems, scratchpads: []),
            showLabels: true,
            showSystemStatsButton: false,
            backgroundOpacity: 0.1,
            barHeight: 30,
            accentColor: nil,
            textColor: nil
        )
    }

    private func applyFrame(_ panel: WorkspaceBarPanel, _ frame: CGRect) {
        panel.setFrame(frame, display: false)
    }

    private func midpoint(_ frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
