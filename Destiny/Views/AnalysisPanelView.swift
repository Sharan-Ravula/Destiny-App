import SwiftUI
import DestinyEngine

/// The 4 "mechanical" (purely sign-position) analysis categories -- shared
/// between the D1 Chart page and the Divisional Charts page, since
/// VargaAnalysis is computed identically for D1 and every other varga.
/// `placements` is needed alongside `analysis` just to label which
/// planets occupy each rasi in the Rashi Drishti section (VargaAnalysis
/// itself doesn't carry placements). `title` is shown as a header when
/// more than one of these appears on the same page (e.g. D1 and D9 side
/// by side) so it's clear which chart each panel describes.
struct AnalysisPanelView: View {
    /// Which of the 4 sections to show -- lets a caller split them across
    /// two side-by-side panels (e.g. the Divisional Charts page, which
    /// otherwise wasted its whole left side as an empty balancing spacer)
    /// instead of always showing all 4 together. Grouped as "the two
    /// aspect/drishti categories" (rashi + graha) vs. "the two placement-
    /// fact categories" (conjunctions + lordships), rather than pairing
    /// them in on-screen order.
    enum SectionGroup: Equatable {
        case all
        case rashiAndGrahaDrishti
        case conjunctionsAndLordships
        /// D1 Chart page: everything except House Lordships, which moves
        /// to join D1ReferencePanelView on the other side instead.
        case exceptHouseLordships
        case houseLordshipsOnly
    }

    let analysis: VargaAnalysis
    let placements: [CelestialBody: Rasi]
    var title: String? = nil
    var sections: SectionGroup = .all
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @Environment(\.fontZoomMultiplier) private var fontZoomMultiplier
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    // All expanded by default -- collapsing is an explicit per-section
    // choice, not something that should hide data the first time this
    // panel appears.
    @State private var conjunctionsExpanded = true
    @State private var aspectsExpanded = true
    @State private var rashiAspectsExpanded = true
    @State private var houseLordshipsExpanded = true

    /// Literal point sizes (not .caption/.subheadline) so this scales with
    /// the app's Cmd +/- text zoom like every other data-heavy view --
    /// kept close to .caption/.subheadline's own base sizes (not bumped up
    /// further) since this panel is dense, multi-line, and narrow.
    private var bodyFont: Font { .system(size: 10 * fontZoomMultiplier) }
    private var headerFont: Font { .system(size: 12 * fontZoomMultiplier, weight: .bold) }
    private var titleFont: Font { .system(size: 13 * fontZoomMultiplier, weight: .bold) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title).font(titleFont)
            }
            switch sections {
            case .all:
                conjunctionsSection
                aspectsSection
                rashiAspectsSection
                houseLordshipsSection
            case .rashiAndGrahaDrishti:
                rashiAspectsSection
                aspectsSection
            case .conjunctionsAndLordships:
                conjunctionsSection
                houseLordshipsSection
            case .exceptHouseLordships:
                conjunctionsSection
                aspectsSection
                rashiAspectsSection
            case .houseLordshipsOnly:
                houseLordshipsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyText(_ body: CelestialBody) -> Text {
        Text(body.displayName).foregroundStyle(theme.keyword)
    }

    private func rasiText(_ rasi: Rasi) -> Text {
        Text(rasi.displayName).foregroundStyle(theme.string)
    }

    private func joinedBodyText(_ bodies: [CelestialBody]) -> Text {
        guard let first = bodies.first else { return Text("") }
        return bodies.dropFirst().reduce(bodyText(first)) { partial, next in
            Text("\(partial), \(bodyText(next))")
        }
    }

    private var conjunctionsSection: some View {
        DisclosureGroup(isExpanded: $conjunctionsExpanded) {
            if analysis.conjunctions.isEmpty {
                Text("None").font(bodyFont).foregroundStyle(.secondary)
            } else {
                ForEach(Array(analysis.conjunctions.enumerated()), id: \.offset) { _, c in
                    Text("\(rasiText(c.rasi)): \(joinedBodyText(c.bodies))")
                        .font(bodyFont)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } label: {
            Text("Conjunctions").font(headerFont)
        }
    }

    /// Every aspect a body casts is always present now (regardless of
    /// whether the target house is occupied), so grouping by caster --
    /// "Mars \u{2192} 4th in Cancer, 7th in Libra (Saturn), 8th in Scorpio"
    /// on one line -- keeps this readable in a narrow panel instead of
    /// always being a fixed 15 rows.
    private var groupedAspectsByFrom: [(from: CelestialBody, aspects: [PlanetAspect])] {
        var dict: [CelestialBody: [PlanetAspect]] = [:]
        for aspect in analysis.aspects { dict[aspect.from, default: []].append(aspect) }
        return CelestialBody.allCases.compactMap { body in
            guard let list = dict[body] else { return nil }
            return (body, list.sorted { $0.houseNumber < $1.houseNumber })
        }
    }

    /// "7th (Moon) in Aquarius" or, when the target house is empty,
    /// "8th in Pisces" -- always names the sign the aspect actually lands
    /// on, not just the abstract house number.
    private func aspectPhrase(_ aspect: PlanetAspect) -> Text {
        let houseNumber = Text("\(aspect.houseNumber)").foregroundStyle(theme.number)
        var phrase = Text("\(houseNumber)th")
        if !aspect.toOccupants.isEmpty {
            phrase = Text("\(phrase) (\(joinedBodyText(aspect.toOccupants)))")
        }
        phrase = Text("\(phrase) in \(rasiText(aspect.toRasi))")
        return phrase
    }

    private var aspectsSection: some View {
        DisclosureGroup(isExpanded: $aspectsExpanded) {
            if !analysis.ascendantAspectedBy.isEmpty {
                Text("Ascendant \u{2190} \(joinedBodyText(analysis.ascendantAspectedBy))")
                    .font(bodyFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(groupedAspectsByFrom, id: \.from) { entry in
                entry.aspects.enumerated().reduce(Text("\(bodyText(entry.from)) \u{2192} ")) { partial, item in
                    let (index, aspect) = item
                    return index == 0 ? Text("\(partial)\(aspectPhrase(aspect))") : Text("\(partial), \(aspectPhrase(aspect))")
                }
                .font(bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        } label: {
            Text("Graha Drishti").font(headerFont)
        }
    }

    /// "Aries (Mars, Rahu)" -- rasi in string color, occupants (if any) in
    /// keyword color, matching the old Summary tab's convention.
    private func rasiLabel(_ rasi: Rasi) -> Text {
        let occupants = placements.filter { $0.value == rasi }.keys.sorted { $0.rawValue < $1.rawValue }
        guard !occupants.isEmpty else { return rasiText(rasi) }
        return Text("\(rasiText(rasi)) (\(joinedBodyText(occupants)))")
    }

    /// Every occupied sign always casts exactly 3 rashi drishti now
    /// (regardless of whether the targets are occupied), so grouping by
    /// caster -- "Aries (Mars) \u{2192} Gemini, Leo, Libra" -- keeps this to
    /// one line per occupied sign instead of 3x that.
    private var groupedRashiAspectsByFrom: [(fromRasi: Rasi, toRasis: [Rasi])] {
        var order: [Rasi] = []
        var dict: [Rasi: [Rasi]] = [:]
        for aspect in analysis.rashiAspects {
            if dict[aspect.fromRasi] == nil { order.append(aspect.fromRasi) }
            dict[aspect.fromRasi, default: []].append(aspect.toRasi)
        }
        return order.map { ($0, dict[$0] ?? []) }
    }

    private var rashiAspectsSection: some View {
        DisclosureGroup(isExpanded: $rashiAspectsExpanded) {
            if analysis.rashiAspects.isEmpty {
                Text("No occupied signs").font(bodyFont).foregroundStyle(.secondary)
            } else {
                ForEach(groupedRashiAspectsByFrom, id: \.fromRasi) { entry in
                    let toList = entry.toRasis.enumerated().reduce(Text("")) { partial, item in
                        let (index, rasi) = item
                        return index == 0 ? rasiLabel(rasi) : Text("\(partial), \(rasiLabel(rasi))")
                    }
                    Text("\(rasiLabel(entry.fromRasi)) \u{2192} \(toList)")
                        .font(bodyFont)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } label: {
            Text("Rashi Drishti").font(headerFont)
        }
    }

    /// Groups the one-row-per-house data by lord (a lord often rules 2
    /// houses) -- "4th & 7th lord Jupiter, in the 11th (Cancer)" instead
    /// of two rows differing only in which house is being described.
    private var groupedLordships: [(houses: [Int], lord: CelestialBody, placedHouse: Int, placedRasi: Rasi)] {
        var housesByLord: [CelestialBody: [Int]] = [:]
        var placedHouseByLord: [CelestialBody: Int] = [:]
        var rasiByHouse: [Int: Rasi] = [:]
        for entry in analysis.houseLordships {
            housesByLord[entry.lord, default: []].append(entry.house)
            placedHouseByLord[entry.lord] = entry.lordPlacedInHouse
            rasiByHouse[entry.house] = entry.rasi
        }
        return housesByLord.map { lord, houses in
            let placedHouse = placedHouseByLord[lord] ?? 0
            return (houses.sorted(), lord, placedHouse, rasiByHouse[placedHouse] ?? .aries)
        }.sorted { $0.houses.first! < $1.houses.first! }
    }

    private func ordinal(_ n: Int) -> String {
        switch (n % 100, n % 10) {
        case (11...13, _): return "\(n)th"
        case (_, 1): return "\(n)st"
        case (_, 2): return "\(n)nd"
        case (_, 3): return "\(n)rd"
        default: return "\(n)th"
        }
    }

    private var houseLordshipsSection: some View {
        DisclosureGroup(isExpanded: $houseLordshipsExpanded) {
            ForEach(groupedLordships, id: \.lord) { row in
                Text("\(row.houses.map(ordinal).joined(separator: " & ")) lord \(bodyText(row.lord)) \u{2192} \(ordinal(row.placedHouse)) (\(rasiText(row.placedRasi)))")
                    .font(bodyFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } label: {
            Text("House Lordships").font(headerFont)
        }
    }
}
