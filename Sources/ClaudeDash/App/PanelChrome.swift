import SwiftUI

/// Design-agnostic overlay wrapped around every dashboard design: a close
/// (hide) button that fades in at the top-right while the pointer is over the
/// panel, keeping the cluster chrome-free the rest of the time.
struct PanelChrome<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: Content

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            if hovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.8))
                        .padding(6)
                        .background(Circle().fill(Color(white: 0.16).opacity(0.92)))
                        .overlay(Circle().strokeBorder(Color(white: 0.35).opacity(0.4), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Hide dashboard (reopen from the menu bar gauge icon)")
                .padding(12)
                .transition(.opacity)
            }
        }
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hovering = isHovering
            }
        }
    }
}
