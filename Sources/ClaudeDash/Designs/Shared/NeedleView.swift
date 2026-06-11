import SwiftUI

/// Tapered gauge needle with counterweight tail and hub, drawn pointing at
/// 12 o'clock and rotated. Angle is degrees clockwise from 12 o'clock.
struct NeedleView: View {
    var angle: Double
    var color: Color = .yellow
    /// Needle tip reach as a fraction of the view's radius.
    var length: CGFloat = 0.86
    var hubColor: Color = Color(white: 0.08)
    var hubScale: CGFloat = 0.16

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = side / 2
            ZStack {
                NeedleShape(length: length)
                    .fill(color)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 1)
                    .rotationEffect(.degrees(angle))
                Circle()
                    .fill(hubColor)
                    .overlay(
                        Circle().strokeBorder(Color(white: 0.25), lineWidth: 1)
                    )
                    .frame(width: radius * hubScale * 2, height: radius * hubScale * 2)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct NeedleShape: Shape {
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let tip = radius * length
        let tail = radius * 0.18
        let baseHalfWidth = radius * 0.030
        let tipHalfWidth = radius * 0.008

        var path = Path()
        path.move(to: CGPoint(x: center.x - tipHalfWidth, y: center.y - tip))
        path.addLine(to: CGPoint(x: center.x + tipHalfWidth, y: center.y - tip))
        path.addLine(to: CGPoint(x: center.x + baseHalfWidth, y: center.y + tail))
        path.addLine(to: CGPoint(x: center.x - baseHalfWidth, y: center.y + tail))
        path.closeSubpath()
        return path
    }
}
