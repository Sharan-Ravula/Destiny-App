import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import DestinyEngine

private struct FormTarget: Identifiable {
    let id = UUID()
    let existingRecord: ChartRecord?
}

struct SavedChartsListView: View {
    @Query(sort: \ChartIndexEntry.name) private var entries: [ChartIndexEntry]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @AppStorage("fontZoomStep") private var fontZoomStep: Int = 0
    @State private var formTarget: FormTarget?
    @State private var showingAbout = false
    @State private var loadedRecord: ChartRecord?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    /// Matches name, place, or the formatted date-of-birth/time-of-birth
    /// string (e.g. "Aug 24, 2002" or "9:40 AM" both match, since
    /// birthDisplay already combines both into one string) -- client-side
    /// filtering over the already-loaded @Query results rather than a
    /// SwiftData predicate, since there's no single field to match a
    /// free-text query against and the saved-chart count is always small.
    private var filteredEntries: [ChartIndexEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query)
                || entry.placeName.localizedCaseInsensitiveContains(query)
                || birthDisplay(for: entry).localizedCaseInsensitiveContains(query)
        }
    }
    private var fontZoomStepLabel: String {
        switch fontZoomStep {
        case -3: return "Small"
        case 3: return "Large"
        default: return "Normal"
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        formTarget = FormTarget(existingRecord: nil)
                    } label: {
                        Label("New Chart", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        importChart()
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding()

                List(filteredEntries) { entry in
                    Button {
                        load(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.name).font(.headline)
                            Text(entry.placeName).font(.caption).foregroundStyle(.secondary)
                            Text(birthDisplay(for: entry)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            edit(entry)
                        }
                        Button("Show in Finder") {
                            showInFinder(entry)
                        }
                        Button("Delete", role: .destructive) {
                            delete(entry)
                        }
                    }
                }
                // Themed background needs .scrollContentBackground(.hidden)
                // first -- otherwise List keeps its native fill underneath
                // whatever's set via .background. alternatingRowBackgrounds
                // disables AppKit's own native per-row stripe, which would
                // otherwise still show through regardless of the palette.
                .alternatingRowBackgrounds(.disabled)
                .scrollContentBackground(.hidden)
                .background(theme.secondaryBackground)
                .overlay {
                    if filteredEntries.isEmpty && !searchText.isEmpty {
                        Text("No charts match \u{201C}\(searchText)\u{201D}")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }

                Divider()

                // Plain dropdown boxes in the sidebar itself, not toolbar
                // items -- the toolbar collapsed them behind a "»" overflow
                // chevron (with an extra submenu arrow to open each one) once
                // there wasn't room for every item, which wasn't discoverable.
                VStack(alignment: .leading, spacing: 10) {
                    // Menu (not Picker) here on purpose: a menu-style
                    // Picker draws its selected-value text via the
                    // underlying NSPopUpButton's own title, which ignores
                    // .foregroundStyle and (under a forced light/dark
                    // appearance mismatch with the system's actual one)
                    // can render at near-invisible contrast against our
                    // flat custom background. Menu's label is plain
                    // SwiftUI content, so an explicit color always wins.
                    LabeledContent("Themes") {
                        Menu {
                            ForEach(ColorTheme.all) { candidate in
                                Button(candidate.name) { colorThemeID = candidate.id }
                            }
                        } label: {
                            Text(theme.name).foregroundStyle(.primary)
                        }
                        .fixedSize()
                    }
                    LabeledContent("Font Size") {
                        Menu {
                            Button("Small") { fontZoomStep = -3 }
                            Button("Normal") { fontZoomStep = 0 }
                            Button("Large") { fontZoomStep = 3 }
                        } label: {
                            Text(fontZoomStepLabel).foregroundStyle(.primary)
                        }
                        .fixedSize()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.secondaryBackground)
            }
            .navigationTitle("Saved Charts")
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search name, place, date, or time")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .sheet(item: $formTarget) { target in
                ChartInputFormView(existingRecord: target.existingRecord) { record in
                    loadedRecord = record
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .importChartRequested)) { _ in
                importChart()
            }
            .task {
                repairLegacyTimeZonesIfNeeded()
            }
        } detail: {
            if let loadedRecord {
                ChartDetailView(record: loadedRecord)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            } else {
                Text("Select or create a chart").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            }
        }
    }

    /// dateOfBirth is stored as an absolute UTC instant -- reformatted
    /// using the chart's own birth time zone (not the machine's local one)
    /// so this reads back as the original wall-clock date/time of birth.
    private func birthDisplay(for entry: ChartIndexEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy \u{00B7} h:mm a"
        formatter.timeZone = TimeZone(identifier: entry.timeZoneIdentifier) ?? TimeZone(identifier: "UTC")
        return formatter.string(from: entry.dateOfBirth)
    }

    /// Entries saved before timeZoneIdentifier existed have it as either ""
    /// (the current lightweight-migration default) or "UTC" (an earlier
    /// build's default, already physically written to disk for existing
    /// rows before this fix -- so "" alone isn't enough to catch them).
    /// Either way this displays DOB times reformatted as if they were UTC,
    /// which is wrong for anyone not actually born in that zone. One-time
    /// per-entry repair by reading each affected chart's own JSON file
    /// (cheap -- loadFile skips the full chart recompute -- and there are
    /// only ever a handful of legacy entries, not a cost paid every launch
    /// going forward).
    private func repairLegacyTimeZonesIfNeeded() {
        var didRepair = false
        for entry in entries where entry.timeZoneIdentifier.isEmpty || entry.timeZoneIdentifier == "UTC" {
            guard let file = try? ChartStore.loadFile(from: entry) else { continue }
            entry.timeZoneIdentifier = file.input.birthMoment.timeZoneIdentifier
            didRepair = true
        }
        if didRepair {
            try? modelContext.save()
        }
    }

    private func load(_ entry: ChartIndexEntry) {
        Task {
            do {
                let record = try await ChartStore.load(from: entry)
                loadedRecord = record
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load chart: \(error)"
            }
        }
    }

    private func edit(_ entry: ChartIndexEntry) {
        Task {
            do {
                let record = try await ChartStore.load(from: entry)
                formTarget = FormTarget(existingRecord: record)
            } catch {
                errorMessage = "Failed to load chart for editing: \(error)"
            }
        }
    }

    /// Lets the user pick a chart .json file from anywhere on disk (not
    /// just the app's own Charts folder -- e.g. one shared from outside
    /// the app), decodes it, recomputes its chart, and registers it into
    /// the saved-charts list. Re-importing a file whose id already exists
    /// just refreshes that chart in place (same overwrite behavior as
    /// ChartStore.save's normal update path), rather than creating a
    /// duplicate.
    private func importChart() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Destiny chart JSON file to import"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let file = try decoder.decode(ChartFile.self, from: data)
                let computation = try await ChartCalculator.computeChart(
                    birthMoment: file.input.birthMoment, latitude: file.input.latitude, longitude: file.input.longitude
                )
                let record = ChartRecord(
                    id: file.id ?? UUID(), engineVersion: file.engineVersion ?? ChartCalculator.engineVersion,
                    input: file.input, computation: computation
                )
                try ChartStore.save(record, in: modelContext)
                loadedRecord = record
                errorMessage = nil
            } catch {
                errorMessage = "Failed to import chart: \(error)"
            }
        }
    }

    private func showInFinder(_ entry: ChartIndexEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([ChartStore.fileURL(for: entry)])
    }

    private func delete(_ entry: ChartIndexEntry) {
        try? ChartStore.delete(id: entry.id, in: modelContext)
        if loadedRecord?.id == entry.id {
            loadedRecord = nil
        }
    }
}
