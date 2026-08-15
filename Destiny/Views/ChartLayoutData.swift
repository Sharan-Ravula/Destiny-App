import SwiftUI
import DestinyEngine

/// A planet abbreviation plus its markers, kept separate (rather than
/// pre-joined into one string) so the view can color the retrograde/combust
/// markers with theme.number -- matching the legend -- distinctly from the
/// abbreviation itself.
struct PlanetLabel {
    let body: CelestialBody
    let abbreviation: String
    let isRetrograde: Bool
    let isCombust: Bool
}

/// Shared data prep for both chart renderers: which planets (and the
/// Ascendant) fall in each rasi.
struct ChartLayoutData {
    let ascendantRasi: Rasi
    let planetsByRasi: [Rasi: [PlanetLabel]]
    /// Kept separate from planetsByRasi -- these render as their own
    /// bottom-left corner badge (mirroring the top-right "Asc" badge)
    /// rather than mixed into the centered planet-abbreviation text.
    let arudhaLagnaRasi: Rasi?
    let upapadaLagnaRasi: Rasi?
    /// Karakamsa (the Atmakaraka's D9 sign) only makes sense in the
    /// Navamsa chart specifically, so callers opt in per-varga rather than
    /// this being derived automatically.
    let karakamsaRasi: Rasi?

    init(computation: ChartComputation) {
        ascendantRasi = computation.ascendant.rasi
        var dict: [Rasi: [PlanetLabel]] = [:]
        for row in computation.rows {
            let label = PlanetLabel(body: row.body, abbreviation: row.body.abbreviation, isRetrograde: row.isRetrograde, isCombust: row.isCombust)
            dict[row.rasi, default: []].append(label)
        }
        self.planetsByRasi = dict
        self.arudhaLagnaRasi = computation.summary.arudhaLagna
        self.upapadaLagnaRasi = computation.summary.upapadaLagna
        self.karakamsaRasi = nil
    }

    /// Divisional charts (D2-D60) have no retrograde/combustion data of
    /// their own -- just body -> rasi placements.
    init(varga: VargaChart, karakamsaRasi: Rasi? = nil) {
        ascendantRasi = varga.ascendant
        var dict: [Rasi: [PlanetLabel]] = [:]
        // Iterate allCases (not the dictionary directly) for a
        // deterministic, stable display order.
        for body in CelestialBody.allCases {
            guard let rasi = varga.placements[body] else { continue }
            dict[rasi, default: []].append(PlanetLabel(body: body, abbreviation: body.abbreviation, isRetrograde: false, isCombust: false))
        }
        self.planetsByRasi = dict
        self.arudhaLagnaRasi = nil
        self.upapadaLagnaRasi = nil
        self.karakamsaRasi = karakamsaRasi
    }

    /// Live transit snapshot (an arbitrary moment, not the natal chart) --
    /// just ascendant + rows, no full ChartComputation/summary, so no
    /// Arudha/Upapada Lagna badges (those are natal-chart-only concepts).
    init(ascendant: ChartPoint, rows: [ChartRow]) {
        ascendantRasi = ascendant.rasi
        var dict: [Rasi: [PlanetLabel]] = [:]
        for row in rows {
            let label = PlanetLabel(body: row.body, abbreviation: row.body.abbreviation, isRetrograde: row.isRetrograde, isCombust: row.isCombust)
            dict[row.rasi, default: []].append(label)
        }
        self.planetsByRasi = dict
        self.arudhaLagnaRasi = nil
        self.upapadaLagnaRasi = nil
        self.karakamsaRasi = nil
    }

    /// House number (1-12) for a given rasi, relative to the Ascendant --
    /// whole-sign houses, so this is just the rasi's offset from the
    /// Ascendant's rasi.
    func houseNumber(for rasi: Rasi) -> Int {
        ((rasi.rawValue - ascendantRasi.rawValue + 12) % 12) + 1
    }

    /// Every rasi aspected (Graha Drishti) by any planet occupying `rasi`
    /// -- for hover highlighting. When a rasi holds more than one planet,
    /// this is the union of each occupant's own aspects (e.g. hovering a
    /// Mars+Saturn conjunction highlights both their aspected houses
    /// together) rather than attributing individual houses to individual
    /// planets, since the highlight itself doesn't need to distinguish
    /// which planet caused which house to light up.
    func aspectedRasis(hovering rasi: Rasi) -> Set<Rasi> {
        guard let labels = planetsByRasi[rasi] else { return [] }
        let fromHouse = houseNumber(for: rasi)
        var result: Set<Rasi> = []
        for label in labels {
            for houseNumber in GrahaDrishti.aspectedHouseNumbers(for: label.body) {
                let targetHouse = ((fromHouse - 1 + houseNumber - 1) % 12) + 1
                result.insert(ascendantRasi.offset(targetHouse - 1))
            }
        }
        return result
    }

    /// The planet abbreviations for a rasi as one Text, with each
    /// retrograde/combust marker colored theme.number -- same color the
    /// legend uses for "^"/"*" -- distinctly from the abbreviation itself
    /// (theme.keyword).
    func planetText(for rasi: Rasi, theme: ColorTheme) -> Text {
        let labels = planetsByRasi[rasi] ?? []
        guard !labels.isEmpty else { return Text("") }
        return labels.enumerated().reduce(Text("")) { partial, entry in
            let (index, label) = entry
            var segment = Text(label.abbreviation).foregroundStyle(theme.keyword)
            if label.isRetrograde {
                segment = Text("\(segment)\(Text("^").foregroundStyle(theme.number))")
            }
            if label.isCombust {
                segment = Text("\(segment)\(Text("*").foregroundStyle(theme.number))")
            }
            return index == 0 ? segment : Text("\(partial) \(segment)")
        }
    }
}
