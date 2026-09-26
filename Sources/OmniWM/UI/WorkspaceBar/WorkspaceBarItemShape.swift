// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import SwiftUI

struct WorkspaceBarItemShape: InsettableShape {
    var rect: CGRect
    var cornerRadius: CGFloat
    private var insetAmount: CGFloat = 0

    init(rect: CGRect, cornerRadius: CGFloat = 6) {
        self.rect = rect
        self.cornerRadius = cornerRadius
    }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(rect.minX, rect.minY),
                AnimatablePair(rect.width, rect.height)
            )
        }
        set {
            rect = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in _: CGRect) -> Path {
        let drawingRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard drawingRect.width > 0, drawingRect.height > 0 else { return Path() }
        return RoundedRectangle(cornerRadius: max(0, cornerRadius - insetAmount), style: .continuous)
            .path(in: drawingRect)
    }

    func inset(by amount: CGFloat) -> Self {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
