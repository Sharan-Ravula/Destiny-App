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
    /// Picked once when this view is first created (i.e. once per app
    /// launch), not re-randomized on every redraw -- a continuously
    /// animating/cycling title gradient would need a repeating animation
    /// loop, forcing the window to keep redrawing for as long as it's
    /// open, which is a real (if small) ongoing CPU/GPU cost. A gradient
    /// that's simply chosen once and then static costs nothing beyond a
    /// normal text render.
    @State private var titleHue = Double.random(in: 0...1)

    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: titleHue, saturation: 0.7, brightness: 0.95),
                Color(hue: (titleHue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.95),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    /// Matches name, place, gender, or the formatted date-of-birth/time-of-
    /// birth string (e.g. "Aug 24, 2002" or "9:40 AM" both match, since
    /// birthDisplay already combines both into one string) -- client-side
    /// filtering over the already-loaded @Query results rather than a
    /// SwiftData predicate, since there's no single field to match a
    /// free-text query against and the saved-chart count is always small.
    ///
    /// Gender uses an anchored (start-of-string) match rather than plain
    /// contains -- "Male" is literally a substring of "Female", so a plain
    /// .localizedCaseInsensitiveContains("male") would wrongly match both.
    private var filteredEntries: [ChartIndexEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query)
                || entry.placeName.localizedCaseInsensitiveContains(query)
                || birthDisplay(for: entry).localizedCaseInsensitiveContains(query)
                || entry.gender.range(of: query, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    @ViewBuilder
    private func fontSizeButton(_ label: String, step: Int) -> some View {
        Button {
            fontZoomStep = step
        } label: {
            if fontZoomStep == step {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(filteredEntries) { entry in
                    Button {
                        load(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.name).font(.headline)
                            Text(entry.placeName).font(.caption).foregroundStyle(.secondary)
                            Text(birthDisplay(for: entry)).font(.caption).foregroundStyle(.secondary)
                            if !entry.gender.isEmpty {
                                Text(entry.gender).font(.caption).foregroundStyle(.secondary)
                            }
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
                    // These rows are a custom Button (not List's built-in
                    // selection binding, since a Button lets each row also
                    // carry its own contextMenu) -- so there's no selection
                    // highlight for free. listRowBackground on the whole
                    // row (not .background on the label content) so the
                    // highlight fills the row's full width/insets, not
                    // just wherever the text happens to sit.
                    .listRowBackground(entry.id == loadedRecord?.id ? theme.accent.opacity(0.18) : Color.clear)
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
            }
            .navigationTitle("Saved Charts")
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search name, place, date, time, or gender")
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
            .onReceive(NotificationCenter.default.publisher(for: .aboutRequested)) { _ in
                showingAbout = true
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
        // Attached to the NavigationSplitView itself, not the sidebar
        // column's own view -- scoping it to the sidebar meant these items
        // could vanish or get shuffled into the "»" overflow chevron
        // whenever the sidebar was collapsed/reopened, since SwiftUI
        // rebuilds that column's toolbar items on each visibility change.
        // A window-level toolbar isn't tied to that lifecycle.
        .toolbar {
            // .sharedBackgroundVisibility(.hidden) on each item -- without
            // it, macOS's toolbar automatically merges adjacent icon
            // buttons into one shared pill/capsule background, which read
            // as a single segmented control instead of separate buttons.
            ToolbarItem {
                Button {
                    formTarget = FormTarget(existingRecord: nil)
                } label: {
                    Label("New Chart", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem {
                Button {
                    importChart()
                } label: {
                    Label("Open", systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
            }
            .sharedBackgroundVisibility(.hidden)
            // Theme and Font Size as 2 separate icon-only buttons (no text
            // label on either -- a palette/text-size icon is self-
            // explanatory) rather than one combined menu.
            ToolbarItem {
                Menu {
                    ForEach(ColorTheme.all) { candidate in
                        Button {
                            colorThemeID = candidate.id
                        } label: {
                            if candidate.id == colorThemeID {
                                Label(candidate.name, systemImage: "checkmark")
                            } else {
                                Text(candidate.name)
                            }
                        }
                    }
                } label: {
                    Label("Theme", systemImage: "paintpalette")
                }
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem {
                Menu {
                    fontSizeButton("Small", step: -3)
                    fontSizeButton("Normal", step: 0)
                    fontSizeButton("Large", step: 3)
                } label: {
                    Label("Font Size", systemImage: "textformat.size")
                }
            }
            .sharedBackgroundVisibility(.hidden)
            // .principal is the toolbar's centered slot -- this replaces
            // the plain default window title text with the gradient
            // version instead of just adding another item alongside it.
            ToolbarItem(placement: .principal) {
                Text("Destiny")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(titleGradient)
            }
            .sharedBackgroundVisibility(.hidden)
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
    /// which is wrong for anyone not actually born in that zone.
    ///
    /// Entries saved before `gender` existed on the index similarly have it
    /// as "" -- backfilled here too, from the same file read, so existing
    /// charts become gender-searchable/-displayed without needing to be
    /// manually re-saved. Unlike the timezone case this isn't strictly
    /// one-time: a chart whose gender is genuinely unset stays "" and gets
    /// re-checked on every launch, but that's a handful of cheap file reads
    /// (loadFile skips the full chart recompute) for a personal chart list,
    /// not a real cost.
    private func repairLegacyTimeZonesIfNeeded() {
        var didRepair = false
        for entry in entries where entry.timeZoneIdentifier.isEmpty || entry.timeZoneIdentifier == "UTC" || entry.gender.isEmpty {
            guard let file = try? ChartStore.loadFile(from: entry) else { continue }
            entry.timeZoneIdentifier = file.input.birthMoment.timeZoneIdentifier
            if let gender = file.input.gender {
                entry.gender = gender.rawValue
            }
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

    /// Lets the user pick one or more chart .json files from anywhere on
    /// disk (not just the app's own Charts folder -- e.g. shared from
    /// outside the app), decodes each, recomputes its chart, and registers
    /// it into the saved-charts list -- every imported file shows up in
    /// the sidebar via the @Query-backed entries list, not just the last
    /// one. Re-importing a file whose id already exists just refreshes
    /// that chart in place (same overwrite behavior as ChartStore.save's
    /// normal update path), rather than creating a duplicate. One file
    /// failing to import doesn't stop the rest -- failures are collected
    /// and reported together at the end.
    private func importChart() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose Destiny chart JSON file(s) to import"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let urls = panel.urls

        Task {
            var lastRecord: ChartRecord?
            var failures: [String] = []
            for url in urls {
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
                    lastRecord = record
                } catch {
                    failures.append("\(url.lastPathComponent): \(error)")
                }
            }
            // Opens whichever file was imported last, matching the old
            // single-file behavior of jumping straight to the imported
            // chart -- the rest are just a click away in the sidebar.
            if let lastRecord {
                loadedRecord = lastRecord
            }
            errorMessage = failures.isEmpty ? nil : "Failed to import \(failures.count) file(s):\n\(failures.joined(separator: "\n"))"
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
