import SwiftUI

/// Maps a small integer "zoom step" (as adjusted by Cmd+/Cmd- or the
/// toolbar's Text Size picker) onto a font-size multiplier, injected as an
/// environment value (see EnvironmentValues.fontZoomMultiplier below).
///
/// Tried two other mechanisms first, both broken in their own way:
/// - DynamicTypeSize environment: didn't visibly affect Table cell text on
///   macOS the way plain Text elsewhere did.
/// - .scaleEffect at the app root: visually scaled everything including
///   Table text, but broke click/selection for every AppKit-backed control
///   (NavigationSplitView, Table row selection, Picker menus, buttons) --
///   SwiftUI's scaleEffect is a rendering-layer transform and doesn't
///   correctly remap hit-testing coordinates for embedded NSView-backed
///   controls, which is most of this app's UI.
///
/// This approach instead multiplies literal point sizes on the specific
/// Table-heavy views where the size actually matters most (see
/// VimshottariDashaView, CharaDashaView, ChartTableView, etc.) -- a plain
/// font-size change has no geometry/hit-testing implications at all.
enum FontZoom {
    private static let stepIncrement: CGFloat = 0.12
    static let minStep = -5
    static let maxStep = 10

    static func multiplier(forStep step: Int) -> CGFloat {
        let clampedStep = min(max(step, minStep), maxStep)
        return 1.0 + CGFloat(clampedStep) * stepIncrement
    }
}

private struct FontZoomMultiplierKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var fontZoomMultiplier: CGFloat {
        get { self[FontZoomMultiplierKey.self] }
        set { self[FontZoomMultiplierKey.self] = newValue }
    }
}
