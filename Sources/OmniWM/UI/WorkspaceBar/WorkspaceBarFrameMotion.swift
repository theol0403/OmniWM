// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
import Observation
import QuartzCore

@MainActor
final class WorkspaceBarFrameMotion {
    private weak var panel: WorkspaceBarPanel?
    private let motionPolicy: MotionPolicy
    private let callback = WorkspaceBarFrameCallback()
    private var displayLink: CADisplayLink?
    private var visibilityObservation: NSKeyValueObservation?
    private var spring: WorkspaceBarFrameSpring?
    private var frameApplier: ((WorkspaceBarPanel, CGRect) -> Void)?
    private var observationGeneration = 0
    private(set) var target: CGRect?

    var isAnimating: Bool {
        displayLink != nil
    }

    init(panel: WorkspaceBarPanel, motionPolicy: MotionPolicy) {
        self.panel = panel
        self.motionPolicy = motionPolicy
        callback.owner = self
        visibilityObservation = panel.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.visibilityChanged() }
        }
        NotificationCenter.default.addObserver(
            callback, selector: #selector(WorkspaceBarFrameCallback.visibilityChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: panel
        )
        NotificationCenter.default.addObserver(
            callback, selector: #selector(WorkspaceBarFrameCallback.windowClosed),
            name: NSWindow.willCloseNotification, object: panel
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            callback, selector: #selector(WorkspaceBarFrameCallback.accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
    }

    isolated deinit {
        displayLink?.invalidate()
        visibilityObservation?.invalidate()
        NotificationCenter.default.removeObserver(callback)
        NSWorkspace.shared.notificationCenter.removeObserver(callback)
    }

    func apply(
        _ frame: CGRect,
        using frameApplier: @escaping (WorkspaceBarPanel, CGRect) -> Void,
        at time: CFTimeInterval = CACurrentMediaTime()
    ) {
        guard let panel else {
            stop()
            return
        }
        if frame == target {
            if isAnimating, !panel.isVisible || !animationsEnabled { finish() }
            return
        }
        self.frameApplier = frameApplier
        guard target != nil, panel.isVisible, animationsEnabled else {
            target = frame
            finish()
            return
        }
        let velocity = spring?.velocity(at: time) ?? .zero
        target = frame
        spring = WorkspaceBarFrameSpring(from: panel.frame, target: frame, velocity: velocity, start: time)
        guard spring?.isSettled(at: time) == false else {
            finish()
            return
        }
        if displayLink == nil {
            let link = panel.displayLink(target: callback, selector: #selector(WorkspaceBarFrameCallback.tick(_:)))
            displayLink = link
            link.add(to: .main, forMode: .common)
            observeMotionPolicy()
        }
    }

    fileprivate func tick(at time: CFTimeInterval) {
        guard let panel, let spring else {
            stop()
            return
        }
        guard panel.isVisible, animationsEnabled, !spring.isSettled(at: time) else {
            finish()
            return
        }
        frameApplier?(panel, spring.frame(at: time))
    }

    fileprivate func visibilityChanged() {
        if panel?.isVisible != true { finish() }
    }

    fileprivate func accessibilityChanged() {
        if !animationsEnabled { finish() }
    }

    fileprivate func stop() {
        displayLink?.invalidate()
        displayLink = nil
        spring = nil
        frameApplier = nil
        observationGeneration &+= 1
    }

    private var animationsEnabled: Bool {
        motionPolicy.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func finish() {
        let apply = frameApplier
        let panel = panel
        let frame = target
        stop()
        if let panel, let frame { apply?(panel, frame) }
    }

    private func observeMotionPolicy() {
        let generation = observationGeneration
        withObservationTracking {
            _ = motionPolicy.animationsEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.observationGeneration == generation, self.isAnimating else { return }
                if self.animationsEnabled { self.observeMotionPolicy() } else { self.finish() }
            }
        }
    }
}

@MainActor
private final class WorkspaceBarFrameCallback: NSObject {
    weak var owner: WorkspaceBarFrameMotion?

    @objc func tick(_: CADisplayLink) {
        owner?.tick(at: CACurrentMediaTime())
    }

    @objc func visibilityChanged() {
        owner?.visibilityChanged()
    }

    @objc func windowClosed() {
        owner?.stop()
    }

    @objc func accessibilityChanged() {
        owner?.accessibilityChanged()
    }
}
