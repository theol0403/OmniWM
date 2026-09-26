// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

final class WorkspaceBarFrameMotionTests: XCTestCase {
    func testSpringIsIndependentOfDisplayRefreshRateAndSettles() {
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        let target = CGRect(x: 400, y: 650, width: 350, height: 30)
        let spring = WorkspaceBarFrameSpring(from: initial, target: target, start: 0)
        XCTAssertEqual(spring.frame(at: 0), initial)
        for frame in 1 ... 24 {
            let at60Hz = spring.frame(at: Double(frame) / 60)
            let at120Hz = spring.frame(at: Double(frame * 2) / 120)
            XCTAssertEqual(at60Hz, at120Hz)
            XCTAssertGreaterThan(at60Hz.minX, initial.minX)
            XCTAssertLessThan(at60Hz.minX, target.minX)
        }
        XCTAssertTrue(spring.isSettled(at: 0.5))
    }

    func testRapidReversalPreservesThePresentedFrameAndVelocity() {
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        var spring = WorkspaceBarFrameSpring(from: initial, target: initial.offsetBy(dx: 200, dy: 0), start: 0)
        for index in 1 ... 4 {
            let time = Double(index) * 0.06
            let presented = spring.frame(at: time)
            let velocity = spring.velocity(at: time)
            let next = initial.offsetBy(dx: index.isMultiple(of: 2) ? 200 : -100, dy: 0)
            spring = WorkspaceBarFrameSpring(from: presented, target: next, velocity: velocity, start: time)
            XCTAssertEqual(spring.frame(at: time).minX, presented.minX, accuracy: 0.0001)
            XCTAssertEqual(spring.velocity(at: time).x, velocity.x, accuracy: 0.0001)
        }
        XCTAssertTrue(spring.isSettled(at: 1))
    }

    func testRetargetingToCurrentFrameDoesNotDiscardVelocity() {
        let frame = CGRect(x: 100, y: 700, width: 200, height: 24)
        let spring = WorkspaceBarFrameSpring(from: frame, target: frame, velocity: SIMD4(300, 0, 0, 0), start: 0)
        XCTAssertFalse(spring.isSettled(at: 0))
        XCTAssertEqual(spring.velocity(at: 0).x, 300)
        XCTAssertGreaterThan(spring.frame(at: 0.02).minX, frame.minX)
        XCTAssertTrue(spring.isSettled(at: 0.5))
    }

    @MainActor
    func testHiddenInitialPlacementSkipsDuplicatesAndReleasesIdleClosure() {
        final class Capture {}
        let panel = WorkspaceBarPanel.defaultPanel()
        defer { panel.close() }
        let motion = WorkspaceBarFrameMotion(panel: panel, motionPolicy: MotionPolicy())
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        var frames: [CGRect] = []
        var capture: Capture? = Capture()
        weak let retained = capture
        motion.apply(initial) { [capture] _, frame in
            XCTAssertNotNil(capture)
            frames.append(frame)
        }
        capture = nil
        XCTAssertNil(retained)
        motion.apply(initial) { _, frame in frames.append(frame) }
        motion.apply(initial.offsetBy(dx: 40, dy: 0)) { _, frame in frames.append(frame) }
        XCTAssertEqual(frames, [initial, initial.offsetBy(dx: 40, dy: 0)])
        XCTAssertFalse(motion.isAnimating)
    }

    @MainActor
    func testImmediateSetterCanRetargetWithoutLosingTheNewRequest() {
        let panel = WorkspaceBarPanel.defaultPanel()
        defer { panel.close() }
        let motion = WorkspaceBarFrameMotion(panel: panel, motionPolicy: MotionPolicy(animationsEnabled: false))
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        let latest = initial.offsetBy(dx: 100, dy: 0)
        motion.apply(initial) { _, _ in
            motion.apply(latest) { panel, frame in panel.setFrame(frame, display: false) }
        }
        XCTAssertEqual(motion.target, latest)
        XCTAssertEqual(panel.frame, latest)
        XCTAssertFalse(motion.isAnimating)
    }

    @MainActor
    func testFinishingCanStartAnotherAnimationFromTheSetter() throws {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            throw XCTSkip("Native frame animations are disabled by macOS Reduce Motion")
        }
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        defer { panel.close() }
        let policy = MotionPolicy()
        let motion = WorkspaceBarFrameMotion(panel: panel, motionPolicy: policy)
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        let first = initial.offsetBy(dx: 100, dy: 0)
        let latest = initial.offsetBy(dx: 200, dy: 0)
        let apply: (WorkspaceBarPanel, CGRect) -> Void = { $0.setFrame($1, display: false) }
        motion.apply(initial, using: apply)
        panel.orderFrontRegardless()
        motion.apply(first) { panel, frame in
            apply(panel, frame)
            if frame == first {
                policy.animationsEnabled = true
                motion.apply(latest, using: apply)
            }
        }
        policy.animationsEnabled = false
        motion.apply(first, using: apply)
        XCTAssertEqual(motion.target, latest)
        XCTAssertTrue(motion.isAnimating)
    }

    @MainActor
    func testCloseAndOwnerRemovalInvalidateActiveLinks() throws {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            throw XCTSkip("Native frame animations are disabled by macOS Reduce Motion")
        }
        let panel = WorkspaceBarPanel.defaultPanel()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        defer { panel.close() }
        let initial = CGRect(x: 100, y: 700, width: 200, height: 24)
        var motion: WorkspaceBarFrameMotion? = WorkspaceBarFrameMotion(panel: panel, motionPolicy: MotionPolicy())
        let apply: (WorkspaceBarPanel, CGRect) -> Void = { $0.setFrame($1, display: false) }
        motion?.apply(initial, using: apply)
        panel.orderFrontRegardless()
        motion?.apply(initial.offsetBy(dx: 100, dy: 0), using: apply)
        XCTAssertTrue(motion?.isAnimating == true)
        panel.close()
        XCTAssertTrue(motion?.isAnimating == false)
        panel.orderFrontRegardless()
        motion?.apply(initial.offsetBy(dx: 200, dy: 0), using: apply)
        XCTAssertTrue(motion?.isAnimating == true)
        weak let retained = motion
        motion = nil
        XCTAssertNil(retained)
    }
}
