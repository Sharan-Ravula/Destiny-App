public struct Conjunction: Codable, Sendable, Equatable {
    public let rasi: Rasi
    /// 2 or more bodies sharing this rasi.
    public let bodies: [CelestialBody]

    public init(rasi: Rasi, bodies: [CelestialBody]) {
        self.rasi = rasi
        self.bodies = bodies
    }
}

public struct HouseLordship: Codable, Sendable, Equatable {
    /// 1-12, relative to the Ascendant (whole-sign).
    public let house: Int
    public let rasi: Rasi
    public let lord: CelestialBody
    /// Which house (1-12, relative to the Ascendant) the lord currently occupies.
    public let lordPlacedInHouse: Int

    public init(house: Int, rasi: Rasi, lord: CelestialBody, lordPlacedInHouse: Int) {
        self.house = house
        self.rasi = rasi
        self.lord = lord
        self.lordPlacedInHouse = lordPlacedInHouse
    }
}

public struct ChartSummary: Codable, Sendable, Equatable {
    public let conjunctions: [Conjunction]
    public let aspects: [PlanetAspect]
    /// Bodies whose graha drishti reaches the 1st house (the Ascendant itself).
    public let ascendantAspectedBy: [CelestialBody]
    public let houseLordships: [HouseLordship]
    public let mangalDosha: MangalDoshaResult
    public let sarpaDosha: SarpaDoshaResult
    /// Rashi drishti among the rasis actually occupied by a planet.
    public let rashiAspects: [RashiAspect]
    /// The Atmakaraka's rasi in the D9 (Navamsa) chart.
    public let karakamsa: Rasi?
    public let arudhaLagna: Rasi
    public let upapadaLagna: Rasi
    /// All 12 Arudha Padas (A1-A12), index 0 = A1 (== arudhaLagna) through
    /// index 11 = A12 (== upapadaLagna) -- the same BhavaArudha algorithm
    /// already used for those two, generalized to every house. Kept
    /// alongside arudhaLagna/upapadaLagna (not replacing them) so existing
    /// callers of those two fields are unaffected.
    public let arudhaPadas: [Rasi]

    public init(conjunctions: [Conjunction], aspects: [PlanetAspect], ascendantAspectedBy: [CelestialBody],
                houseLordships: [HouseLordship], mangalDosha: MangalDoshaResult, sarpaDosha: SarpaDoshaResult,
                rashiAspects: [RashiAspect], karakamsa: Rasi?, arudhaLagna: Rasi, upapadaLagna: Rasi, arudhaPadas: [Rasi]) {
        self.conjunctions = conjunctions
        self.aspects = aspects
        self.ascendantAspectedBy = ascendantAspectedBy
        self.houseLordships = houseLordships
        self.mangalDosha = mangalDosha
        self.sarpaDosha = sarpaDosha
        self.rashiAspects = rashiAspects
        self.karakamsa = karakamsa
        self.arudhaLagna = arudhaLagna
        self.upapadaLagna = upapadaLagna
        self.arudhaPadas = arudhaPadas
    }

    /// Pure function of already-computed D1 data -- no new ephemeris calls.
    /// Takes the raw pieces (not a full ChartComputation) since this result
    /// becomes a field *on* ChartComputation itself. `navamsaPlacements` is
    /// the D9 varga's body->rasi map, needed only for Karakamsa.
    public static func compute(rows: [ChartRow], ascendant: ChartPoint, navamsaPlacements: [CelestialBody: Rasi]) -> ChartSummary {
        let ascendantLongitude = ascendant.absoluteLongitude
        var longitudes: [CelestialBody: Double] = [:]
        for row in rows { longitudes[row.body] = row.absoluteLongitude }

        // Conjunctions/aspects/house lordships/rashi aspects are pure
        // sign-position mechanics -- identical math whether it's D1 or any
        // other varga -- so they're shared with VargaAnalysis.compute
        // rather than duplicated here. See VargaAnalysis's doc comment for
        // why the *other* fields below (doshas, Arudha/Upapada) stay
        // D1-only instead of also being factored out.
        let ascendantRasi = ascendant.rasi
        var placements: [CelestialBody: Rasi] = [:]
        for row in rows { placements[row.body] = row.rasi }
        let analysis = VargaAnalysis.compute(placements: placements, ascendantRasi: ascendantRasi)
        let conjunctions = analysis.conjunctions
        let aspects = analysis.aspects
        let ascendantAspectedBy = analysis.ascendantAspectedBy
        let houseLordships = analysis.houseLordships
        let rashiAspects = analysis.rashiAspects

        let mangalDosha: MangalDoshaResult
        if let mars = longitudes[.mars] {
            mangalDosha = MangalDosha.evaluate(marsLongitude: mars, lagnaLongitude: ascendantLongitude)
        } else {
            mangalDosha = MangalDoshaResult(isPresent: false, house: 0)
        }

        let sarpaDosha = SarpaDosha.evaluate(longitudes: longitudes)

        let karakamsa = rows.first(where: { $0.karaka == .atmaKaraka }).flatMap { navamsaPlacements[$0.body] }

        let arudhaLagna = ArudhaLagna.compute(ascendantRasi: ascendantRasi, lordPlacement: placements)
        let upapadaLagna = UpapadaLagna.compute(ascendantRasi: ascendantRasi, lordPlacement: placements)
        let arudhaPadas = (1...12).map { house in
            BhavaArudha.compute(from: ascendantRasi.offset(house - 1), lordPlacement: placements)
        }

        return ChartSummary(
            conjunctions: conjunctions, aspects: aspects, ascendantAspectedBy: ascendantAspectedBy,
            houseLordships: houseLordships, mangalDosha: mangalDosha, sarpaDosha: sarpaDosha,
            rashiAspects: rashiAspects, karakamsa: karakamsa, arudhaLagna: arudhaLagna, upapadaLagna: upapadaLagna,
            arudhaPadas: arudhaPadas
        )
    }
}
