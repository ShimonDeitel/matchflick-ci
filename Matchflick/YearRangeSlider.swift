import SwiftUI

/// A two-thumb range slider for picking a decade/year span, e.g. 1930-2026.
struct YearRangeSlider: View {
    @Binding var lowerValue: Int
    @Binding var upperValue: Int
    let bounds: ClosedRange<Int>

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumbSize
            let span = CGFloat(bounds.upperBound - bounds.lowerBound)
            let lowerX = width * CGFloat(lowerValue - bounds.lowerBound) / span
            let upperX = width * CGFloat(upperValue - bounds.lowerBound) / span

            ZStack(alignment: .leading) {
                Capsule().fill(Color.matchflickField).frame(height: trackHeight)
                Capsule().fill(Color.matchflickAccent)
                    .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                    .offset(x: lowerX)

                thumb.offset(x: lowerX)
                    .gesture(DragGesture().onChanged { value in
                        let raw = Int(round((value.location.x / width) * span)) + bounds.lowerBound
                        lowerValue = min(max(raw, bounds.lowerBound), upperValue - 1)
                    })

                thumb.offset(x: upperX)
                    .gesture(DragGesture().onChanged { value in
                        let raw = Int(round((value.location.x / width) * span)) + bounds.lowerBound
                        upperValue = max(min(raw, bounds.upperBound), lowerValue + 1)
                    })
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
    }

    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .overlay(Circle().stroke(Color.matchflickAccent, lineWidth: 2))
    }
}
