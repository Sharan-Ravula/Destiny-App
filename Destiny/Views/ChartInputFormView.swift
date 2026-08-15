import SwiftUI
import SwiftData
import AppKit
import DestinyEngine

struct ChartInputFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil means creating a brand-new chart; non-nil means editing this
    /// chart in place (same id preserved on save).
    private let existingRecord: ChartRecord?
    var onSaved: ((ChartRecord) -> Void)?

    @State private var name: String
    @State private var placeQuery: String
    @State private var placeSearchResults: [PlaceSearchResult] = []
    @State private var selectedPlace: PlaceSearchResult?
    /// The only source of truth for where this chart's coordinates/timezone
    /// come from -- set by selecting a search result, or carried over
    /// unchanged from the existing record when editing without re-searching.
    /// There's no manual lat/long/timezone entry in this form anymore (per
    /// user request); that data is shown read-only on the chart itself
    /// after creation instead.
    @State private var resolvedLatitude: Double?
    @State private var resolvedLongitude: Double?
    @State private var timeZoneIdentifier: String
    @State private var gender: Gender
    @State private var birthYear: Int
    @State private var birthMonth: Int // 1-12
    @State private var birthDay: Int // 1-31, clamped to the selected month
    @State private var hour12: Int // 1-12
    @State private var minute: Int // 0-59
    @State private var isPM: Bool

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(existingRecord: ChartRecord? = nil, onSaved: ((ChartRecord) -> Void)? = nil) {
        self.existingRecord = existingRecord
        self.onSaved = onSaved

        let input = existingRecord?.input
        _name = State(initialValue: input?.name ?? "")
        _placeQuery = State(initialValue: input?.placeName ?? "")
        _resolvedLatitude = State(initialValue: input?.latitude)
        _resolvedLongitude = State(initialValue: input?.longitude)
        _timeZoneIdentifier = State(initialValue: input?.birthMoment.timeZoneIdentifier ?? TimeZone.current.identifier)
        _gender = State(initialValue: input?.gender ?? .other)

        let calendar = Calendar(identifier: .gregorian)
        if let moment = input?.birthMoment {
            _birthYear = State(initialValue: moment.year)
            _birthMonth = State(initialValue: moment.month)
            _birthDay = State(initialValue: moment.day)

            let hour24 = moment.hour
            _isPM = State(initialValue: hour24 >= 12)
            let h12 = hour24 % 12
            _hour12 = State(initialValue: h12 == 0 ? 12 : h12)
            _minute = State(initialValue: moment.minute)
        } else {
            let now = Date()
            let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            _birthYear = State(initialValue: nowComponents.year ?? 2000)
            _birthMonth = State(initialValue: nowComponents.month ?? 1)
            _birthDay = State(initialValue: nowComponents.day ?? 1)

            let hour24 = nowComponents.hour ?? 12
            _isPM = State(initialValue: hour24 >= 12)
            let h12 = hour24 % 12
            _hour12 = State(initialValue: h12 == 0 ? 12 : h12)
            _minute = State(initialValue: nowComponents.minute ?? 0)
        }
    }

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    private var daysInSelectedMonth: Int {
        var components = DateComponents()
        components.year = birthYear
        components.month = birthMonth
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components), let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    /// Every row below uses this same fixed-width, trailing-aligned label
    /// column instead of Form's automatic per-row label alignment -- that
    /// auto-alignment repeatedly broke (twice, in two different ways) once
    /// a row's trailing content was a multi-control HStack wider than a
    /// plain TextField/Picker's. A fixed width shared by every row can't
    /// drift the way an automatically-negotiated one did.
    private static let labelWidth: CGFloat = 130

    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: Self.labelWidth, alignment: .trailing)
            content()
        }
    }

    var body: some View {
        // A sheet sizes itself to its content's ideal size, so `minHeight` +
        // `Spacer()`s never had any slack to distribute -- the sheet just
        // shrank to fit the Form exactly. A genuinely fixed frame (taller
        // than the Form needs) gives the Spacers real room to center within.
        VStack {
            Spacer(minLength: 0)
            formContent
            Spacer(minLength: 0)
        }
        .padding()
        .frame(width: 480, height: 600)
    }

    private var formContent: some View {
        Form {
            Text(existingRecord != nil ? "Edit Chart" : "New Chart")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            row("Name") {
                TextField("", text: $name)
                    .labelsHidden()
            }

            row("Date of birth") {
                HStack {
                    Picker("", selection: $birthMonth) {
                        ForEach(1...12, id: \.self) { m in Text(Self.monthNames[m - 1]).tag(m) }
                    }
                    .labelsHidden()
                    .frame(width: 115)
                    .onChange(of: birthMonth) { _, _ in
                        birthDay = min(birthDay, daysInSelectedMonth)
                    }
                    Picker("", selection: $birthDay) {
                        ForEach(1...daysInSelectedMonth, id: \.self) { d in Text("\(d)").tag(d) }
                    }
                    .labelsHidden()
                    .frame(width: 55)
                    TextField("", value: $birthYear, format: .number.grouping(.never))
                        .labelsHidden()
                        .frame(width: 70)
                        .onChange(of: birthYear) { _, _ in
                            birthDay = min(birthDay, daysInSelectedMonth)
                        }
                }
            }

            row("Time of birth") {
                HStack {
                    Picker("", selection: $hour12) {
                        ForEach(1...12, id: \.self) { h in Text("\(h)").tag(h) }
                    }
                    .labelsHidden()
                    .frame(width: 55)
                    Text(":")
                    Picker("", selection: $minute) {
                        ForEach(0..<60, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                    }
                    .labelsHidden()
                    .frame(width: 55)
                    Picker("", selection: $isPM) {
                        Text("AM").tag(false)
                        Text("PM").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }

            row("Gender") {
                Picker("", selection: $gender) {
                    ForEach(Gender.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            row("Place of birth") {
                TextField("", text: $placeQuery)
                    .labelsHidden()
                    .onChange(of: placeQuery) { _, newValue in
                        selectedPlace = nil
                        placeSearchResults = PlaceLookup.shared.search(prefix: newValue)
                    }
            }

            if !placeSearchResults.isEmpty {
                ForEach(placeSearchResults) { result in
                    Button {
                        select(result)
                    } label: {
                        HStack {
                            Spacer().frame(width: Self.labelWidth)
                            Text(result.displayName)
                            Spacer()
                            Text(result.timezoneIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedPlace {
                HStack {
                    Spacer().frame(width: Self.labelWidth)
                    Label("Selected: \(selectedPlace.displayName)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            } else if resolvedLatitude != nil {
                HStack {
                    Spacer().frame(width: Self.labelWidth)
                    Label("Using existing location for \(placeQuery)", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            HStack {
                Spacer().frame(width: Self.labelWidth)
                Button(isSaving ? "Calculating..." : (existingRecord != nil ? "Save Changes" : "Save Chart")) {
                    save()
                }
                .disabled(isSaving || name.isEmpty || resolvedLatitude == nil || resolvedLongitude == nil)
            }
        }
    }

    private func select(_ result: PlaceSearchResult) {
        selectedPlace = result
        placeQuery = result.displayName
        placeSearchResults = []
        resolvedLatitude = result.latitude
        resolvedLongitude = result.longitude
        timeZoneIdentifier = result.timezoneIdentifier
    }

    private func save() {
        guard let latitude = resolvedLatitude, let longitude = resolvedLongitude else {
            errorMessage = "Please search for and select a place of birth."
            return
        }

        // 12-hour -> 24-hour: 12 AM is hour 0, 12 PM is hour 12.
        let hour = isPM ? (hour12 == 12 ? 12 : hour12 + 12) : (hour12 == 12 ? 0 : hour12)

        let birthMoment = BirthMoment(
            year: birthYear, month: birthMonth, day: birthDay, hour: hour, minute: minute,
            timeZoneIdentifier: timeZoneIdentifier
        )

        // Only new charts prompt for a save location -- editing an existing
        // chart keeps saving to wherever it already lives (ChartStore.save
        // ignores `directory` when updating).
        var saveDirectory: URL?
        if existingRecord == nil {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Choose where to save this chart"
            panel.prompt = "Save Here"
            panel.directoryURL = ChartStore.defaultChartsDirectory

            guard panel.runModal() == .OK, let chosenURL = panel.url else {
                return // user cancelled -- don't compute or save anything
            }
            saveDirectory = chosenURL
        }

        isSaving = true
        errorMessage = nil
        Task {
            do {
                let computation = try await ChartCalculator.computeChart(
                    birthMoment: birthMoment, latitude: latitude, longitude: longitude
                )
                let input = ChartInput(
                    name: name, placeName: selectedPlace?.displayName ?? placeQuery,
                    latitude: latitude, longitude: longitude,
                    birthMoment: birthMoment, gender: gender
                )
                let record = ChartRecord(
                    id: existingRecord?.id ?? UUID(),
                    engineVersion: ChartCalculator.engineVersion,
                    input: input,
                    computation: computation
                )
                try ChartStore.save(record, in: modelContext, directory: saveDirectory)
                await MainActor.run {
                    isSaving = false
                    onSaved?(record)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to compute/save chart: \(error)"
                }
            }
        }
    }
}
