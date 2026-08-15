/// Conjunctions, graha drishti, rashi drishti, and house lordships --
/// shared by D1 (via ChartSummary) and every varga D2-D60 (attached to
/// each VargaChart). These four categories are purely sign-position
/// mechanics (which house a planet's sign falls in, relative to the
/// Ascendant's own sign), so they extend cleanly to any varga's own
/// placements with no classical objection. This is unlike combustion,
/// retrograde, nakshatra, Mangal/Sarpa Dosha, Arudha Lagna, and Upapada
/// Lagna -- confirmed with user via research: those are either real
/// physical facts (combustion/retrograde/nakshatra are determined by
/// actual longitude, not varga math) or classically D1-specific concepts
/// (doshas are D1-definitional; Arudha/Upapada were "designed by Jaimini
/// primarily for Rashi chart analysis... applying [them] to divisional
/// charts is a later development and not universally accepted") -- so
/// those stay D1-only, referenced once, not recomputed per varga.
public struct VargaAnalysis: Codable, Sendable, Equatable {
    public let conjunctions: [Conjunction]
    public let aspects: [PlanetAspect]
    /// Bodies whose graha drishti reaches the 1st house (the Ascendant itself).
    public let ascendantAspectedBy: [CelestialBody]
    public let houseLordships: [HouseLordship]
    /// Every rashi drishti cast by an occupied sign, to every sign it
    /// classically aspects -- regardless of whether that target sign
    /// itself is occupied.
    public let rashiAspects: [RashiAspect]

    public init(conjunctions: [Conjunction], aspects: [PlanetAspect], ascendantAspectedBy: [CelestialBody],
                houseLordships: [HouseLordship], rashiAspects: [RashiAspect]) {
        self.conjunctions = conjunctions
        self.aspects = aspects
        self.ascendantAspectedBy = ascendantAspectedBy
        self.houseLordships = houseLordships
        self.rashiAspects = rashiAspects
    }

    /// `placements` need only be a body->rasi map (D1's rows or a varga's
    /// own placements) -- whole-sign house numbers here are plain sign
    /// offsets from `ascendantRasi`, identical to what
    /// WholeSignHouses.house computes from real longitudes, since whole-
    /// sign houses never subdivide a sign. Iterates CelestialBody.allCases
    /// (not the dictionary directly) for deterministic output order.
    public static func compute(placements: [CelestialBody: Rasi], ascendantRasi: Rasi) -> VargaAnalysis {
        func house(of rasi: Rasi) -> Int {
            ((rasi.rawValue - ascendantRasi.rawValue + 12) % 12) + 1
        }

        var byRasi: [Rasi: [CelestialBody]] = [:]
        for body in CelestialBody.allCases {
            guard let rasi = placements[body] else { continue }
            byRasi[rasi, default: []].append(body)
        }
        let conjunctions = byRasi
            .filter { $0.value.count >= 2 }
            .map { Conjunction(rasi: $0.key, bodies: $0.value.sorted { $0.rawValue < $1.rawValue }) }
            .sorted { $0.rasi.rawValue < $1.rasi.rawValue }

        // Every aspect a body casts is recorded, whether or not the
        // target house happens to be occupied -- toOccupants is how a
        // caller tells the two cases apart, rather than the aspect
        // simply not existing when nothing's there to receive it.
        var aspects: [PlanetAspect] = []
        var ascendantAspectedBy: [CelestialBody] = []
        for fromBody in CelestialBody.allCases {
            guard let fromRasi = placements[fromBody] else { continue }
            let fromHouse = house(of: fromRasi)
            for houseNumber in GrahaDrishti.aspectedHouseNumbers(for: fromBody) {
                let targetHouse = ((fromHouse - 1 + houseNumber - 1) % 12) + 1
                if targetHouse == 1 {
                    ascendantAspectedBy.append(fromBody)
                }
                let targetRasi = ascendantRasi.offset(targetHouse - 1)
                var occupants: [CelestialBody] = []
                for toBody in CelestialBody.allCases where toBody != fromBody {
                    if placements[toBody] == targetRasi {
                        occupants.append(toBody)
                    }
                }
                aspects.append(PlanetAspect(from: fromBody, houseNumber: houseNumber, toHouse: targetHouse, toRasi: targetRasi, toOccupants: occupants))
            }
        }

        let houseLordships: [HouseLordship] = (1...12).compactMap { houseNumber in
            let rasi = ascendantRasi.offset(houseNumber - 1)
            let lord = rasi.lord
            guard let lordRasi = placements[lord] else { return nil }
            return HouseLordship(house: houseNumber, rasi: rasi, lord: lord, lordPlacedInHouse: house(of: lordRasi))
        }

        // Set iteration order isn't guaranteed stable across separately
        // built Sets with the same elements -- sorted explicitly so this
        // (and its JSON serialization) is reproducible run to run, not
        // just "correct content in some order".
        let occupiedRasis = Set(placements.values)
        var rashiAspects: [RashiAspect] = []
        for from in occupiedRasis.sorted(by: { $0.rawValue < $1.rawValue }) {
            for to in RashiDrishti.aspectedSigns(for: from) {
                rashiAspects.append(RashiAspect(fromRasi: from, toRasi: to))
            }
        }
        rashiAspects.sort { ($0.fromRasi.rawValue, $0.toRasi.rawValue) < ($1.fromRasi.rawValue, $1.toRasi.rawValue) }

        return VargaAnalysis(
            conjunctions: conjunctions, aspects: aspects, ascendantAspectedBy: ascendantAspectedBy,
            houseLordships: houseLordships, rashiAspects: rashiAspects
        )
    }
}
