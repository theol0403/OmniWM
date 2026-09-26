// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Foundation

struct WorkspaceBarFrameSpring {
    let target: CGRect
    let start: CFTimeInterval
    private let origin: SIMD4<Double>
    private let destination: SIMD4<Double>
    private let initialVelocity: SIMD4<Double>
    private static let frequency = 32.0

    init(from: CGRect, target: CGRect, velocity: SIMD4<Double> = .zero, start: CFTimeInterval) {
        self.target = target
        self.start = start
        origin = Self.components(from)
        destination = Self.components(target)
        initialVelocity = velocity
    }

    func frame(at time: CFTimeInterval) -> CGRect {
        let elapsed = max(0, time - start)
        let displacement = origin - destination
        let value = destination + exp(-Self.frequency * elapsed)
            * (displacement + (initialVelocity + Self.frequency * displacement) * elapsed)
        return CGRect(x: value.x, y: value.y, width: max(0, value.z), height: max(0, value.w))
    }

    func velocity(at time: CFTimeInterval) -> SIMD4<Double> {
        let elapsed = max(0, time - start)
        return exp(-Self.frequency * elapsed)
            * (initialVelocity - Self.frequency * (initialVelocity + Self.frequency * (origin - destination)) * elapsed)
    }

    func isSettled(at time: CFTimeInterval) -> Bool {
        let distance = Self.components(frame(at: time)) - destination
        let speed = velocity(at: time)
        return (0 ..< 4).allSatisfy { abs(distance[$0]) < 0.1 && abs(speed[$0]) < 2 }
    }

    private static func components(_ frame: CGRect) -> SIMD4<Double> {
        SIMD4(frame.origin.x, frame.origin.y, frame.width, frame.height)
    }
}
