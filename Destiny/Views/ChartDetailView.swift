import SwiftUI
import DestinyEngine

struct ChartDetailView: View {
    let record: ChartRecord

    private enum Section: String, CaseIterable, Identifiable {
        case charts = "Charts"
        case vimshottari = "Vimshottari Dasha"
        case chara = "Chara Dasha"
        var id: String { rawValue }
    }

    @State private var section: Section = .charts
    /// D1 by default -- D1 and every divisional chart share one page/one
    /// picker now (DivisionalChartsView), rather than D1 having its own
    /// separate page.
    @State private var selectedVarga: DivisionalChart = .d1
    @State private var showingTransitExplorer = false
    @State private var showingPDFExport = false

    /// Whatever chart is currently selected in DivisionalChartsView's own
    /// picker -- so "Explore Transits" opens already showing that chart.
    private var transitExplorerInitialVarga: DivisionalChart { selectedVarga }
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
                            case .charts:
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
        .sheet(isPresented: $showingPDFExport) {
            PDFExportOptionsView(record: record)
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
            HStack(spacing: 8) {
                Button {
                    showingPDFExport = true
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    showingTransitExplorer = true
                } label: {
                    Label("Explore Transits", systemImage: "clock.arrow.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)
    }
}
