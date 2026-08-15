import SwiftUI

let dashaDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
}()

/// Whole years read as "N years"; a year with a leftover fraction reads as
/// "N years M months"; under a year reads as months, and under a month
/// (common at the deepest Pratyantardasha level) falls back to days --
/// "0.8 years" as a bare number doesn't read naturally, but "10 months"
/// does.
func dashaDurationDisplay(years: Double) -> String {
    func pluralized(_ count: Int, _ unit: String) -> String {
        "\(count) \(unit)\(count == 1 ? "" : "s")"
    }

    if years >= 1 {
        let wholeYears = Int(years)
        let remainderMonths = Int(((years - Double(wholeYears)) * 12).rounded())
        guard remainderMonths > 0 else { return pluralized(wholeYears, "year") }
        return "\(pluralized(wholeYears, "year")) \(pluralized(remainderMonths, "month"))"
    }

    let months = Int((years * 12).rounded())
    guard months > 0 else {
        let days = max(1, Int((years * 365.2425).rounded()))
        return pluralized(days, "day")
    }
    return pluralized(months, "month")
}

/// Builds a "Asc = Ascendant    Ar = Arudha Lagna    * = combust" style
/// legend caption with each abbreviation/marker symbol in the theme's
/// keyword/number color and the "= meaning" part in secondary, instead of
/// one flat secondary-colored string -- used under the chart diagrams.
func chartLegendText(
    theme: ColorTheme,
    abbreviations: [(abbr: String, meaning: String)],
    markers: [(symbol: String, meaning: String)] = []
) -> Text {
    // Non-breaking spaces *within* an "X = meaning" pair (not between
    // pairs) -- otherwise a line wrap could split e.g. "^" from
    // "= Retrograde" onto separate lines while leaving them looking like
    // two unrelated fragments. Wrapping between whole pairs (separated by
    // regular, breakable spaces) is fine.
    let abbrParts = abbreviations.map { entry -> Text in
        Text("\(Text(entry.abbr).foregroundStyle(theme.keyword))\u{00A0}=\u{00A0}\(entry.meaning)")
            .foregroundStyle(.secondary)
    }
    let markerParts = markers.map { entry -> Text in
        Text("\(Text(entry.symbol).foregroundStyle(theme.number))\u{00A0}=\u{00A0}\(entry.meaning)")
            .foregroundStyle(.secondary)
    }
    let allParts = abbrParts + markerParts
    guard let first = allParts.first else { return Text("") }
    return allParts.dropFirst().reduce(first) { partial, part in
        Text("\(partial)    \(part)")
    }
}
