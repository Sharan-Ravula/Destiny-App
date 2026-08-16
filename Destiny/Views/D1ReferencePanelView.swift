import SwiftUI
import DestinyEngine

/// D1-only reference data that doesn't extend to other vargas (see
/// VargaAnalysis's doc comment for why): doshas, Arudha/Upapada Lagna,
/// Karakamsa, and the 7 Chara Karakas. Shown only when D1 is selected on
/// the Charts page (DivisionalChartsView) -- there is no standalone
/// Summary tab anymore.
struct D1ReferencePanelView: View {
    let computation: ChartComputation
    /// Set only by ChartPDFExporter, to force a light/print-friendly theme
    /// regardless of the live app theme -- nil (the default) uses whatever
    /// colorTheme is currently selected, as before.
    var overrideTheme: ColorTheme?
    private var summary: ChartSummary { computation.summary }
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { overrideTheme ?? ColorTheme.theme(forID: colorThemeID) }

    /// Literal point sizes (not .caption/.subheadline) so this scales with
    /// the app's Cmd +/- text zoom -- matches AnalysisPanelView's sizing.
    private var bodyFont: Font { .system(size: 10 * fontZoomMultiplier) }
    private var smallFont: Font { .system(size: 9 * fontZoomMultiplier) }
    private var headerFont: Font { .system(size: 12 * fontZoomMultiplier, weight: .bold) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            doshaSection
            jaiminiSection
            arudhaPadasSection
            karakasSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyText(_ body: CelestialBody) -> Text {
        Text(body.displayName).foregroundStyle(theme.keyword)
    }

    private func rasiText(_ rasi: Rasi) -> Text {
        Text(rasi.displayName).foregroundStyle(theme.string)
    }

    private var doshaSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Doshas").font(headerFont)
            doshaRow("Mangal Dosha", present: summary.mangalDosha.isPresent, detail: mangalDoshaDetail)
            doshaRow("Sarpa Dosha", present: summary.sarpaDosha.isPresent, detail: sarpaDoshaDetail)
        }
    }

    private var sarpaDoshaDetail: String? {
        guard summary.sarpaDosha.isPresent else { return nil }
        return summary.sarpaDosha.triggeringBodies.map(\.displayName).joined(separator: ", ")
    }

    private var mangalDoshaDetail: String? {
        guard summary.mangalDosha.isPresent else { return nil }
        return "Asc, \(ordinal(summary.mangalDosha.house)) house Mars"
    }

    /// "1st"/"2nd"/"3rd"/"4th" etc. -- only houses 1,2,4,7,8,12 are ever
    /// passed in (the afflicted set Mangal Dosha checks), so the 11-13
    /// "th" exception only ever actually matters for 12.
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11, _), (12, _), (13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// One concatenated Text (not separate Text views in the HStack) for
    /// the name+detail, with .fixedSize -- a dosha with several triggering
    /// bodies (e.g. "Sarpa Dosha (Venus, Saturn, Rahu)") needs to wrap
    /// onto a second line in a narrow panel rather than silently
    /// truncating, which plain sibling Text views in an HStack don't do
    /// reliably on their own (see AnalysisPanelView's rows for the same
    /// pattern).
    private func doshaRow(_ name: String, present: Bool, detail: String?) -> some View {
        let nameText = Text(name).foregroundStyle(theme.keyword)
        let text = detail.map { Text("\(nameText) (\($0))").foregroundStyle(.secondary) } ?? nameText
        return HStack(alignment: .top, spacing: 4) {
            Image(systemName: present ? "checkmark.circle.fill" : "circle")
                .font(smallFont)
                .foregroundStyle(present ? .orange : .secondary)
            text
                .font(bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var jaiminiSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Jaimini").font(headerFont)
            if let karakamsa = summary.karakamsa {
                Text("Karakamsa: \(rasiText(karakamsa))").font(bodyFont)
            }
        }
    }

    /// All 12 Arudha Padas (A1-A12) -- A1 is Arudha Lagna, A12 is Upapada
    /// Lagna, both already badged on the chart diagrams ("Ar"/"Up"); the
    /// rest (A2-A11) are the same BhavaArudha algorithm applied to every
    /// other house. 2-column grid since 12 single lines would be a lot of
    /// vertical space for what's normally read as a quick reference list.
    private var arudhaPadasSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Arudha Padas").font(headerFont)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 2) {
                ForEach(1...12, id: \.self) { house in
                    Text("A\(house) \(rasiText(summary.arudhaPadas[house - 1]))").font(bodyFont)
                }
            }
        }
    }

    private var karakaAssignments: [KarakaRole: CelestialBody] {
        var result: [KarakaRole: CelestialBody] = [:]
        for row in computation.rows {
            if let karaka = row.karaka {
                result[karaka] = row.body
            }
        }
        return result
    }

    private static let karakaOrder: [KarakaRole] = [
        .atmaKaraka, .amatyaKaraka, .bhratriKaraka, .matriKaraka, .putraKaraka, .gnatiKaraka, .daraKaraka,
    ]

    private var karakasSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chara Karakas").font(headerFont)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 2) {
                ForEach(Self.karakaOrder, id: \.self) { role in
                    if let body = karakaAssignments[role] {
                        Text("\(role.rawValue) \(bodyText(body))").font(bodyFont)
                    }
                }
            }
        }
    }
}
