import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DestinyEngine

/// Sheet presented from ChartDetailView's "Export PDF" button -- lets the
/// user pick chart style(s) and which chart(s) (D1 + any subset of the
/// divisional charts) to include before generating the actual file via
/// ChartPDFExporter.
struct PDFExportOptionsView: View {
    let record: ChartRecord
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    @State private var styleOption: PDFChartStyleOption = .northIndian
    @State private var selectedCharts: Set<DivisionalChart> = [.d1]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export PDF").font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Chart Style").font(.headline)
                Picker("Chart Style", selection: $styleOption) {
                    ForEach(PDFChartStyleOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Charts to Include").font(.headline)
                    Spacer()
                    Button("All") { selectedCharts = Set(DivisionalChart.allCases) }
                        .buttonStyle(.plain)
                        .font(.caption)
                    Button("None") { selectedCharts = [] }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(DivisionalChart.allCases, id: \.self) { chart in
                            Toggle(chart.rawValue, isOn: chartBinding(chart))
                                .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 160)
                .background(theme.secondaryBackground)
            }

            // Doshas/Karakamsa/Arudha Padas/Chara Karakas are always
            // included once regardless of chart selection (they're D1-only
            // concepts, not tied to whether D1's diagram itself is picked)
            // -- see ChartPDFExporter's own doc comment.
            Text("The exported PDF always includes birth details and D1-only reference data (doshas, Karakamsa, Arudha Padas, Chara Karakas) on a cover page, plus a diagram and planetary positions table for each chart selected above. Conjunctions, aspects, house lordships, and the dasha tables are left out to keep the file compact.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Export\u{2026}") { exportTapped() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCharts.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(theme.background)
    }

    private func chartBinding(_ chart: DivisionalChart) -> Binding<Bool> {
        Binding(
            get: { selectedCharts.contains(chart) },
            set: { isOn in
                if isOn { selectedCharts.insert(chart) } else { selectedCharts.remove(chart) }
            }
        )
    }

    private func exportTapped() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(record.input.name) Chart.pdf"
        panel.message = "Choose where to save the exported chart PDF"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // DivisionalChart.allCases is already in D1..D60 ascending order --
        // filtering it (rather than iterating the Set directly) keeps the
        // exported page order predictable regardless of selection order.
        let charts = DivisionalChart.allCases.filter { selectedCharts.contains($0) }
        do {
            try ChartPDFExporter.export(record: record, charts: charts, styleOption: styleOption, to: url)
            dismiss()
        } catch {
            errorMessage = "Failed to export PDF: \(error)"
        }
    }
}
