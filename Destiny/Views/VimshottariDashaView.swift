import SwiftUI
import DestinyEngine

/// A manually-flattened outline (not Table's built-in children: API) --
/// that API has no way to control which rows start expanded, and the
/// whole point here is to open with today's Mahadasha/Antardasha already
/// drilled open down to the running Pratyantardasha, not fully collapsed.
/// `expandedIDs` tracks which rows are open; `flattenedRows` walks the
/// tree fresh each render, only descending into a period's subPeriods
/// when its id is in that set.
///
/// id is derived deterministically (level + lord + start date) rather
/// than a fresh `UUID()` per instance -- this rebuilds every body
/// evaluation, and a random id would make every rebuild look like an
/// entirely new set of rows to the Table, resetting selection/scroll.
struct VimshottariDashaView: View {
    let periods: [DashaPeriod]
    @State private var selection: String?
    @State private var expandedIDs: Set<String>
    private let currentIDs: Set<String>
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    private struct Row: Identifiable {
        let id: String
        let period: DashaPeriod
        let level: Int // 0 = Mahadasha, 1 = Antardasha, 2 = Pratyantardasha
        let isCurrent: Bool

        static let levelNames = ["Mahadasha", "Antardasha", "Pratyantardasha"]
        var levelName: String { Self.levelNames[min(level, Self.levelNames.count - 1)] }
    }

    /// Finds which Mahadasha/Antardasha/Pratyantardasha contains `now`
    /// (real wall-clock "today", not the birth date) and seeds both the
    /// "Now" badge set and the initially-expanded rows in one pass, so
    /// the two can never disagree about what "current" means.
    init(periods: [DashaPeriod]) {
        self.periods = periods
        let now = Date()
        var current: Set<String> = []
        var expanded: Set<String> = []
        if let maha = periods.first(where: { $0.startDate <= now && now < $0.endDate }) {
            let mahaID = Self.rowID(maha, level: 0)
            current.insert(mahaID)
            expanded.insert(mahaID)
            if let antar = maha.subPeriods.first(where: { $0.startDate <= now && now < $0.endDate }) {
                let antarID = Self.rowID(antar, level: 1)
                current.insert(antarID)
                expanded.insert(antarID)
                if let praty = antar.subPeriods.first(where: { $0.startDate <= now && now < $0.endDate }) {
                    current.insert(Self.rowID(praty, level: 2))
                }
            }
        }
        self.currentIDs = current
        _expandedIDs = State(initialValue: expanded)
    }

    private static func rowID(_ period: DashaPeriod, level: Int) -> String {
        "\(level)-\(period.lord.rawValue)-\(Int(period.startDate.timeIntervalSince1970))"
    }

    private var flattenedRows: [Row] {
        var result: [Row] = []
        func walk(_ list: [DashaPeriod], level: Int) {
            for period in list {
                let id = Self.rowID(period, level: level)
                result.append(Row(id: id, period: period, level: level, isCurrent: currentIDs.contains(id)))
                if !period.subPeriods.isEmpty && expandedIDs.contains(id) {
                    walk(period.subPeriods, level: level + 1)
                }
            }
        }
        walk(periods, level: 0)
        return result
    }

    /// Literal point-size scaling (not .font(.title2) etc.) so the Text
    /// Size zoom actually affects this Table's cells -- see FontZoom's doc
    /// comment for why .dynamicTypeSize/.scaleEffect don't work here.
    private var cellFont: Font { .system(size: 17 * fontZoomMultiplier) }
    private var levelLabelFont: Font { .system(size: 13 * fontZoomMultiplier) }

    var body: some View {
        Table(flattenedRows, selection: $selection) {
            TableColumn("Mahadasha") { row in
                HStack(spacing: 6) {
                    if row.period.subPeriods.isEmpty {
                        Color.clear.frame(width: 14)
                    } else {
                        Button {
                            toggle(row.id)
                        } label: {
                            Image(systemName: expandedIDs.contains(row.id) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10 * fontZoomMultiplier))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 14)
                    }
                    Text(row.period.lord.displayName)
                        .foregroundStyle(theme.keyword)
                    if row.level > 0 {
                        Text(row.levelName)
                            .font(levelLabelFont)
                            .foregroundStyle(.secondary)
                    }
                    if row.isCurrent {
                        nowBadge
                    }
                }
                .padding(.leading, CGFloat(row.level) * 16)
                .font(cellFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowHighlight(row))
            }
            TableColumn("Duration") { row in
                let years = row.period.endDate.timeIntervalSince(row.period.startDate) / (VimshottariDasha.daysPerYear * 86400)
                Text(row.level == 0 ? dashaDurationDisplay(years: years) : dashaSubPeriodDurationDisplay(years: years))
                    .font(cellFont)
                    .foregroundStyle(theme.number)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowHighlight(row))
            }
            TableColumn("Start") { row in
                Text(dashaDateFormatter.string(from: row.period.startDate))
                    .font(cellFont)
                    .foregroundStyle(theme.string)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowHighlight(row))
            }
            TableColumn("End") { row in
                Text(dashaDateFormatter.string(from: row.period.endDate))
                    .font(cellFont)
                    .foregroundStyle(theme.string)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowHighlight(row))
            }
        }
        // This is the only content on its whole page/section (unlike the
        // other tables in the app, which sit above further content), so it
        // fills all available height instead of a small fixed box -- a
        // small fixed height here just left phantom empty striped rows
        // padding out the unused space.
        .frame(maxHeight: .infinity)
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }

    private var nowBadge: some View {
        Text("Now")
            .font(levelLabelFont.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.accent.opacity(0.25), in: Capsule())
            .foregroundStyle(theme.accent)
    }

    private func rowHighlight(_ row: Row) -> Color {
        row.isCurrent ? theme.accent.opacity(0.12) : Color.clear
    }

    private func toggle(_ id: String) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}
