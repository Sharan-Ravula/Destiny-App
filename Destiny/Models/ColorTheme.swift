import SwiftUI

private extension Color {
    /// 6-digit hex, e.g. Color(hex: 0x2E3440) -- used below so the named
    /// developer-theme palettes can be written as their actual published
    /// hex values instead of hand-guessed RGB fractions.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Experimental: a handful of complete color palettes (not just an accent
/// color) the user can pick between. Every theme except "System" has its
/// own forcedAppearance (light or dark) to keep native text/controls
/// legible against its own background; "System" (forcedAppearance nil)
/// just leaves NSApp.appearance alone and follows whatever macOS itself
/// is set to.
///
/// keyword/string/number are "text" theming -- real editor themes
/// distinguish different kinds of text (not just one accent color), e.g.
/// Dark+'s blue keywords vs. orange strings vs. green numbers. Every theme
/// here passes all three explicitly: named IDE/editor themes use that
/// project's own published syntax colors; this app's 7 own invented
/// palettes (System/Light/Dark/Ocean/Sunset/Forest/Violet) use hand-picked
/// colors fitting each palette's concept instead, since there's no
/// "official" syntax spec to source those from. Applied across every
/// table and both chart diagrams (planet/lord names = keyword, rasi/
/// nakshatra names = string, numeric/date values = number).
///
/// Table/List rows disable their native alternating-row striping wherever
/// a theme's background is applied (see ChartTableView, VimshottariDashaView,
/// etc. for the .alternatingRowBackgrounds(.disabled) + .scrollContentBackground(.hidden)
/// pairing) -- without that, AppKit draws its own light/dark stripe
/// underneath every other row regardless of the chosen palette.
struct ColorTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let background: Color
    let secondaryBackground: Color
    let keyword: Color
    let string: Color
    let number: Color
    let forcedAppearance: AppearanceMode?

    init(id: String, name: String, accent: Color, background: Color, secondaryBackground: Color,
         keyword: Color? = nil, string: Color? = nil, number: Color? = nil,
         forcedAppearance: AppearanceMode?) {
        self.id = id
        self.name = name
        self.accent = accent
        self.background = background
        self.secondaryBackground = secondaryBackground
        self.keyword = keyword ?? accent
        self.string = string ?? accent
        self.number = number ?? accent
        self.forcedAppearance = forcedAppearance
    }

    // These 7 are this app's own invented palettes (not ports of a named
    // IDE theme), so their keyword/string/number are hand-picked to fit
    // each palette's own concept rather than "researched" -- System uses
    // SwiftUI's semantic colors specifically because they auto-adjust for
    // light/dark (System has no forcedAppearance, so a fixed hex could end
    // up low-contrast against whichever the OS happens to be in).
    static let system = ColorTheme(
        id: "system", name: "System", accent: .accentColor,
        background: Color(nsColor: .windowBackgroundColor),
        secondaryBackground: Color(nsColor: .controlBackgroundColor),
        keyword: .purple, string: .orange, number: .green,
        forcedAppearance: nil
    )
    static let light = ColorTheme(
        id: "light", name: "Light", accent: .blue,
        background: Color(white: 0.98),
        secondaryBackground: Color(white: 0.93),
        keyword: Color(hex: 0x0B6FCC), string: Color(hex: 0x116329), number: Color(hex: 0x953800),
        forcedAppearance: .light
    )
    static let dark = ColorTheme(
        id: "dark", name: "Dark", accent: .blue,
        background: Color(white: 0.08),
        secondaryBackground: Color(white: 0.14),
        keyword: Color(hex: 0x569CD6), string: Color(hex: 0xCE9178), number: Color(hex: 0xB5CEA8),
        forcedAppearance: .dark
    )
    static let ocean = ColorTheme(
        id: "ocean", name: "Ocean", accent: Color(red: 0.40, green: 0.80, blue: 0.88),
        background: Color(red: 0.04, green: 0.10, blue: 0.16),
        secondaryBackground: Color(red: 0.07, green: 0.16, blue: 0.24),
        keyword: Color(hex: 0x5FB3B3), string: Color(hex: 0x99C794), number: Color(hex: 0xFAC863),
        forcedAppearance: .dark
    )
    static let sunset = ColorTheme(
        id: "sunset", name: "Sunset", accent: Color(red: 0.95, green: 0.58, blue: 0.32),
        background: Color(red: 0.16, green: 0.07, blue: 0.09),
        secondaryBackground: Color(red: 0.24, green: 0.11, blue: 0.12),
        keyword: Color(hex: 0xFF6B6B), string: Color(hex: 0xFFD93D), number: Color(hex: 0xC77DFF),
        forcedAppearance: .dark
    )
    static let forest = ColorTheme(
        id: "forest", name: "Forest", accent: Color(red: 0.48, green: 0.80, blue: 0.53),
        background: Color(red: 0.05, green: 0.11, blue: 0.08),
        secondaryBackground: Color(red: 0.08, green: 0.17, blue: 0.12),
        keyword: Color(hex: 0x8FBC8F), string: Color(hex: 0xDEB887), number: Color(hex: 0xF0E68C),
        forcedAppearance: .dark
    )
    static let violet = ColorTheme(
        id: "violet", name: "Violet", accent: Color(red: 0.75, green: 0.58, blue: 0.96),
        background: Color(red: 0.10, green: 0.06, blue: 0.16),
        secondaryBackground: Color(red: 0.16, green: 0.10, blue: 0.24),
        keyword: Color(hex: 0xE0AAFF), string: Color(hex: 0xFF9EDB), number: Color(hex: 0xC77DFF),
        forcedAppearance: .dark
    )

    // Well-known developer color palettes, using their actual published
    // hex values (not approximated) -- Nord, Dracula, Solarized, Gruvbox,
    // and Monokai are all widely recognized, deliberately-designed schemes.
    // keyword/string/number use each theme's own published syntax colors.
    static let nord = ColorTheme(
        id: "nord", name: "Nord", accent: Color(hex: 0x88C0D0),
        background: Color(hex: 0x2E3440),
        secondaryBackground: Color(hex: 0x3B4252),
        keyword: Color(hex: 0x81A1C1), string: Color(hex: 0xA3BE8C), number: Color(hex: 0xB48EAD),
        forcedAppearance: .dark
    )
    static let dracula = ColorTheme(
        id: "dracula", name: "Dracula", accent: Color(hex: 0xBD93F9),
        background: Color(hex: 0x282A36),
        secondaryBackground: Color(hex: 0x44475A),
        keyword: Color(hex: 0xFF79C6), string: Color(hex: 0xF1FA8C), number: Color(hex: 0x50FA7B),
        forcedAppearance: .dark
    )
    static let solarizedDark = ColorTheme(
        id: "solarizedDark", name: "Solarized Dark", accent: Color(hex: 0x268BD2),
        background: Color(hex: 0x002B36),
        secondaryBackground: Color(hex: 0x073642),
        keyword: Color(hex: 0x6C71C4), string: Color(hex: 0x2AA198), number: Color(hex: 0xD33682),
        forcedAppearance: .dark
    )
    static let gruvbox = ColorTheme(
        id: "gruvbox", name: "Gruvbox", accent: Color(hex: 0xFE8019),
        background: Color(hex: 0x282828),
        secondaryBackground: Color(hex: 0x3C3836),
        keyword: Color(hex: 0xFB4934), string: Color(hex: 0xB8BB26), number: Color(hex: 0xD3869B),
        forcedAppearance: .dark
    )
    static let monokai = ColorTheme(
        id: "monokai", name: "Monokai", accent: Color(hex: 0xF92672),
        background: Color(hex: 0x272822),
        secondaryBackground: Color(hex: 0x3E3D32),
        keyword: Color(hex: 0xF92672), string: Color(hex: 0xE6DB74), number: Color(hex: 0xAE81FF),
        forcedAppearance: .dark
    )

    // More well-known palettes, researched (published hex values, not
    // approximated): Catppuccin Mocha, Tokyo Night, Rose Pine, Everforest,
    // and One Dark -- all widely used, deliberately-designed dark themes
    // from the editor/terminal-theming world.
    static let catppuccinMocha = ColorTheme(
        id: "catppuccinMocha", name: "Catppuccin Mocha", accent: Color(hex: 0x89B4FA),
        background: Color(hex: 0x1E1E2E),
        secondaryBackground: Color(hex: 0x181825),
        keyword: Color(hex: 0xCBA6F7), string: Color(hex: 0xA6E3A1), number: Color(hex: 0xFAB387),
        forcedAppearance: .dark
    )
    static let tokyoNight = ColorTheme(
        id: "tokyoNight", name: "Tokyo Night", accent: Color(hex: 0x7AA2F7),
        background: Color(hex: 0x1A1B26),
        secondaryBackground: Color(hex: 0x1F2335),
        keyword: Color(hex: 0xBB9AF7), string: Color(hex: 0x9ECE6A), number: Color(hex: 0xFF9E64),
        forcedAppearance: .dark
    )
    static let rosePine = ColorTheme(
        id: "rosePine", name: "Ros\u{00E9} Pine", accent: Color(hex: 0xEB6F92),
        background: Color(hex: 0x191724),
        secondaryBackground: Color(hex: 0x1F1D2E),
        keyword: Color(hex: 0xC4A7E7), string: Color(hex: 0x9CCFD8), number: Color(hex: 0xF6C177),
        forcedAppearance: .dark
    )
    static let everforest = ColorTheme(
        id: "everforest", name: "Everforest", accent: Color(hex: 0xA7C080),
        background: Color(hex: 0x2F383E),
        secondaryBackground: Color(hex: 0x374247),
        keyword: Color(hex: 0xE67E80), string: Color(hex: 0x7FBBB3), number: Color(hex: 0xD699B6),
        forcedAppearance: .dark
    )
    static let oneDark = ColorTheme(
        id: "oneDark", name: "One Dark", accent: Color(hex: 0x528BFF),
        background: Color(hex: 0x282C34),
        secondaryBackground: Color(hex: 0x2C313A),
        keyword: Color(hex: 0xC678DD), string: Color(hex: 0x98C379), number: Color(hex: 0xD19A66),
        forcedAppearance: .dark
    )

    // Another round, same research approach: Kanagawa, Ayu Dark, Material
    // Palenight, and SynthWave '84 -- each a well-known, deliberately
    // distinct palette (muted Japanese-painting tones, warm amber-on-near-
    // black, cool purple-gray, and neon retro-synth respectively).
    static let kanagawa = ColorTheme(
        id: "kanagawa", name: "Kanagawa", accent: Color(hex: 0x7E9CD8),
        background: Color(hex: 0x1F1F28),
        secondaryBackground: Color(hex: 0x2A2A37),
        keyword: Color(hex: 0x957FB8), string: Color(hex: 0x98BB6C), number: Color(hex: 0xD27E99),
        forcedAppearance: .dark
    )
    static let ayu = ColorTheme(
        id: "ayu", name: "Ayu Dark", accent: Color(hex: 0xE6B450),
        background: Color(hex: 0x0D1017),
        secondaryBackground: Color(hex: 0x131721),
        keyword: Color(hex: 0xFF8F40), string: Color(hex: 0xAAD94C), number: Color(hex: 0x59C2FF),
        forcedAppearance: .dark
    )
    static let palenight = ColorTheme(
        id: "palenight", name: "Palenight", accent: Color(hex: 0x7C4DFF),
        background: Color(hex: 0x292D3E),
        secondaryBackground: Color(hex: 0x343953),
        keyword: Color(hex: 0x89DDFF), string: Color(hex: 0xC3E88D), number: Color(hex: 0xF78C6C),
        forcedAppearance: .dark
    )
    static let synthwave = ColorTheme(
        id: "synthwave", name: "SynthWave '84", accent: Color(hex: 0xF92AAD),
        background: Color(hex: 0x241B2F),
        secondaryBackground: Color(hex: 0x2D2139),
        keyword: Color(hex: 0xFEDE5D), string: Color(hex: 0xFF8B39), number: Color(hex: 0xF97E72),
        forcedAppearance: .dark
    )

    // A 3rd research round, all well-known VS Code/editor extensions:
    // Night Owl (Sarah Drasner), GitHub Dark (GitHub's own), Cobalt2 (Wes
    // Bos), Shades of Purple (Ahmad Awais), and Oceanic Next.
    static let nightOwl = ColorTheme(
        id: "nightOwl", name: "Night Owl", accent: Color(hex: 0x82AAFF),
        background: Color(hex: 0x011627),
        secondaryBackground: Color(hex: 0x0B2942),
        keyword: Color(hex: 0xC792EA), string: Color(hex: 0xADDB67), number: Color(hex: 0xF78C6C),
        forcedAppearance: .dark
    )
    static let githubDark = ColorTheme(
        id: "githubDark", name: "GitHub Dark", accent: Color(hex: 0x2F81F7),
        background: Color(hex: 0x0D1117),
        secondaryBackground: Color(hex: 0x161B22),
        keyword: Color(hex: 0xFF7B72), string: Color(hex: 0xA5D6FF), number: Color(hex: 0x79C0FF),
        forcedAppearance: .dark
    )
    static let cobalt2 = ColorTheme(
        id: "cobalt2", name: "Cobalt2", accent: Color(hex: 0xFFC600),
        background: Color(hex: 0x193549),
        secondaryBackground: Color(hex: 0x15232D),
        keyword: Color(hex: 0xFF9D00), string: Color(hex: 0xA5FF90), number: Color(hex: 0xFF628C),
        forcedAppearance: .dark
    )
    static let shadesOfPurple = ColorTheme(
        id: "shadesOfPurple", name: "Shades of Purple", accent: Color(hex: 0xFAD000),
        background: Color(hex: 0x2D2B55),
        secondaryBackground: Color(hex: 0x28284E),
        keyword: Color(hex: 0xFF9D00), string: Color(hex: 0x9EFFFF), number: Color(hex: 0xFAD000),
        forcedAppearance: .dark
    )
    static let oceanicNext = ColorTheme(
        id: "oceanicNext", name: "Oceanic Next", accent: Color(hex: 0x6699CC),
        background: Color(hex: 0x1B2B34),
        secondaryBackground: Color(hex: 0x343D46),
        keyword: Color(hex: 0xC594C5), string: Color(hex: 0x99C794), number: Color(hex: 0xF99157),
        forcedAppearance: .dark
    )

    // Requested by name: VS Code's actual default Dark+ theme, JetBrains'
    // signature Darcula (a distinct palette from Dracula despite the
    // similar name), Monokai Pro (a distinct, muted evolution of classic
    // Monokai above), and Zenburn (the classic low-contrast Emacs/Vim
    // theme). All hex values from each project's own theme source files.
    static let vscodeDarkPlus = ColorTheme(
        id: "vscodeDarkPlus", name: "VS Code Dark+", accent: Color(hex: 0x569CD6),
        background: Color(hex: 0x1E1E1E),
        secondaryBackground: Color(hex: 0x252526),
        keyword: Color(hex: 0x569CD6), string: Color(hex: 0xCE9178), number: Color(hex: 0xB5CEA8),
        forcedAppearance: .dark
    )
    static let darcula = ColorTheme(
        id: "darcula", name: "Darcula (JetBrains)", accent: Color(hex: 0xCC7832),
        background: Color(hex: 0x2B2B2B),
        secondaryBackground: Color(hex: 0x3C3F41),
        keyword: Color(hex: 0xCC7832), string: Color(hex: 0x6A8759), number: Color(hex: 0x6897BB),
        forcedAppearance: .dark
    )
    static let monokaiPro = ColorTheme(
        id: "monokaiPro", name: "Monokai Pro", accent: Color(hex: 0xFF6188),
        background: Color(hex: 0x2D2A2E),
        secondaryBackground: Color(hex: 0x363338),
        keyword: Color(hex: 0xFF6188), string: Color(hex: 0xFFD866), number: Color(hex: 0xAB9DF2),
        forcedAppearance: .dark
    )
    static let zenburn = ColorTheme(
        id: "zenburn", name: "Zenburn", accent: Color(hex: 0xDFAF8F),
        background: Color(hex: 0x3F3F3F),
        secondaryBackground: Color(hex: 0x4F4F4F),
        keyword: Color(hex: 0xDFAF8F), string: Color(hex: 0x7F9F7F), number: Color(hex: 0x8CD0D3),
        forcedAppearance: .dark
    )

    static let all: [ColorTheme] = [
        .system, .light, .dark, .ocean, .sunset, .forest, .violet,
        .nord, .dracula, .solarizedDark, .gruvbox, .monokai,
        .catppuccinMocha, .tokyoNight, .rosePine, .everforest, .oneDark,
        .kanagawa, .ayu, .palenight, .synthwave,
        .nightOwl, .githubDark, .cobalt2, .shadesOfPurple, .oceanicNext,
        .vscodeDarkPlus, .darcula, .monokaiPro, .zenburn,
    ]

    static func theme(forID id: String) -> ColorTheme {
        all.first(where: { $0.id == id }) ?? .system
    }
}
