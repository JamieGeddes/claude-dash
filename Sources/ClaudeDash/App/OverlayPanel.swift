import AppKit
import SwiftUI

/// Borderless always-on-top panel hosting the dashboard. Non-activating so
/// clicking/dragging the cluster never steals focus from the active app.
final class OverlayPanel: NSPanel {
    init(size: CGSize, origin: CGPoint?) {
        let frame: NSRect
        if let origin {
            frame = NSRect(origin: origin, size: size)
        } else if let screen = NSScreen.main {
            // Default: top-center, just under the menu bar.
            let visible = screen.visibleFrame
            frame = NSRect(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - 24,
                width: size.width,
                height: size.height
            )
        } else {
            frame = NSRect(origin: .zero, size: size)
        }

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the cluster view draws its own shadow
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
