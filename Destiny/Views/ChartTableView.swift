import SwiftUI
import DestinyEngine

private struct ChartTableRow: Identifiable {
    let id: String
    let label: String
    let absoluteLongitude: Double
    let degreeWithinSign: Double
    let rasi: Rasi
    let nakshatra: Nakshatra
    let pada: Int
    let isRetrograde: Bool
    let isCombust: Bool
    let karaka: KarakaRole?

    var planetCell: String {
        var markers = ""
        if isRetrograde { markers += " ^" }
        if isCombust { markers += " *" }
        return label + markers
    }

    var karakaCell: String { karaka?.rawValue ?? "-" }
}

struct ChartTableView: View {
    let computation: ChartComputation
    @State private var selection: String?
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }
    private var cellFont: Font { .system(size: 13 * fontZoomMultiplier) }

    private var rows: [ChartTableRow] {
        var result: [ChartTableRow] = [
            ChartTableRow(
                id: "ascendant", label: "Ascendant",
                absoluteLongitude: computation.ascendant.absoluteLongitude,
                degreeWithinSign: computation.ascendant.absoluteLongitude.truncatingRemainder(dividingBy: 30),
                rasi: computation.ascendant.rasi, nakshatra: computation.ascendant.nakshatra,
                pada: Nakshatra.pada(forLongitude: computation.ascendant.absoluteLongitude),
                isRetrograde: false, isCombust: false, karaka: nil
            ),
        ]
        result += computation.rows.map { row in
            ChartTableRow(
                id: row.body.rawValue, label: row.body.displayName,
                absoluteLongitude: row.absoluteLongitude, degreeWithinSign: row.degreeWithinSign,
                rasi: row.rasi, nakshatra: row.nakshatra,
                pada: Nakshatra.pada(forLongitude: row.absoluteLongitude),
                isRetrograde: row.isRetrograde, isCombust: row.isCombust, karaka: row.karaka
            )
        }
        return result
    }

    /// Table/List need *some* bounded height when nested inside a
    /// ScrollView -- they're viewport-based, not auto-sizing-to-content --
    /// so this is sized to the actual row count instead of either an
    /// arbitrary fixed value (which left empty striped rows below short
    /// tables) or no constraint at all (which collapsed them to nothing).
    private var tableHeight: CGFloat {
        CGFloat(rows.count) * 28 * fontZoomMultiplier + 30
    }

    var body: some View {
        // "Text" theming experiment: planet/lord names read as the theme's
        // keyword color (its most prominent syntax color), rasi/nakshatra
        // names as string color, and raw numeric values as number color --
        // mirroring how a real editor theme distinguishes different kinds
        // of text rather than coloring everything the same.
        Table(rows, selection: $selection) {
            TableColumn("Planet") { row in
                Text(row.planetCell).font(cellFont).foregroundStyle(theme.keyword)
            }
            TableColumn("Position") { row in
                Text(String(format: "%.2f\u{00B0}", row.absoluteLongitude)).font(cellFont).foregroundStyle(theme.number)
            }
            TableColumn("Deg. in Sign") { row in
                Text(String(format: "%.2f\u{00B0}", row.degreeWithinSign)).font(cellFont).foregroundStyle(theme.number)
            }
            TableColumn("Rasi") { row in
                Text(row.rasi.displayName).font(cellFont).foregroundStyle(theme.string)
            }
            TableColumn("Rasi Lord") { row in
                Text(row.rasi.lord.displayName).font(cellFont).foregroundStyle(theme.keyword)
            }
            TableColumn("Nakshatra") { row in
                Text(row.nakshatra.displayName).font(cellFont).foregroundStyle(theme.string)
            }
            TableColumn("Pada") { row in
                Text("\(row.pada)").font(cellFont).foregroundStyle(theme.number)
            }
            TableColumn("Nakshatra Lord") { row in
                Text(row.nakshatra.lord.displayName).font(cellFont).foregroundStyle(theme.keyword)
            }
            TableColumn("Karaka") { row in
                Text(row.karakaCell).font(cellFont)
            }
        }
        .frame(height: tableHeight)
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }
}
