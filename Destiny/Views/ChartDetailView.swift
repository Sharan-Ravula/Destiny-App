import SwiftUI
import DestinyEngine

struct ChartDetailView: View {
    let record: ChartRecord

    private enum Section: String, CaseIterable, Identifiable {
        case d1 = "D1 Chart"
        case vargas = "Divisional Charts"
        case vimshottari = "Vimshottari Dasha"
        case chara = "Chara Dasha"
        var id: String { rawValue }
    }

    @State private var section: Section = .d1
    @State private var d1Style: ChartRenderStyle = .northIndian
    @State private var selectedVarga: DivisionalChart = .d9
    @State private var showingTransitExplorer = false

    /// Whatever chart is currently on screen -- D1 by default, or
    /// whichever varga is selected when the Divisional Cha     rts tab is
    /// active -- so "Explore Transits" opens already showing that chart.
    private var transitExplorerInitialVarga: DivisionalChart {
        section == .vargas ? selectedVarga : .d1
    }
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    /// Built via DateFormatter (not raw Int interpolation) so the month
    /// reads as text and the year doesn't pick up a thousands separator --
    /// SwiftUI's Text(_:) string interpolation applies locale-aware number
    /// grouping to bare Int values (e.g. year 2026 rendering as "2,026").
    private var birthDateDisplay: String {
        let moment = record.input.birthMoment
        var components = DateComponents()
        components.year = moment.year
        components.month = moment.month
        components.day = moment.day
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            return "\(moment.year)-\(moment.month)-\(moment.day)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// hour/minute on BirthMoment are already the birth-local wall clock
    /// (not a UTC instant), so no time zone conversion is needed here.
    private var birthTimeDisplay: String {
        let moment = record.input.birthMoment
        let hour12 = moment.hour % 12 == 0 ? 12 : moment.hour % 12
        let ampm = moment.hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, moment.minute, ampm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .center)

            // Vimshottari and Chara Dasha are the only content on their own
            // pages (unlike the other sections, which stack several pieces
            // above/below each other), and their Tables scroll internally
            // on their own -- nesting them in the same outer ScrollView as
            // everything else meant they could never actually claim the
            // full remaining height, leaving a small fixed box padded out
            // with phantom empty rows.
            switch section {
            case .vimshottari:
                VimshottariDashaView(periods: record.computation.vimshottariDasha)
                    .padding(.top, 4)
            case .chara:
                CharaDashaView(periods: record.computation.charaDasha)
                    .padding(.top, 4)
            default:
                // GeometryReader + frame(minHeight:) (not just a bare
                // ScrollView) -- a ScrollView always expands to fill
                // whatever height its parent offers regardless of how
                // short its content is, and that content was top-aligned
                // within it, so on a tall window/monitor the content sat
                // near the top with a large empty gap below. minHeight
                // matching the viewport plus vertical-center alignment
                // splits that leftover space evenly above/below when
                // content is shorter than the page, while still scrolling
                // normally if content ever exceeds it.
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch section {
                            case .d1:
                                d1Section(availableWidth: geometry.size.width)
                            case .vargas:
                                DivisionalChartsView(computation: record.computation, selectedVarga: $selectedVarga, availableWidth: geometry.size.width)
                            case .vimshottari, .chara:
                                EmptyView()
                            }
                        }
                        .padding(.top, 4)
                        .frame(minHeight: geometry.size.height, alignment: .top)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
        .sheet(isPresented: $showingTransitExplorer) {
            TransitExplorerView(record: record, initialVarga: transitExplorerInitialVarga)
        }
    }

    private var header: some View {
        // No Spacer between the name and the grid -- HStack's own `spacing`
        // already gives a fixed gap, so the whole (name + grid) block sizes
        // to its natural width and the outer frame below centers that block
        // as a unit, rather than a Spacer greedily shoving the grid to the
        // far trailing edge.
        HStack(alignment: .top, spacing: 32) {
            Text(record.input.name)
                .font(.title2.bold())
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 4) {
                GridRow {
                    fieldLabel("Place of Birth")
                    Text(record.input.placeName)
                    fieldLabel("Latitude")
                    Text("\(String(format: "%.4f", record.input.latitude))\u{00B0}")
                }
                GridRow {
                    fieldLabel("Date of Birth")
                    Text(birthDateDisplay)
                    fieldLabel("Longitude")
                    Text("\(String(format: "%.4f", record.input.longitude))\u{00B0}")
                }
                GridRow {
                    fieldLabel("Time of Birth")
                    Text(birthTimeDisplay)
                    fieldLabel("Time Zone")
                    Text(record.input.birthMoment.timeZoneIdentifier)
                }
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(alignment: .trailing) {
            Button {
                showingTransitExplorer = true
            } label: {
                Label("Explore Transits", systemImage: "clock.arrow.2.circlepath")
            }
            .buttonStyle(.bordered)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)
    }

    /// Body -> D1 rasi, for AnalysisPanelView's Rashi Drishti occupant
    /// labels (VargaAnalysis itself carries no placements).
    private var d1Placements: [CelestialBody: Rasi] {
        var result: [CelestialBody: Rasi] = [:]
        for row in record.computation.rows { result[row.body] = row.rasi }
        return result
    }

    /// The 4 mechanical categories are already on computation.summary
    /// (unchanged, still D1-specific) -- just repackaged into the shared
    /// VargaAnalysis shape so AnalysisPanelView can render D1 and every
    /// varga with the same view.
    private var d1Analysis: VargaAnalysis {
        let summary = record.computation.summary
        return VargaAnalysis(
            conjunctions: summary.conjunctions, aspects: summary.aspects,
            ascendantAspectedBy: summary.ascendantAspectedBy, houseLordships: summary.houseLordships,
            rashiAspects: summary.rashiAspects
        )
    }

    /// Scales panel width and chart size down together as available width
    /// shrinks (sidebar opening/closing, window resize), computed fresh
    /// from GeometryReader's measured width on every layout pass -- so it
    /// reacts automatically to the sidebar's actual current state rather
    /// than assuming one fixed size. No ScrollView involved (that
    /// combination caused its own rendering problems for no benefit) --
    /// just a plain HStack sized to always fit exactly.
    private static func panelAndChartSize(availableWidth: CGFloat, panelCount: CGFloat, chartCount: CGFloat, idealChart: CGFloat, minChart: CGFloat, chartSpacing: CGFloat) -> (panel: CGFloat, chart: CGFloat) {
        let idealPanel: CGFloat = 320
        let minPanel: CGFloat = 220
        let fixedSpacing: CGFloat = 20 * 2 + chartSpacing // gaps around the center column + between charts

        let idealContent = idealPanel * panelCount + idealChart * chartCount
        guard availableWidth < idealContent + fixedSpacing else {
            return (idealPanel, idealChart)
        }

        let availableForContent = max(0, availableWidth - fixedSpacing)
        let scale = idealContent > 0 ? availableForContent / idealContent : 1
        var panel = idealPanel * scale
        var chart = idealChart * scale

        // If scaling alone would push one dimension below its floor,
        // clamp it and let the other absorb the remaining budget so the
        // total still fits exactly instead of drifting past availableWidth.
        if panel < minPanel {
            panel = minPanel
            chart = chartCount > 0 ? max(0, availableForContent - minPanel * panelCount) / chartCount : chart
        } else if chart < minChart {
            chart = minChart
            panel = panelCount > 0 ? max(0, availableForContent - minChart * chartCount) / panelCount : panel
        }

        return (max(minPanel, panel), max(minChart, chart))
    }

    /// Just the D1 (Rasi) chart -- D9 used to sit alongside it here, but
    /// two charts plus two side panels made this page's alignment fragile
    /// (see the panel-sizing history above), and D9 (and every other
    /// varga) already has its own full page with the same analysis
    /// panel/table treatment on Divisional Charts. Dropping to one chart
    /// also means it can be shown meaningfully larger.
    private func d1Section(availableWidth: CGFloat) -> some View {
        let sizes = Self.panelAndChartSize(availableWidth: availableWidth, panelCount: 2, chartCount: 1, idealChart: 460, minChart: 320, chartSpacing: 0)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                AnalysisPanelView(analysis: d1Analysis, placements: d1Placements, sections: .exceptHouseLordships)
                    .frame(width: sizes.panel, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Chart Style", selection: $d1Style) {
                        ForEach(ChartRenderStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity, alignment: .center)

                    // A fixed size (not maxWidth) on the chart itself,
                    // then a separate outer frame to center it -- see
                    // DivisionalChartsView's chart for why maxWidth+Spacer
                    // wasn't reliable with these GeometryReader-based
                    // chart views.
                    chartView(layout: ChartLayoutData(computation: record.computation))
                        .frame(width: sizes.chart, height: sizes.chart)
                        .frame(maxWidth: .infinity, alignment: .center)

                    chartLegendText(
                        theme: theme,
                        abbreviations: [
                            ("Asc", "Ascendant"), ("Ar", "Arudha Lagna"), ("Up", "Upapada Lagna"),
                        ],
                        markers: [("*", "combust"), ("^", "Retrograde")]
                    )
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 16) {
                    D1ReferencePanelView(computation: record.computation)
                    AnalysisPanelView(analysis: d1Analysis, placements: d1Placements, sections: .houseLordshipsOnly)
                }
                .frame(width: sizes.panel, alignment: .leading)
            }

            Text("Planetary Positions").font(.headline)
            ChartTableView(computation: record.computation)
        }
    }

    @ViewBuilder
    private func chartView(layout: ChartLayoutData) -> some View {
        switch d1Style {
        case .northIndian:
            NorthIndianChartView(layout: layout)
        case .southIndian:
            SouthIndianChartView(layout: layout)
        }
    }
}
