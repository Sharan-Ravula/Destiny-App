import SwiftUI

let dashaDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
}()

private func pluralized(_ count: Int, _ unit: String) -> String {
    "\(count) \(unit)\(count == 1 ? "" : "s")"
}

/// Whole years read as "N years"; a year with a leftover fraction reads as
/// "N years M months"; under a year reads as months, and under a month
/// falls back to days -- "0.8 years" as a bare number doesn't read
/// naturally, but "10 months" does. Used for Mahadasha rows, which are
/// always at least several years for both Vimshottari and Chara Dasha.
func dashaDurationDisplay(years: Double) -> String {
    if years >= 1 {
        var wholeYears = Int(years)
        var remainderMonths = Int(((years - Double(wholeYears)) * 12).rounded())
        // Rounding a remainder like 11.6 months up to 12 would otherwise
        // display as the nonsensical "N years 12 months" -- carry it into
        // the year instead.
        if remainderMonths >= 12 {
            wholeYears += 1
            remainderMonths = 0
        }
        guard remainderMonths > 0 else { return pluralized(wholeYears, "year") }
        return "\(pluralized(wholeYears, "year")) \(pluralized(remainderMonths, "month"))"
    }

    // Check the *unrounded* month count before deciding whether this reads
    // as months or days -- rounding first (e.g. 0.6 months -> 1) would
    // otherwise display "1 month" for a duration that's still under a
    // month.
    let exactMonths = years * 12
    guard exactMonths >= 1 else {
        let days = max(1, Int((years * 365.2425).rounded()))
        return pluralized(days, "day")
    }
    return pluralized(Int(exactMonths.rounded()), "month")
}

/// Months + leftover days, e.g. "3 months 12 days" or, under a month,
/// just "12 days" -- used for Antardasha/Pratyantardasha rows, which are
/// short enough that a year/month breakdown loses the precision that
/// actually matters at this level.
func dashaSubPeriodDurationDisplay(years: Double) -> String {
    let avgDaysPerMonth = 365.2425 / 12.0
    let totalDays = years * 365.2425
    var months = Int(totalDays / avgDaysPerMonth)
    var remainderDays = Int((totalDays - Double(months) * avgDaysPerMonth).rounded())
    if remainderDays >= Int(avgDaysPerMonth.rounded()) {
        months += 1
        remainderDays = 0
    }
    guard months > 0 else {
        return pluralized(max(1, remainderDays), "day")
    }
    guard remainderDays > 0 else { return pluralized(months, "month") }
    return "\(pluralized(months, "month")) \(pluralized(remainderDays, "day"))"
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
