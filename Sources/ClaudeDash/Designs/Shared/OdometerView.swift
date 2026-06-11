import SwiftUI

/// Mechanical-odometer style readout: one dark cell per digit with rolling
/// digit transitions.
struct OdometerView: View {
    var value: Int
    var minimumDigits: Int = 7
    var font: Font
    var digitColor: Color = Color(white: 0.92)
    var cellColor: Color = Color(white: 0.04)

    private var digits: [String] {
        let text = String(max(0, value))
        let padded = String(repeating: "0", count: max(0, minimumDigits - text.count)) + text
        return padded.map(String.init)
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                Text(digit)
                    .font(font)
                    .foregroundColor(digitColor)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .padding(.horizontal, 1.5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(cellColor)
                            .overlay(
                                // Subtle drum shading top and bottom.
                                LinearGradient(
                                    colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            )
                    )
            }
        }
        .animation(.easeOut(duration: 0.5), value: value)
    }
}
