import SwiftUI
import CoreGraphics
import DestinyEngine

/// Which chart style(s) to draw in the exported PDF -- independent of
/// whatever style is currently selected on screen, since a PDF export
/// might reasonably want a different combination (e.g. both styles side
/// by side) than the live view.
enum PDFChartStyleOption: String, CaseIterable, Identifiable {
    case northIndian = "North Indian"
    case southIndian = "South Indian"
    case both = "Both"
    var id: String { rawValue }
}

enum ChartPDFExportError: Error {
    case cannotCreateContext
}

private let pdfPageWidth: CGFloat = 760
private let pdfPagePadding: CGFloat = 30

/// Builds one PDF document: a cover page (metadata + doshas/Karakamsa/
/// Arudha Padas/Chara Karakas -- these are D1-only concepts, see
/// VargaAnalysis's doc comment, so they're always included exactly once
/// here rather than tied to whether D1 itself is among the selected
/// charts), followed by one page per selected chart (diagram(s) +
/// planetary positions table). Conjunctions/Graha Drishti/Rashi Drishti/
/// House Lordships are deliberately left out -- this is meant to be a
/// compact reference printout, not the full on-screen analysis, and
/// Vimshottari/Chara Dasha are left out too (too long to usefully print).
enum ChartPDFExporter {
    @MainActor
    static func export(record: ChartRecord, charts: [DivisionalChart], styleOption: PDFChartStyleOption, to url: URL) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ChartPDFExportError.cannotCreateContext }
        var initialMediaBox = CGRect(x: 0, y: 0, width: pdfPageWidth, height: 792)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &initialMediaBox, nil) else {
            throw ChartPDFExportError.cannotCreateContext
        }

        renderPage(PDFCoverPageView(record: record), in: pdfContext)
        for chart in charts {
            renderPage(PDFChartPageView(record: record, chart: chart, styleOption: styleOption), in: pdfContext)
        }

        pdfContext.closePDF()
    }

    /// Renders one SwiftUI view as a single PDF page sized exactly to that
    /// view's natural height at a fixed page width (.fixedSize(vertical:)
    /// makes ImageRenderer report the content's ideal height for that
    /// width instead of an ambient/expanding one) -- not fixed US Letter
    /// page breaks, so every chart's content always fits on its own page
    /// without needing separate pagination logic.
    @MainActor
    private static func renderPage(_ view: some View, in pdfContext: CGContext) {
        // This app sets its theme by mutating NSApp.appearance globally
        // (see ContentView), not via SwiftUI's .preferredColorScheme --
        // so .primary/.secondary text (used throughout D1ReferencePanelView
        // and elsewhere) would still pick up whatever the *live* app
        // appearance is without this. Forcing colorScheme directly in the
        // environment here is what actually makes those resolve to light
        // regardless of NSApp.appearance.
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light).fixedSize(horizontal: false, vertical: true))
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: NSData(bytes: &mediaBox, length: MemoryLayout<CGRect>.size),
            ]
            pdfContext.beginPDFPage(pageInfo as CFDictionary)
            draw(pdfContext)
            pdfContext.endPDFPage()
        }
    }
}

// MARK: - Cover page

private struct PDFCoverPageView: View {
    let record: ChartRecord
    // Always light/print-friendly, regardless of whatever theme is
    // currently selected on screen -- a PDF meant for printing/sharing
    // shouldn't come out in whatever dark palette happens to be active.
    private let theme = ColorTheme.light

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

    private var birthTimeDisplay: String {
        let moment = record.input.birthMoment
        let hour12 = moment.hour % 12 == 0 ? 12 : moment.hour % 12
        let ampm = moment.hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, moment.minute, ampm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(record.input.name).font(.system(size: 26, weight: .bold))

            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 6) {
                GridRow {
                    metadataLabel("Place of Birth")
                    Text(record.input.placeName)
                    metadataLabel("Latitude")
                    Text("\(String(format: "%.4f", record.input.latitude))\u{00B0}")
                }
                GridRow {
                    metadataLabel("Date of Birth")
                    Text(birthDateDisplay)
                    metadataLabel("Longitude")
                    Text("\(String(format: "%.4f", record.input.longitude))\u{00B0}")
                }
                GridRow {
                    metadataLabel("Time of Birth")
                    Text(birthTimeDisplay)
                    metadataLabel("Time Zone")
                    Text(record.input.birthMoment.timeZoneIdentifier)
                }
                if let gender = record.input.gender {
                    GridRow {
                        metadataLabel("Gender")
                        Text(gender.rawValue)
                        Text("")
                        Text("")
                    }
                }
            }
            .font(.system(size: 13))

            Divider()

            D1ReferencePanelView(computation: record.computation, overrideTheme: theme)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .padding(pdfPagePadding)
        .frame(width: pdfPageWidth, alignment: .leading)
        .background(theme.background)
    }

    private func metadataLabel(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).fontWeight(.semibold)
    }
}

// MARK: - Per-chart page

private struct PDFChartPageView: View {
    let record: ChartRecord
    let chart: DivisionalChart
    let styleOption: PDFChartStyleOption
    // Always light/print-friendly -- see PDFCoverPageView's comment.
    private let theme = ColorTheme.light

    private var vargaChart: VargaChart? {
        chart == .d1 ? nil : record.computation.vargas.first(where: { $0.varga == chart })
    }

    private var layout: ChartLayoutData {
        if chart == .d1 {
            return ChartLayoutData(computation: record.computation)
        }
        guard let vargaChart else { return ChartLayoutData(computation: record.computation) }
        let karakamsaRasi = chart == .d9 ? record.computation.summary.karakamsa : nil
        return ChartLayoutData(varga: vargaChart, karakamsaRasi: karakamsaRasi)
    }

    private var title: String {
        chart == .d1 ? "D1 \u{2013} Rasi Chart" : chart.rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 20, weight: .bold))
            diagrams
            planetaryTable
        }
        .padding(pdfPagePadding)
        .frame(width: pdfPageWidth, alignment: .leading)
        .background(theme.background)
    }

    @ViewBuilder
    private var diagrams: some View {
        let contentWidth = pdfPageWidth - pdfPagePadding * 2
        switch styleOption {
        case .northIndian:
            NorthIndianChartView(layout: layout, overrideTheme: theme)
                .frame(width: 380, height: 380)
                .frame(maxWidth: .infinity, alignment: .center)
        case .southIndian:
            SouthIndianChartView(layout: layout, overrideTheme: theme)
                .frame(width: 380, height: 380)
                .frame(maxWidth: .infinity, alignment: .center)
        case .both:
            let side = (contentWidth - 24) / 2
            HStack(spacing: 24) {
                NorthIndianChartView(layout: layout, overrideTheme: theme).frame(width: side, height: side)
                SouthIndianChartView(layout: layout, overrideTheme: theme).frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var planetaryTable: some View {
        if chart == .d1 {
            PDFTableView(columns: Self.d1Columns, rows: Self.d1Rows(computation: record.computation, theme: theme))
        } else if let vargaChart {
            PDFTableView(columns: Self.vargaColumns, rows: Self.vargaRows(computation: record.computation, vargaChart: vargaChart, theme: theme))
        }
    }

    private static let d1Columns: [PDFTableColumn] = [
        PDFTableColumn(title: "Planet", width: 90), PDFTableColumn(title: "Position", width: 70),
        PDFTableColumn(title: "Deg. in Sign", width: 70), PDFTableColumn(title: "Rasi", width: 80),
        PDFTableColumn(title: "Rasi Lord", width: 80), PDFTableColumn(title: "Nakshatra", width: 90),
        PDFTableColumn(title: "Pada", width: 40), PDFTableColumn(title: "Nakshatra Lord", width: 90),
        PDFTableColumn(title: "Karaka", width: 90),
    ]

    private static let vargaColumns: [PDFTableColumn] = [
        PDFTableColumn(title: "Planet", width: 100), PDFTableColumn(title: "Rasi", width: 100),
        PDFTableColumn(title: "Rasi Lord", width: 100), PDFTableColumn(title: "Deg. in Sign", width: 90),
        PDFTableColumn(title: "Nakshatra", width: 130), PDFTableColumn(title: "Pada", width: 50),
        PDFTableColumn(title: "Nakshatra Lord", width: 130),
    ]

    /// Same row shape as ChartTableView -- duplicated rather than shared
    /// since that view's rows are a private nested type built around its
    /// own Table-based rendering.
    private static func d1Rows(computation: ChartComputation, theme: ColorTheme) -> [PDFTableRowData] {
        func planetCell(_ label: String, retrograde: Bool, combust: Bool) -> String {
            var text = label
            if retrograde { text += " ^" }
            if combust { text += " *" }
            return text
        }

        var result: [PDFTableRowData] = [
            PDFTableRowData(id: "ascendant", cells: [
                PDFTableCell(text: "Ascendant", color: theme.keyword),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", computation.ascendant.absoluteLongitude), color: theme.number),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", computation.ascendant.absoluteLongitude.truncatingRemainder(dividingBy: 30)), color: theme.number),
                PDFTableCell(text: computation.ascendant.rasi.displayName, color: theme.string),
                PDFTableCell(text: computation.ascendant.rasi.lord.displayName, color: theme.keyword),
                PDFTableCell(text: computation.ascendant.nakshatra.displayName, color: theme.string),
                PDFTableCell(text: "\(Nakshatra.pada(forLongitude: computation.ascendant.absoluteLongitude))", color: theme.number),
                PDFTableCell(text: computation.ascendant.nakshatra.lord.displayName, color: theme.keyword),
                PDFTableCell(text: "-", color: .primary),
            ]),
        ]
        for row in computation.rows {
            result.append(PDFTableRowData(id: row.body.rawValue, cells: [
                PDFTableCell(text: planetCell(row.body.displayName, retrograde: row.isRetrograde, combust: row.isCombust), color: theme.keyword),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", row.absoluteLongitude), color: theme.number),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", row.degreeWithinSign), color: theme.number),
                PDFTableCell(text: row.rasi.displayName, color: theme.string),
                PDFTableCell(text: row.rasi.lord.displayName, color: theme.keyword),
                PDFTableCell(text: row.nakshatra.displayName, color: theme.string),
                PDFTableCell(text: "\(Nakshatra.pada(forLongitude: row.absoluteLongitude))", color: theme.number),
                PDFTableCell(text: row.nakshatra.lord.displayName, color: theme.keyword),
                PDFTableCell(text: row.karaka?.rawValue ?? "-", color: .primary),
            ]))
        }
        return result
    }

    /// Same row shape as VargaPlacementTable -- see its own doc comment
    /// for why Nakshatra/Pada here are a deliberately-computed synthetic
    /// value (scaled to the varga's own resulting position), not a
    /// textbook one.
    private static func vargaRows(computation: ChartComputation, vargaChart: VargaChart, theme: ColorTheme) -> [PDFTableRowData] {
        func nakshatra(rasi: Rasi, degreeWithinSign: Double) -> Nakshatra {
            Nakshatra.containing(longitude: Double(rasi.rawValue) * 30 + degreeWithinSign)
        }
        func pada(rasi: Rasi, degreeWithinSign: Double) -> Int {
            Nakshatra.pada(forLongitude: Double(rasi.rawValue) * 30 + degreeWithinSign)
        }
        func planetCell(_ label: String, retrograde: Bool, combust: Bool) -> String {
            var text = label
            if retrograde { text += " ^" }
            if combust { text += " *" }
            return text
        }

        let ascendantNakshatra = nakshatra(rasi: vargaChart.ascendant, degreeWithinSign: vargaChart.ascendantDegreeWithinSign)
        var result: [PDFTableRowData] = [
            PDFTableRowData(id: "ascendant", cells: [
                PDFTableCell(text: "Ascendant", color: theme.keyword),
                PDFTableCell(text: vargaChart.ascendant.displayName, color: theme.string),
                PDFTableCell(text: vargaChart.ascendant.lord.displayName, color: theme.keyword),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", vargaChart.ascendantDegreeWithinSign), color: theme.number),
                PDFTableCell(text: ascendantNakshatra.displayName, color: theme.string),
                PDFTableCell(text: "\(pada(rasi: vargaChart.ascendant, degreeWithinSign: vargaChart.ascendantDegreeWithinSign))", color: theme.number),
                PDFTableCell(text: ascendantNakshatra.lord.displayName, color: theme.keyword),
            ]),
        ]
        for d1Row in computation.rows {
            guard let vargaRasi = vargaChart.placements[d1Row.body],
                  let vargaDegree = vargaChart.degreesWithinSign[d1Row.body] else { continue }
            let bodyNakshatra = nakshatra(rasi: vargaRasi, degreeWithinSign: vargaDegree)
            result.append(PDFTableRowData(id: d1Row.body.rawValue, cells: [
                PDFTableCell(text: planetCell(d1Row.body.displayName, retrograde: d1Row.isRetrograde, combust: d1Row.isCombust), color: theme.keyword),
                PDFTableCell(text: vargaRasi.displayName, color: theme.string),
                PDFTableCell(text: vargaRasi.lord.displayName, color: theme.keyword),
                PDFTableCell(text: String(format: "%.2f\u{00B0}", vargaDegree), color: theme.number),
                PDFTableCell(text: bodyNakshatra.displayName, color: theme.string),
                PDFTableCell(text: "\(pada(rasi: vargaRasi, degreeWithinSign: vargaDegree))", color: theme.number),
                PDFTableCell(text: bodyNakshatra.lord.displayName, color: theme.keyword),
            ]))
        }
        return result
    }
}

// MARK: - Plain (non-Table) table, safe for ImageRenderer

/// SwiftUI's Table/List are AppKit-backed and virtualize their rows, which
/// ImageRenderer doesn't reliably rasterize in full (it can only capture
/// whatever's actually laid out, not off-screen virtualized rows) -- this
/// is a plain VStack/HStack grid instead, so every row is guaranteed to
/// actually render into the PDF.
private struct PDFTableColumn {
    let title: String
    let width: CGFloat
}

private struct PDFTableCell {
    let text: String
    let color: Color
}

private struct PDFTableRowData: Identifiable {
    let id: String
    let cells: [PDFTableCell]
}

private struct PDFTableView: View {
    let columns: [PDFTableColumn]
    let rows: [PDFTableRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(columns.indices, id: \.self) { index in
                    Text(columns[index].title)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: columns[index].width, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
            Divider()
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    ForEach(row.cells.indices, id: \.self) { index in
                        Text(row.cells[index].text)
                            .font(.system(size: 10))
                            .foregroundStyle(row.cells[index].color)
                            .frame(width: columns[index].width, alignment: .leading)
                    }
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
    }
}
