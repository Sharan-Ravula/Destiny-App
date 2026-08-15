import Foundation

public enum ChartCalculator {
    /// Bumped whenever calculation logic changes -- stored by the app
    /// alongside a saved chart's raw inputs so a persisted chart could be
    /// flagged if it was last computed under different logic.
    public static let engineVersion = "2.0.0"

    private static let karakaEligibleBodies: [CelestialBody] = [.sun, .moon, .mars, .mercury, .jupiter, .venus, .saturn]

    /// Shared by computeChart, computeD1Snapshot, and computeVargaSnapshot
    /// -- the only calls that actually hit the ephemeris.
    private static func positionsAndAscendant(
        birthMoment: BirthMoment, latitude: Double, longitude: Double, ayanamsa: Ayanamsa
    ) async throws -> (utcDate: Date, positions: [PlanetPosition], ascendantLongitude: Double) {
        let utcDate = try birthMoment.resolvedUTCDate()
        let engine = EphemerisEngine.shared

        let positions = try await engine.planetaryPositions(
            date: utcDate, latitude: latitude, longitude: longitude, ayanamsa: ayanamsa, nodeType: .mean
        )
        let ascendantLongitude = try await engine.ascendant(
            date: utcDate, latitude: latitude, longitude: longitude, ayanamsa: ayanamsa
        )
        return (utcDate, positions, ascendantLongitude)
    }

    public static func computeChart(
        birthMoment: BirthMoment,
        latitude: Double,
        longitude: Double,
        ayanamsa: Ayanamsa = .lahiri
    ) async throws -> ChartComputation {
        let (utcDate, positions, ascendantLongitude) = try await positionsAndAscendant(
            birthMoment: birthMoment, latitude: latitude, longitude: longitude, ayanamsa: ayanamsa
        )

        guard let sunLongitude = positions.first(where: { $0.body == .sun })?.siderealLongitude else {
            throw ChartCalculatorError.missingBody(.sun)
        }

        var degreesWithinSign: [CelestialBody: Double] = [:]
        for body in karakaEligibleBodies {
            guard let position = positions.first(where: { $0.body == body }) else {
                throw ChartCalculatorError.missingBody(body)
            }
            degreesWithinSign[body] = AngleMath.degreeWithinSign(position.siderealLongitude)
        }
        let karakaAssignments = KarakaCalculator.sevenKarakaAssignments(degreesWithinSign: degreesWithinSign)

        let rows = positions.map { position -> ChartRow in
            let combust = karakaEligibleBodies.contains(position.body) && position.body != .sun
                ? Combustion.isCombust(
                    body: position.body, longitude: position.siderealLongitude,
                    sunLongitude: sunLongitude, isRetrograde: position.isRetrograde
                )
                : false

            return ChartRow(
                body: position.body,
                absoluteLongitude: position.siderealLongitude,
                degreeWithinSign: AngleMath.degreeWithinSign(position.siderealLongitude),
                rasi: Rasi.containing(longitude: position.siderealLongitude),
                nakshatra: Nakshatra.containing(longitude: position.siderealLongitude),
                isRetrograde: position.isRetrograde,
                isCombust: combust,
                karaka: karakaAssignments[position.body]
            )
        }

        let ascendant = ChartPoint(
            absoluteLongitude: ascendantLongitude,
            rasi: Rasi.containing(longitude: ascendantLongitude),
            nakshatra: Nakshatra.containing(longitude: ascendantLongitude)
        )

        let vargas = DivisionalChart.allCases.filter { $0 != .d1 }.map { varga -> VargaChart in
            var placements: [CelestialBody: Rasi] = [:]
            var degreesWithinSign: [CelestialBody: Double] = [:]
            for position in positions {
                placements[position.body] = varga.rasi(forLongitude: position.siderealLongitude)
                degreesWithinSign[position.body] = varga.degreeWithinResultingSign(forLongitude: position.siderealLongitude)
            }
            let vargaAscendant = varga.rasi(forLongitude: ascendantLongitude)
            return VargaChart(
                varga: varga,
                ascendant: vargaAscendant,
                ascendantDegreeWithinSign: varga.degreeWithinResultingSign(forLongitude: ascendantLongitude),
                placements: placements,
                degreesWithinSign: degreesWithinSign,
                analysis: VargaAnalysis.compute(placements: placements, ascendantRasi: vargaAscendant)
            )
        }

        guard let moonLongitude = positions.first(where: { $0.body == .moon })?.siderealLongitude else {
            throw ChartCalculatorError.missingBody(.moon)
        }
        let dasha = VimshottariDasha.mahadashaSequence(moonLongitude: moonLongitude, birthDate: utcDate)

        var lordPlacement: [CelestialBody: Rasi] = [:]
        for row in rows where karakaEligibleBodies.contains(row.body) {
            lordPlacement[row.body] = row.rasi
        }
        let charaDasha = CharaDasha.sequence(lagna: ascendant.rasi, lordPlacement: lordPlacement, birthDate: utcDate)

        let navamsaPlacements = vargas.first(where: { $0.varga == .d9 })?.placements ?? [:]
        let summary = ChartSummary.compute(rows: rows, ascendant: ascendant, navamsaPlacements: navamsaPlacements)

        return ChartComputation(
            ascendant: ascendant, rows: rows,
            vargas: vargas, vimshottariDasha: dasha, charaDasha: charaDasha, summary: summary
        )
    }

    /// Just the D1 ascendant + planet rows for an arbitrary moment -- no
    /// vargas/dashas/summary. For live transit scrubbing, where only D1
    /// needs to re-render on every recompute and the other outputs would
    /// be wasted work recomputed dozens of times a minute. `karaka` is
    /// always nil here (the 7-karaka scheme is a natal-chart concept, not
    /// meaningful for an arbitrary transit moment).
    public static func computeD1Snapshot(
        birthMoment: BirthMoment,
        latitude: Double,
        longitude: Double,
        ayanamsa: Ayanamsa = .lahiri
    ) async throws -> (ascendant: ChartPoint, rows: [ChartRow]) {
        let (_, positions, ascendantLongitude) = try await positionsAndAscendant(
            birthMoment: birthMoment, latitude: latitude, longitude: longitude, ayanamsa: ayanamsa
        )

        guard let sunLongitude = positions.first(where: { $0.body == .sun })?.siderealLongitude else {
            throw ChartCalculatorError.missingBody(.sun)
        }

        let rows = positions.map { position -> ChartRow in
            let combust = karakaEligibleBodies.contains(position.body) && position.body != .sun
                ? Combustion.isCombust(
                    body: position.body, longitude: position.siderealLongitude,
                    sunLongitude: sunLongitude, isRetrograde: position.isRetrograde
                )
                : false

            return ChartRow(
                body: position.body,
                absoluteLongitude: position.siderealLongitude,
                degreeWithinSign: AngleMath.degreeWithinSign(position.siderealLongitude),
                rasi: Rasi.containing(longitude: position.siderealLongitude),
                nakshatra: Nakshatra.containing(longitude: position.siderealLongitude),
                isRetrograde: position.isRetrograde,
                isCombust: combust,
                karaka: nil
            )
        }

        let ascendant = ChartPoint(
            absoluteLongitude: ascendantLongitude,
            rasi: Rasi.containing(longitude: ascendantLongitude),
            nakshatra: Nakshatra.containing(longitude: ascendantLongitude)
        )

        return (ascendant, rows)
    }

    /// Same idea as computeD1Snapshot, but for a single arbitrary varga --
    /// used when the transit scrubber is opened on whichever divisional
    /// chart was already on screen (e.g. D3), not just D1. Only ever
    /// computes the one requested varga, not all 16, on each recompute.
    /// No retrograde/combustion data -- same as every other varga's
    /// placements (that's a D1-only concept), so ChartLayoutData's
    /// existing varga rendering already handles this correctly.
    public static func computeVargaSnapshot(
        varga: DivisionalChart,
        birthMoment: BirthMoment,
        latitude: Double,
        longitude: Double,
        ayanamsa: Ayanamsa = .lahiri
    ) async throws -> VargaChart {
        let (_, positions, ascendantLongitude) = try await positionsAndAscendant(
            birthMoment: birthMoment, latitude: latitude, longitude: longitude, ayanamsa: ayanamsa
        )

        var placements: [CelestialBody: Rasi] = [:]
        var degreesWithinSign: [CelestialBody: Double] = [:]
        for position in positions {
            placements[position.body] = varga.rasi(forLongitude: position.siderealLongitude)
            degreesWithinSign[position.body] = varga.degreeWithinResultingSign(forLongitude: position.siderealLongitude)
        }

        let vargaAscendant = varga.rasi(forLongitude: ascendantLongitude)
        return VargaChart(
            varga: varga,
            ascendant: vargaAscendant,
            ascendantDegreeWithinSign: varga.degreeWithinResultingSign(forLongitude: ascendantLongitude),
            placements: placements,
            degreesWithinSign: degreesWithinSign,
            analysis: VargaAnalysis.compute(placements: placements, ascendantRasi: vargaAscendant)
        )
    }
}

public enum ChartCalculatorError: Error, Sendable {
    case missingBody(CelestialBody)
}
