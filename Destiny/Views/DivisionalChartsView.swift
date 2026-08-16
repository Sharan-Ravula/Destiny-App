import SwiftUI
import DestinyEngine

/// Handles D1 (Rasi) alongside every divisional chart -- one shared varga
/// picker (D1 included), with the analysis panels/table swapping between
/// D1-specific content (doshas, Karakamsa, Arudha Padas, Chara Karakas)
/// and the shared varga-analysis content depending on what's selected.
/// D1 and every varga used to be 2 separate pages; merged into one since
/// they share almost all their layout machinery.
struct DivisionalChartsView: View {
    let computation: ChartComputation

    /// Lifted up to ChartDetailView (not local @State) so "Explore
    /// Transits" can open on whichever chart is currently on screen here.
    @Binding var selectedVarga: DivisionalChart
    /// Passed down from ChartDetailView's GeometryReader so the panel/
    /// chart sizing below reacts to the sidebar opening/closing.
    let availableWidth: CGFloat
    @State private var style: ChartRenderStyle = .northIndian
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    /// Same key as ChartDetailView's -- one chart-size preference shared
    /// across both pages.
    @AppStorage("chartSizeStep") private var chartSizeStep: Int = 0
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    /// nil for D1 (which reads directly off `computation`, not a
    /// VargaChart) and for the theoretically-unreachable case where a
    /// selected varga has no matching computed chart.
    private var vargaChart: VargaChart? {
        selectedVarga == .d1 ? nil : computation.vargas.first(where: { $0.varga == selectedVarga })
    }

    private var layout: ChartLayoutData {
        if selectedVarga == .d1 {
            return ChartLayoutData(computation: computation)
        }
        guard let vargaChart else { return ChartLayoutData(computation: computation) }
        // Karakamsa (Atmakaraka's Navamsa sign) only makes sense in D9.
        let karakamsaRasi = selectedVarga == .d9 ? computation.summary.karakamsa : nil
        return ChartLayoutData(varga: vargaChart, karakamsaRasi: karakamsaRasi)
    }

    private var legendAbbreviations: [(abbr: String, meaning: String)] {
        switch selectedVarga {
        case .d1: return [("Asc", "Ascendant"), ("Ar", "Arudha Lagna"), ("Up", "Upapada Lagna")]
        case .d9: return [("Asc", "Ascendant"), ("Kk", "Karakamsa Lagna")]
        default: return [("Asc", "Ascendant")]
        }
    }

    /// Body -> D1 rasi, for AnalysisPanelView's Rashi Drishti occupant
    /// labels (VargaAnalysis itself carries no placements).
    private var d1Placements: [CelestialBody: Rasi] {
        var result: [CelestialBody: Rasi] = [:]
        for row in computation.rows { result[row.body] = row.rasi }
        return result
    }

    /// The 4 mechanical categories are already on computation.summary
    /// (unchanged, still D1-specific) -- just repackaged into the shared
    /// VargaAnalysis shape so AnalysisPanelView can render D1 and every
    /// varga with the same view.
    private var d1Analysis: VargaAnalysis {
        let summary = computation.summary
        return VargaAnalysis(
            conjunctions: summary.conjunctions, aspects: summary.aspects,
            ascendantAspectedBy: summary.ascendantAspectedBy, houseLordships: summary.houseLordships,
            rashiAspects: summary.rashiAspects
        )
    }

    /// Same idea as ChartDetailView's own copy (kept separate rather than
    /// shared to avoid a cross-file dependency for ~15 lines of math) --
    /// scales panel width and chart size down together as available width
    /// shrinks, computed fresh from GeometryReader's measured width on
    /// every layout pass, no ScrollView involved.
    private static func panelAndChartSize(availableWidth: CGFloat, panelCount: CGFloat, chartCount: CGFloat, chartSpacing: CGFloat, chartSizeMultiplier: CGFloat) -> (panel: CGFloat, chart: CGFloat) {
        let idealPanel: CGFloat = 320
        let idealChart: CGFloat = 420 * chartSizeMultiplier
        let minPanel: CGFloat = 220
        let minChart: CGFloat = 280 * chartSizeMultiplier
        let fixedSpacing: CGFloat = 20 * 2 + chartSpacing

        let idealContent = idealPanel * panelCount + idealChart * chartCount
        guard availableWidth < idealContent + fixedSpacing else {
            return (idealPanel, idealChart)
        }

        let availableForContent = max(0, availableWidth - fixedSpacing)
        let scale = idealContent > 0 ? availableForContent / idealContent : 1
        var panel = idealPanel * scale
        var chart = idealChart * scale

        if panel < minPanel {
            panel = minPanel
            chart = chartCount > 0 ? max(0, availableForContent - minPanel * panelCount) / chartCount : chart
        } else if chart < minChart {
            chart = minChart
            panel = panelCount > 0 ? max(0, availableForContent - minChart * chartCount) / panelCount : panel
        }

        return (max(minPanel, panel), max(minChart, chart))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let sizes = Self.panelAndChartSize(
                availableWidth: availableWidth, panelCount: 2, chartCount: 1, chartSpacing: 0,
                chartSizeMultiplier: ChartSizeZoom.multiplier(forStep: chartSizeStep)
            )

            // The row's own width is fixed (panel/chart sizes only shrink
            // below their ideal, they don't grow past it), so once the
            // sidebar closes and there's more room than the row needs, it
            // would otherwise just sit at the leading edge of that extra
            // space instead of using it -- the outer frame here re-centers
            // the whole row instead.
            HStack(alignment: .top, spacing: 20) {
                leftPanel
                    .frame(width: sizes.panel, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    // Varga/Style pickers + the chart-size control live
                    // inside this same flex-width middle column (not a
                    // separate full-page-width row above the whole 3-panel
                    // layout) specifically so the size control's trailing
                    // overlay is anchored to this column's width rather
                    // than the full page.
                    HStack {
                        Picker("Varga", selection: $selectedVarga) {
                            ForEach(DivisionalChart.allCases, id: \.self) { varga in
                                Text(varga.rawValue).tag(varga)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()

                        Picker("Style", selection: $style) {
                            ForEach(ChartRenderStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(alignment: .trailing) { chartSizeControl }

                    // A fixed size (not maxWidth) on the chart itself, then
                    // a separate outer frame to center it -- more reliable
                    // than an HStack+Spacer pair here, since the chart's
                    // GeometryReader content always greedily fills
                    // whatever it's offered, which made its flexibility
                    // ambiguous to the HStack's own space-distribution
                    // algorithm and left the Spacers with no slack to
                    // actually split evenly.
                    Group {
                        switch style {
                        case .northIndian:
                            NorthIndianChartView(layout: layout)
                        case .southIndian:
                            SouthIndianChartView(layout: layout)
                        }
                    }
                    .frame(width: sizes.chart, height: sizes.chart)
                    .frame(maxWidth: .infinity, alignment: .center)

                    chartLegendText(
                        theme: theme,
                        abbreviations: legendAbbreviations,
                        markers: [("*", "combust"), ("^", "Retrograde")]
                    )
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                rightPanel
                    .frame(width: sizes.panel, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Planetary Positions").font(.headline)
            planetaryTable
        }
    }

    @ViewBuilder
    private var leftPanel: some View {
        if selectedVarga == .d1 {
            AnalysisPanelView(analysis: d1Analysis, placements: d1Placements, sections: .exceptHouseLordships)
        } else if let vargaChart {
            // Rashi Drishti + Graha Drishti on the left, Conjunctions +
            // House Lordships on the right. There's no D1-style reference
            // panel here -- doshas/Arudha/Upapada/karakas are D1-only (see
            // VargaAnalysis's doc comment).
            AnalysisPanelView(analysis: vargaChart.analysis, placements: vargaChart.placements, sections: .rashiAndGrahaDrishti)
        }
    }

    @ViewBuilder
    private var rightPanel: some View {
        if selectedVarga == .d1 {
            VStack(alignment: .leading, spacing: 16) {
                D1ReferencePanelView(computation: computation)
                AnalysisPanelView(analysis: d1Analysis, placements: d1Placements, sections: .houseLordshipsOnly)
            }
        } else if let vargaChart {
            AnalysisPanelView(analysis: vargaChart.analysis, placements: vargaChart.placements, sections: .conjunctionsAndLordships)
        }
    }

    @ViewBuilder
    private var planetaryTable: some View {
        if selectedVarga == .d1 {
            ChartTableView(computation: computation)
        } else if let vargaChart {
            VargaPlacementTable(computation: computation, vargaChart: vargaChart)
        } else {
            Text("No data for \(selectedVarga.rawValue).")
                .foregroundStyle(.secondary)
        }
    }

    /// +/- chart-size control, same pattern as ChartDetailView's own copy.
    private var chartSizeControl: some View {
        HStack(spacing: 6) {
            Button {
                chartSizeStep = max(ChartSizeZoom.minStep, chartSizeStep - 1)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .disabled(chartSizeStep <= ChartSizeZoom.minStep)

            Text("\(Int((ChartSizeZoom.multiplier(forStep: chartSizeStep) * 100).rounded()))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 36)

            Button {
                chartSizeStep = min(ChartSizeZoom.maxStep, chartSizeStep + 1)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .disabled(chartSizeStep >= ChartSizeZoom.maxStep)
        }
        .foregroundStyle(.secondary)
    }
}

/// Every column here is genuinely varga-specific, not repeated D1 data:
/// Deg. in Sign is the planet's proportional position within whichever
/// division determined its resulting sign (scaled to fill 0-30), and
/// Nakshatra/Nakshatra Lord are derived from that same scaled position --
/// see DivisionalChart.degreeWithinResultingSign. Nakshatra isn't a
/// classical per-varga concept (traditionally it's a D1-only idea used for
/// dasha etc.), so this is a deliberately-computed synthetic value, not a
/// textbook one; confirmed with user before implementing it this way.
struct VargaPlacementTable: View {
    let computation: ChartComputation
    let vargaChart: VargaChart
    @State private var selection: String?
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }
    private var cellFont: Font { .system(size: 13 * fontZoomMultiplier) }

    private struct Row: Identifiable {
        let id: String
        let label: String
        let vargaRasi: Rasi
        let degreeWithinSign: Double
        let nakshatra: Nakshatra
        let pada: Int
        let isRetrograde: Bool
        let isCombust: Bool

        var planetCell: String {
            var markers = ""
            if isRetrograde { markers += " ^" }
            if isCombust { markers += " *" }
            return label + markers
        }
    }

    /// The varga's own nakshatra, applying the same 13deg20' math D1 uses
    /// but to this varga's synthetic absolute longitude (its resulting
    /// sign's start + its own scaled degree within that sign) instead of
    /// the planet's real D1 longitude.
    private func vargaNakshatra(rasi: Rasi, degreeWithinSign: Double) -> Nakshatra {
        Nakshatra.containing(longitude: Double(rasi.rawValue) * 30 + degreeWithinSign)
    }

    private func vargaPada(rasi: Rasi, degreeWithinSign: Double) -> Int {
        Nakshatra.pada(forLongitude: Double(rasi.rawValue) * 30 + degreeWithinSign)
    }

    private var rows: [Row] {
        var result = [
            Row(
                id: "ascendant", label: "Ascendant", vargaRasi: vargaChart.ascendant,
                degreeWithinSign: vargaChart.ascendantDegreeWithinSign,
                nakshatra: vargaNakshatra(rasi: vargaChart.ascendant, degreeWithinSign: vargaChart.ascendantDegreeWithinSign),
                pada: vargaPada(rasi: vargaChart.ascendant, degreeWithinSign: vargaChart.ascendantDegreeWithinSign),
                isRetrograde: false, isCombust: false
            ),
        ]
        for d1Row in computation.rows {
            guard let vargaRasi = vargaChart.placements[d1Row.body],
                  let vargaDegree = vargaChart.degreesWithinSign[d1Row.body] else { continue }
            result.append(Row(
                id: d1Row.body.rawValue, label: d1Row.body.displayName,
                vargaRasi: vargaRasi, degreeWithinSign: vargaDegree,
                nakshatra: vargaNakshatra(rasi: vargaRasi, degreeWithinSign: vargaDegree),
                pada: vargaPada(rasi: vargaRasi, degreeWithinSign: vargaDegree),
                isRetrograde: d1Row.isRetrograde, isCombust: d1Row.isCombust
            ))
        }
        return result
    }

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("Planet") { Text($0.planetCell).font(cellFont).foregroundStyle(theme.keyword) }
            TableColumn("Rasi") { Text($0.vargaRasi.displayName).font(cellFont).foregroundStyle(theme.string) }
            TableColumn("Rasi Lord") { Text($0.vargaRasi.lord.displayName).font(cellFont).foregroundStyle(theme.keyword) }
            TableColumn("Deg. in Sign") { Text(String(format: "%.2f\u{00B0}", $0.degreeWithinSign)).font(cellFont).foregroundStyle(theme.number) }
            TableColumn("Nakshatra") { Text($0.nakshatra.displayName).font(cellFont).foregroundStyle(theme.string) }
            TableColumn("Pada") { Text("\($0.pada)").font(cellFont).foregroundStyle(theme.number) }
            TableColumn("Nakshatra Lord") { Text($0.nakshatra.lord.displayName).font(cellFont).foregroundStyle(theme.keyword) }
        }
        .frame(height: CGFloat(rows.count) * 28 * fontZoomMultiplier + 30)
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }
}
