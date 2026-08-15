import SwiftUI
import AppKit

/// Which system-control appearance a ColorTheme forces (see
/// ColorTheme.forcedAppearance) -- "System" no longer exists as a
/// selectable case here since removing the separate Appearance picker;
/// a theme with no forced appearance just leaves NSApp.appearance nil
/// (follow macOS) instead of picking this enum's "system" value.
enum AppearanceMode: String, Equatable {
    case light = "Light"
    case dark = "Dark"

    /// Driving the window's appearance via AppKit directly (rather than
    /// only SwiftUI's .preferredColorScheme) -- toggling
    /// .preferredColorScheme between an explicit value and nil left the
    /// window's title bar and content view out of sync until the app lost
    /// and regained focus. Setting NSApp.appearance applies immediately
    /// and consistently across the whole window.
    var nsAppearance: NSAppearance {
        switch self {
        case .light: return NSAppearance(named: .aqua)!
        case .dark: return NSAppearance(named: .darkAqua)!
        }
    }
}
