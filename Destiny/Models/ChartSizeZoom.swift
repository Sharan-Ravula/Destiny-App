import SwiftUI

/// Same idea as FontZoom -- a small integer "zoom step" (adjusted via the
/// +/- controls next to each chart's style picker) mapped onto a size
/// multiplier. Applied to a chart's *ideal* and *minimum* target size
/// before ChartDetailView's/DivisionalChartsView's own responsive
/// width-fitting math runs, so a user's size preference still always fits
/// the available width (sidebar open/closed, window resize) rather than
/// ever overflowing it -- the multiplier changes what the layout aims for,
/// not a post-hoc scale applied on top of an already-fitted size.
enum ChartSizeZoom {
    private static let stepIncrement: CGFloat = 0.1
    static let minStep = -4
    static let maxStep = 6

    static func multiplier(forStep step: Int) -> CGFloat {
        let clampedStep = min(max(step, minStep), maxStep)
        return 1.0 + CGFloat(clampedStep) * stepIncrement
    }
}
