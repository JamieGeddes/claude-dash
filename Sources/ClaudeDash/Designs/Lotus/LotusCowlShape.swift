import SwiftUI

/// The Exige binnacle silhouette: two hump circles over the dials unioned
/// with a rounded apron below. Nonzero fill merges the subpaths, and the
/// circle intersection geometry produces the characteristic V-notch between
/// the domes. All coordinates are absolute within the cluster frame.
struct LotusCowlShape: Shape {
    var leftCenter: CGPoint
    var rightCenter: CGPoint
    var humpRadius: CGFloat
    var apron: CGRect
    var apronCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: leftCenter.x - humpRadius, y: leftCenter.y - humpRadius,
            width: humpRadius * 2, height: humpRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: rightCenter.x - humpRadius, y: rightCenter.y - humpRadius,
            width: humpRadius * 2, height: humpRadius * 2
        ))
        path.addRoundedRect(
            in: apron,
            cornerSize: CGSize(width: apronCornerRadius, height: apronCornerRadius)
        )
        return path
    }
}

/// Outer cowl plus the recessed inner panel the dials sit in.
struct LotusHousingView: View {
    var leftCenter: CGPoint
    var rightCenter: CGPoint
    var humpRadius: CGFloat
    var apron: CGRect

    var body: some View {
        ZStack {
            LotusCowlShape(
                leftCenter: leftCenter,
                rightCenter: rightCenter,
                humpRadius: humpRadius,
                apron: apron,
                apronCornerRadius: 26
            )
            .fill(
                LinearGradient(
                    colors: [LotusTheme.cowlTop, LotusTheme.cowl],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                LotusCowlShape(
                    leftCenter: leftCenter,
                    rightCenter: rightCenter,
                    humpRadius: humpRadius,
                    apron: apron,
                    apronCornerRadius: 26
                )
                .stroke(Color(white: 0.30).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 14, y: 6)

            LotusCowlShape(
                leftCenter: leftCenter,
                rightCenter: rightCenter,
                humpRadius: humpRadius - 10,
                apron: apron.insetBy(dx: 8, dy: 6),
                apronCornerRadius: 20
            )
            .fill(LotusTheme.innerPanel)
        }
    }
}
