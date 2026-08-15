import SwiftUI
import AppKit
import DestinyEngine

/// Read-only transit scrubber: starts from a saved chart's data (name,
/// Place of Birth) and whichever chart (D1 or a specific varga) was on
/// screen when it was opened, but the displayed Date & Time can be
/// scrolled forward/backward, live-recomputing that one chart's planet
/// positions + ascendant for whatever moment is currently shown. Never
/// touches the saved chart's file -- `record` is only ever read here, and
/// `currentMoment` lives in local @State that starts equal to (and can
/// always be reset back to) record.input.birthMoment.
struct TransitExplorerView: View {
    let record: ChartRecord

    private enum Granularity: String, CaseIterable, Identifiable {
        case day = "Day", hour = "Hour", minute = "Minute", second = "Second"
        var id: String { rawValue }
        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .hour: return .hour
            case .minute: return .minute
            case .second: return .second
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    @State private var currentVarga: DivisionalChart
    @State private var currentMoment: BirthMoment
    /// Used when currentVarga == .d1 (carries retrograde/combust markers).
    @State private var d1Ascendant: ChartPoint
    @State private var d1Rows: [ChartRow]
    /// Used when currentVarga != .d1.
    @State private var vargaChart: VargaChart?
    @State private var granularity: Granularity = .day
    @State private var style: ChartRenderStyle = .northIndian
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var scrollAccumulator: CGFloat = 0
    @State private var recomputeTask: Task<Void, Never>?
    /// Monotonically increasing per requested recompute -- Task cancellation
    /// alone stops a *pending* (still-sleeping/debouncing) request, but an
    /// already-in-flight engine call keeps running to completion regardless
    /// of cancellation (Swift's cancellation is cooperative, and the engine
    /// call itself never checks for it). Comparing against this on the way
    /// back is what actually stops a slow, superseded response from
    /// clobbering a newer one that already landed.
    @State private var latestRequestID: UInt64 = 0

    init(record: ChartRecord, initialVarga: DivisionalChart = .d1) {
        self.record = record
        _currentVarga = State(initialValue: initialVarga)
        _currentMoment = State(initialValue: record.input.birthMoment)
        _d1Ascendant = State(initialValue: record.computation.ascendant)
        _d1Rows = State(initialValue: record.computation.rows)
        _vargaChart = State(initialValue: record.computation.vargas.first { $0.varga == initialVarga })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore Transits").font(.title3.bold())
                    Text(record.input.name).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            HStack(spacing: 24) {
                fieldLabel("Place of Birth (fixed)")
                Text(record.input.placeName)
                fieldLabel("Coordinates")
                Text("\(String(format: "%.4f", record.input.latitude))\u{00B0}, \(String(format: "%.4f", record.input.longitude))\u{00B0}")
                fieldLabel("Chart")
                Menu {
                    ForEach(DivisionalChart.allCases, id: \.self) { varga in
                        Button(varga.rawValue) { currentVarga = varga }
                    }
                } label: {
                    Text(currentVarga.rawValue).foregroundStyle(.primary)
                }
                .fixedSize()
            }
            .font(.caption)

            Divider()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Displayed Date & Time").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("\(momentDateDisplay)  \u{00B7}  \(momentTimeDisplay)")
                            .font(.title2.monospacedDigit())
                        if isComputing {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Granularity").font(.caption).foregroundStyle(.secondary)
                    Picker("Granularity", selection: $granularity) {
                        ForEach(Granularity.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                Button("Reset to Birth") { resetToBirth() }
                    .buttonStyle(.bordered)
                    .disabled(currentMoment == record.input.birthMoment)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Picker("Chart Style", selection: $style) {
                ForEach(ChartRenderStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .frame(maxWidth: .infinity, alignment: .center)

            Group {
                if let layout = currentLayout {
                    chartView(layout: layout)
                } else {
                    ProgressView().frame(width: 380, height: 380)
                }
            }
            .frame(width: 380, height: 380)
            .overlay(ScrollWheelCapture(onScroll: handleScroll(deltaY:)))
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Hover over the chart and scroll to move time forward/backward, one \(granularity.rawValue.lowercased()) per tick.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            chartLegendText(
                theme: theme,
                abbreviations: [("Asc", "Ascendant")],
                markers: [("*", "combust"), ("^", "Retrograde")]
            )
            .font(.caption2)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 680, height: 700)
        .background(theme.background)
        .environment(\.fontZoomMultiplier, fontZoomMultiplier)
        .onChange(of: currentVarga) { _, newVarga in
            recomputeTask?.cancel()
            latestRequestID &+= 1
            if currentMoment == record.input.birthMoment {
                seedFromNatal(varga: newVarga)
            } else {
                let requestID = latestRequestID
                let moment = currentMoment
                recomputeTask = Task { await recompute(moment, varga: newVarga, requestID: requestID) }
            }
        }
    }

    private var currentLayout: ChartLayoutData? {
        if currentVarga == .d1 {
            return ChartLayoutData(ascendant: d1Ascendant, rows: d1Rows)
        }
        guard let vargaChart else { return nil }
        return ChartLayoutData(varga: vargaChart)
    }

    @ViewBuilder
    private func chartView(layout: ChartLayoutData) -> some View {
        switch style {
        case .northIndian:
            NorthIndianChartView(layout: layout)
        case .southIndian:
            SouthIndianChartView(layout: layout)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).fontWeight(.semibold)
    }

    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    private var momentDateDisplay: String {
        let name = Self.monthNames[max(0, min(11, currentMoment.month - 1))]
        return "\(name) \(currentMoment.day), \(currentMoment.year)"
    }

    private var momentTimeDisplay: String {
        let hour12 = currentMoment.hour % 12 == 0 ? 12 : currentMoment.hour % 12
        let ampm = currentMoment.hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d:%02d %@", hour12, currentMoment.minute, Int(currentMoment.second), ampm)
    }

    /// Trackpad scroll events fire many small deltas per gesture (a mouse
    /// wheel fires fewer, larger ones) -- accumulating and only acting once
    /// the running total crosses a fixed threshold turns either input into
    /// discrete, evenly-paced ticks instead of the displayed time jumping
    /// around unpredictably.
    private func handleScroll(deltaY: CGFloat) {
        scrollAccumulator += deltaY
        let threshold: CGFloat = 8
        while abs(scrollAccumulator) >= threshold {
            let direction = scrollAccumulator > 0 ? 1 : -1
            scrollAccumulator -= CGFloat(direction) * threshold
            applyTick(direction: direction)
        }
    }

    private func applyTick(direction: Int) {
        guard let newMoment = Self.shiftedMoment(by: direction, unit: granularity.calendarComponent, from: currentMoment) else { return }
        currentMoment = newMoment
        scheduleRecompute()
    }

    private func seedFromNatal(varga: DivisionalChart) {
        if varga == .d1 {
            d1Ascendant = record.computation.ascendant
            d1Rows = record.computation.rows
        } else {
            vargaChart = record.computation.vargas.first { $0.varga == varga }
        }
        errorMessage = nil
        isComputing = false
    }

    private func resetToBirth() {
        recomputeTask?.cancel()
        latestRequestID &+= 1
        scrollAccumulator = 0
        currentMoment = record.input.birthMoment
        seedFromNatal(varga: currentVarga)
    }

    /// Debounced: every new tick cancels whatever recompute was pending
    /// and restarts the pause timer, so rapid scrolling only triggers an
    /// actual engine call once the user pauses briefly, not on every tick.
    /// The captured requestID is what actually protects against a stale
    /// response landing late -- see recompute's doc comment.
    private func scheduleRecompute() {
        recomputeTask?.cancel()
        latestRequestID &+= 1
        let requestID = latestRequestID
        let momentToCompute = currentMoment
        let varga = currentVarga
        recomputeTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, requestID == latestRequestID else { return }
            await recompute(momentToCompute, varga: varga, requestID: requestID)
        }
    }

    /// `requestID` must still equal `latestRequestID` at the exact moment
    /// a result is about to be applied, checked again after each await --
    /// not just relying on Task.isCancelled, since cancelling a Task
    /// doesn't abort an engine call already in flight (it runs to
    /// completion regardless) and could otherwise still land after a
    /// faster, newer request already updated the screen.
    @MainActor
    private func recompute(_ moment: BirthMoment, varga: DivisionalChart, requestID: UInt64) async {
        isComputing = true
        do {
            if varga == .d1 {
                let snapshot = try await ChartCalculator.computeD1Snapshot(
                    birthMoment: moment, latitude: record.input.latitude, longitude: record.input.longitude
                )
                guard requestID == latestRequestID else { return }
                d1Ascendant = snapshot.ascendant
                d1Rows = snapshot.rows
            } else {
                let snapshot = try await ChartCalculator.computeVargaSnapshot(
                    varga: varga, birthMoment: moment, latitude: record.input.latitude, longitude: record.input.longitude
                )
                guard requestID == latestRequestID else { return }
                vargaChart = snapshot
            }
            errorMessage = nil
        } catch {
            guard requestID == latestRequestID else { return }
            errorMessage = "Couldn't compute positions for this moment -- it may be outside the ephemeris's supported date range."
        }
        if requestID == latestRequestID {
            isComputing = false
        }
    }

    /// Adds `amount` of `unit` to `moment` in its own birth-local time
    /// zone (not the app's system time zone), so a "day" tick always means
    /// one calendar day at the birth location -- correctly handling that
    /// location's own DST transitions -- rather than an ambiguous 24-hour
    /// jump in some other zone.
    private static func shiftedMoment(by amount: Int, unit: Calendar.Component, from moment: BirthMoment) -> BirthMoment? {
        guard let baseDate = try? moment.resolvedUTCDate() else { return nil }
        let timeZone: TimeZone
        if let manualOffset = moment.manualUTCOffsetSeconds, let fixed = TimeZone(secondsFromGMT: manualOffset) {
            timeZone = fixed
        } else if let resolved = TimeZone(identifier: moment.timeZoneIdentifier) {
            timeZone = resolved
        } else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let newDate = calendar.date(byAdding: unit, value: amount, to: baseDate) else { return nil }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: newDate)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let hour = comps.hour, let minute = comps.minute else { return nil }

        return BirthMoment(
            year: year, month: month, day: day, hour: hour, minute: minute,
            second: Double(comps.second ?? 0),
            timeZoneIdentifier: moment.timeZoneIdentifier, manualUTCOffsetSeconds: moment.manualUTCOffsetSeconds
        )
    }
}

/// SwiftUI has no built-in "scroll over an arbitrary view" gesture on
/// macOS -- ScrollView is for actual scrollable content, not this. Wraps a
/// plain NSView that forwards raw scrollWheel deltas; AppKit already
/// routes scroll events to whichever view sits under the cursor, so no
/// separate hover-tracking is needed.
private struct ScrollWheelCapture: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }
}

private final class ScrollCaptureView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }
}
