import Testing
import Foundation
@testable import DestinyEngine

@Suite("Rasi static properties")
struct RasiStaticPropertiesTests {
    @Test func genderAlternatesStartingMale() {
        #expect(Rasi.aries.gender == .male)
        #expect(Rasi.taurus.gender == .female)
        #expect(Rasi.gemini.gender == .male)
        #expect(Rasi.libra.gender == .male)
        #expect(Rasi.scorpio.gender == .female)
    }

    @Test func directionMatchesElement() {
        #expect(Rasi.aries.direction == .east) // fire
        #expect(Rasi.leo.direction == .east) // fire
        #expect(Rasi.taurus.direction == .south) // earth
        #expect(Rasi.virgo.direction == .south) // earth
        #expect(Rasi.gemini.direction == .west) // air
        #expect(Rasi.libra.direction == .west) // air
        #expect(Rasi.cancer.direction == .north) // water
        #expect(Rasi.scorpio.direction == .north) // water
    }
}

@Suite("VargaAnalysis")
struct VargaAnalysisTests {
    /// Two planets in the same sign, 7th from the Ascendant -- exercises
    /// conjunctions, the universal 7th-house graha drishti, and house
    /// lordships together in one minimal, hand-verifiable setup.
    @Test func minimalHandVerifiedCase() {
        let placements: [CelestialBody: Rasi] = [.sun: .libra, .moon: .libra, .mars: .capricorn]
        let analysis = VargaAnalysis.compute(placements: placements, ascendantRasi: .aries)

        #expect(analysis.conjunctions.count == 1)
        #expect(analysis.conjunctions[0].rasi == .libra)
        #expect(Set(analysis.conjunctions[0].bodies) == [.sun, .moon])

        // Sun/Moon in Libra = house 7 from Aries; their 7th-house aspect
        // lands back on house 1 (the Ascendant). Mars in Capricorn =
        // house 10 from Aries; Mars's 4th-house aspect ((10-1+4-1)%12)+1
        // also lands on house 1. All three show up in ascendantAspectedBy;
        // nothing else occupies Aries, so no planet-to-planet aspect
        // results from any of this.
        #expect(Set(analysis.ascendantAspectedBy) == [.sun, .moon, .mars])

        let ariesLordship = analysis.houseLordships.first { $0.house == 1 }
        #expect(ariesLordship?.lord == .mars)
        #expect(ariesLordship?.lordPlacedInHouse == 10)
    }

    /// Repeated calls with the same input, constructed via a differently-
    /// ordered dictionary literal, must produce byte-for-byte identical
    /// output -- guards against the Set-iteration-order bug caught by
    /// Sprint2ReferenceChartTests.chart1D3SnapshotMatchesFullCompute.
    @Test func deterministicAcrossRepeatedCalls() {
        let placements: [CelestialBody: Rasi] = [
            .sun: .pisces, .moon: .aries, .mercury: .cancer, .venus: .scorpio,
            .mars: .aries, .jupiter: .taurus, .saturn: .scorpio, .rahu: .sagittarius, .ketu: .gemini,
        ]
        let reordered: [CelestialBody: Rasi] = [
            .ketu: .gemini, .rahu: .sagittarius, .saturn: .scorpio, .jupiter: .taurus, .mars: .aries,
            .venus: .scorpio, .mercury: .cancer, .moon: .aries, .sun: .pisces,
        ]
        let a = VargaAnalysis.compute(placements: placements, ascendantRasi: .libra)
        let b = VargaAnalysis.compute(placements: reordered, ascendantRasi: .libra)
        #expect(a == b)
    }
}

@Suite("DivisionalChart formulas")
struct DivisionalChartTests {
    @Test func d2Hora() {
        #expect(DivisionalChart.d2.rasi(forLongitude: 5) == .leo) // Aries (odd), 1st half
        #expect(DivisionalChart.d2.rasi(forLongitude: 20) == .cancer) // Aries (odd), 2nd half
        #expect(DivisionalChart.d2.rasi(forLongitude: 35) == .cancer) // Taurus (even), 1st half
        #expect(DivisionalChart.d2.rasi(forLongitude: 50) == .leo) // Taurus (even), 2nd half
    }

    @Test func d3Drekkana() {
        #expect(DivisionalChart.d3.rasi(forLongitude: 5) == .aries) // part 0: same
        #expect(DivisionalChart.d3.rasi(forLongitude: 15) == .leo) // part 1: 5th
        #expect(DivisionalChart.d3.rasi(forLongitude: 25) == .sagittarius) // part 2: 9th
    }

    @Test func d4Chaturthamsa() {
        #expect(DivisionalChart.d4.rasi(forLongitude: 2) == .aries)
        #expect(DivisionalChart.d4.rasi(forLongitude: 10) == .cancer)
        #expect(DivisionalChart.d4.rasi(forLongitude: 20) == .libra)
        #expect(DivisionalChart.d4.rasi(forLongitude: 27) == .capricorn)
    }

    @Test func d7Saptamsa() {
        #expect(DivisionalChart.d7.rasi(forLongitude: 2) == .aries) // odd: from same
        #expect(DivisionalChart.d7.rasi(forLongitude: 32) == .scorpio) // Taurus (even): from 7th (Scorpio)
    }

    @Test func d9Navamsa() {
        // Movable (Aries) starts from itself.
        #expect(DivisionalChart.d9.rasi(forLongitude: 0.5) == .aries)
        // Fixed (Taurus) starts from the 9th (Capricorn).
        #expect(DivisionalChart.d9.rasi(forLongitude: 30.5) == .capricorn)
        // Dual (Gemini) starts from the 5th (Libra).
        #expect(DivisionalChart.d9.rasi(forLongitude: 60.5) == .libra)
    }

    @Test func d10Dasamsa() {
        #expect(DivisionalChart.d10.rasi(forLongitude: 1) == .aries) // odd, part 0: same
        #expect(DivisionalChart.d10.rasi(forLongitude: 28) == .capricorn) // odd, part 9: +9
        #expect(DivisionalChart.d10.rasi(forLongitude: 31) == .capricorn) // Taurus (even), part 0: from 9th
    }

    @Test func d12Dwadasamsa() {
        #expect(DivisionalChart.d12.rasi(forLongitude: 1) == .aries)
        #expect(DivisionalChart.d12.rasi(forLongitude: 28) == .pisces) // part 11: +11
    }

    @Test func d16Shodasamsa() {
        #expect(DivisionalChart.d16.rasi(forLongitude: 0.5) == .aries) // movable -> from Aries
        #expect(DivisionalChart.d16.rasi(forLongitude: 30.5) == .leo) // fixed -> from Leo
        #expect(DivisionalChart.d16.rasi(forLongitude: 60.5) == .sagittarius) // dual -> from Sagittarius
    }

    @Test func d20Vimsamsa() {
        #expect(DivisionalChart.d20.rasi(forLongitude: 0.5) == .aries)
        #expect(DivisionalChart.d20.rasi(forLongitude: 30.5) == .sagittarius)
        #expect(DivisionalChart.d20.rasi(forLongitude: 60.5) == .leo)
    }

    @Test func d24Chaturvimsamsa() {
        #expect(DivisionalChart.d24.rasi(forLongitude: 0.5) == .leo) // odd -> from Leo
        #expect(DivisionalChart.d24.rasi(forLongitude: 30.5) == .cancer) // even -> from Cancer
    }

    @Test func d27Bhamsa() {
        #expect(DivisionalChart.d27.rasi(forLongitude: 0.5) == .aries) // fire -> from Aries
        #expect(DivisionalChart.d27.rasi(forLongitude: 90.5) == .capricorn) // Cancer, water -> from Capricorn
    }

    @Test func d30Trimsamsa() {
        // Aries (odd): Mars 0-5, Saturn 5-10, Jupiter 10-18, Mercury 18-25, Venus 25-30.
        #expect(DivisionalChart.d30.rasi(forLongitude: 2) == .aries)
        #expect(DivisionalChart.d30.rasi(forLongitude: 7) == .aquarius)
        #expect(DivisionalChart.d30.rasi(forLongitude: 14) == .sagittarius)
        #expect(DivisionalChart.d30.rasi(forLongitude: 21) == .gemini)
        #expect(DivisionalChart.d30.rasi(forLongitude: 27) == .libra)
        // Taurus (even, reversed): Venus 0-5, Mercury 5-12, Jupiter 12-20, Saturn 20-25, Mars 25-30.
        #expect(DivisionalChart.d30.rasi(forLongitude: 32) == .libra)
        #expect(DivisionalChart.d30.rasi(forLongitude: 38) == .gemini)
        #expect(DivisionalChart.d30.rasi(forLongitude: 45) == .sagittarius)
        #expect(DivisionalChart.d30.rasi(forLongitude: 52) == .aquarius)
        #expect(DivisionalChart.d30.rasi(forLongitude: 58) == .aries)
    }

    @Test func d40Khavedamsa() {
        #expect(DivisionalChart.d40.rasi(forLongitude: 0.3) == .aries) // odd -> from Aries
        #expect(DivisionalChart.d40.rasi(forLongitude: 30.3) == .libra) // even -> from Libra
    }

    @Test func d45Akshavedamsa() {
        #expect(DivisionalChart.d45.rasi(forLongitude: 0.3) == .aries)
        #expect(DivisionalChart.d45.rasi(forLongitude: 30.3) == .leo)
        #expect(DivisionalChart.d45.rasi(forLongitude: 60.3) == .sagittarius)
    }

    @Test func d60Shashtiamsa() {
        #expect(DivisionalChart.d60.rasi(forLongitude: 0.3) == .aries) // part 0
        #expect(DivisionalChart.d60.rasi(forLongitude: 0.7) == .taurus) // part 1
        #expect(DivisionalChart.d60.rasi(forLongitude: 6.2) == .aries) // part 12 -> wraps (12 % 12 = 0)
    }

    /// Proportional position within whichever division determined the
    /// resulting sign, scaled to fill 0-30 -- same longitudes as
    /// d3Drekkana above, all landing exactly mid-part (5 of each part's
    /// 10 degrees in), so all three should read 15 degrees regardless of
    /// which sign the part maps to.
    @Test func d3DegreeWithinResultingSign() {
        #expect(DivisionalChart.d3.degreeWithinResultingSign(forLongitude: 5) == 15)
        #expect(DivisionalChart.d3.degreeWithinResultingSign(forLongitude: 15) == 15)
        #expect(DivisionalChart.d3.degreeWithinResultingSign(forLongitude: 25) == 15)
    }

    /// D30's unequal widths need their own check -- same longitudes as
    /// d30Trimsamsa above (Aries/odd: Mars 0-5, Saturn 5-10, Jupiter
    /// 10-18, Mercury 18-25, Venus 25-30).
    @Test func d30DegreeWithinResultingSign() {
        #expect(DivisionalChart.d30.degreeWithinResultingSign(forLongitude: 2) == 12) // Mars: 2/5*30
        #expect(DivisionalChart.d30.degreeWithinResultingSign(forLongitude: 7) == 12) // Saturn: (7-5)/5*30
        #expect(DivisionalChart.d30.degreeWithinResultingSign(forLongitude: 14) == 15) // Jupiter: (14-10)/8*30
        let mercuryDegree = DivisionalChart.d30.degreeWithinResultingSign(forLongitude: 21) // (21-18)/7*30
        #expect(abs(mercuryDegree - 12.857) < 0.001)
        #expect(DivisionalChart.d30.degreeWithinResultingSign(forLongitude: 27) == 12) // Venus: (27-25)/5*30
    }
}

@Suite("VimshottariDasha")
struct VimshottariDashaTests {
    @Test func balanceFormula() {
        // Nakshatra span 800 arcmin; 5.3667deg = 322 arcmin elapsed into
        // Purva Ashadha (index 19, lord Venus, 20 years) at Moon=258.7deg.
        let (lord, years) = VimshottariDasha.balanceAtBirth(moonLongitude: 258.7)
        #expect(lord == .venus)
        #expect(abs(years - 11.95) < 0.01)
    }

    @Test func sequenceStartsAtBalanceLordAndSumsToFullCycle() {
        let birth = Date(timeIntervalSince1970: 0)
        let sequence = VimshottariDasha.mahadashaSequence(moonLongitude: 258.7, birthDate: birth)
        #expect(sequence.count == 9)
        #expect(sequence[0].lord == .venus)
        #expect(sequence[1].lord == .sun) // next in the fixed 9-lord cycle after Venus
        #expect(sequence[0].startDate == birth)
        // The sequence is forward-looking from birth only, so it's the
        // truncated first mahadasha's *remaining* years plus the other 8
        // lords in full -- not a full 120, since the already-elapsed
        // portion of the first mahadasha (before birth) isn't included.
        let expectedTotalYears = 11.95 + VimshottariDasha.yearsByLord.filter { $0.key != .venus }.values.reduce(0, +)
        let totalDays = sequence.last!.endDate.timeIntervalSince(birth) / 86400
        #expect(abs(totalDays / VimshottariDasha.daysPerYear - expectedTotalYears) < 0.01)
    }

    @Test func subPeriodsSumToParentDuration() {
        let birth = Date(timeIntervalSince1970: 0)
        let sequence = VimshottariDasha.mahadashaSequence(moonLongitude: 258.7, birthDate: birth)
        let firstMahadasha = sequence[0]
        #expect(firstMahadasha.subPeriods.count == 9)
        #expect(firstMahadasha.subPeriods[0].lord == .venus) // self-antardasha first
        #expect(firstMahadasha.subPeriods.last!.endDate == firstMahadasha.endDate)
        // Pratyantardasha level exists, one further level down, then stops.
        #expect(!firstMahadasha.subPeriods[0].subPeriods.isEmpty)
        #expect(firstMahadasha.subPeriods[0].subPeriods[0].subPeriods.isEmpty)
    }
}

@Suite("D9 and Vimshottari balance against Sprint 0 reference charts")
struct Sprint2ReferenceChartTests {
    @Test("Chart 1 - Sydney", arguments: [chart1Sydney])
    func chart1(_ chart: ReferenceChart) throws {
        let moonLongitude = chart.expected[.moon]!.longitude

        print("\n=== Chart 1 - Sydney: D9 (Navamsa) placements ===")
        for body in CelestialBody.allCases {
            let lon = chart.expected[body]!.longitude
            print("\(body.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) D1=\(Rasi.containing(longitude: lon))  D9=\(DivisionalChart.d9.rasi(forLongitude: lon))")
        }
        print("Ascendant D1=\(Rasi.containing(longitude: chart.expectedAscendant))  D9=\(DivisionalChart.d9.rasi(forLongitude: chart.expectedAscendant))")

        let birth = try chart.moment.resolvedUTCDate()
        let sequence = VimshottariDasha.mahadashaSequence(moonLongitude: moonLongitude, birthDate: birth)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Display in the birth location's own timezone, not the test
        // runner's system timezone (DateFormatter defaults to the latter,
        // which would show the wrong calendar date for a UTC-adjacent
        // birth instant).
        formatter.timeZone = TimeZone(identifier: chart.moment.timeZoneIdentifier)
        print("\n=== Chart 1 - Sydney: Vimshottari mahadasha sequence from birth ===")
        for period in sequence {
            print("\(period.lord.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(formatter.string(from: period.startDate)) -> \(formatter.string(from: period.endDate))")
        }
        print("\nFirst mahadasha (\(sequence[0].lord.rawValue)) antardashas:")
        for sub in sequence[0].subPeriods {
            print("  \(sub.lord.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(formatter.string(from: sub.startDate)) -> \(formatter.string(from: sub.endDate))")
        }

        #expect(DivisionalChart.d9.rasi(forLongitude: moonLongitude) == .virgo)
        let (lord, years) = VimshottariDasha.balanceAtBirth(moonLongitude: moonLongitude)
        #expect(lord == .venus)
        #expect(abs(years - 11.95) < 0.01)
    }

    @Test("Chart 2 - Reykjavik", arguments: [chart2Reykjavik])
    func chart2(_ chart: ReferenceChart) throws {
        let moonLongitude = chart.expected[.moon]!.longitude
        #expect(DivisionalChart.d9.rasi(forLongitude: moonLongitude) == .gemini)
        let (lord, years) = VimshottariDasha.balanceAtBirth(moonLongitude: moonLongitude)
        #expect(lord == .moon)
        #expect(abs(years - 3.975) < 0.01)
    }

    @Test("Chart 3 - Mumbai", arguments: [chart3Mumbai])
    func chart3(_ chart: ReferenceChart) throws {
        let moonLongitude = chart.expected[.moon]!.longitude
        #expect(DivisionalChart.d9.rasi(forLongitude: moonLongitude) == .gemini)
        let (lord, years) = VimshottariDasha.balanceAtBirth(moonLongitude: moonLongitude)
        #expect(lord == .jupiter)
        #expect(abs(years - 6.56) < 0.01)
    }

    /// D3 degreeWithinResultingSign against Chart 1's already-validated D1
    /// longitudes, hand-derived: Sun Pisces 0.883 deg (part 0, same sign) ->
    /// 0.883/10*30 = 2.65; Mercury Pisces 19.0 deg (part 1, +4 -> Cancer)
    /// -> (19-10)/10*30 = 27.0; Venus Pisces 28.6 deg (part 2, +8 ->
    /// Scorpio) -> (28.6-20)/10*30 = 25.8; Mars Aries 6.317 deg (part 0,
    /// same sign) -> 6.317/10*30 = 18.95.
    @Test("Chart 1 - Sydney: D3 degree within resulting sign", arguments: [chart1Sydney])
    func chart1D3Degree(_ chart: ReferenceChart) throws {
        let sunDegree = DivisionalChart.d3.degreeWithinResultingSign(forLongitude: chart.expected[.sun]!.longitude)
        #expect(abs(sunDegree - 2.65) < 0.01)

        let mercuryDegree = DivisionalChart.d3.degreeWithinResultingSign(forLongitude: chart.expected[.mercury]!.longitude)
        #expect(abs(mercuryDegree - 27.0) < 0.01)

        let venusDegree = DivisionalChart.d3.degreeWithinResultingSign(forLongitude: chart.expected[.venus]!.longitude)
        #expect(abs(venusDegree - 25.8) < 0.01)

        let marsDegree = DivisionalChart.d3.degreeWithinResultingSign(forLongitude: chart.expected[.mars]!.longitude)
        #expect(abs(marsDegree - 18.95) < 0.01)
    }

    /// computeD1Snapshot is a leaner alternative to computeChart used by
    /// the transit scrubber (no vargas/dashas/summary) -- its ascendant and
    /// rows must exactly match computeChart's D1 output for the same
    /// moment, since it shares the same underlying engine calls and row-
    /// building logic.
    @Test("Chart 1 - Sydney: computeD1Snapshot matches computeChart's D1", arguments: [chart1Sydney])
    func chart1D1SnapshotMatchesFullCompute(_ chart: ReferenceChart) async throws {
        let full = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let snapshot = try await ChartCalculator.computeD1Snapshot(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )

        #expect(snapshot.ascendant == full.ascendant)
        #expect(snapshot.rows.count == full.rows.count)
        for (snapshotRow, fullRow) in zip(snapshot.rows, full.rows) {
            #expect(snapshotRow.body == fullRow.body)
            #expect(snapshotRow.absoluteLongitude == fullRow.absoluteLongitude)
            #expect(snapshotRow.rasi == fullRow.rasi)
            #expect(snapshotRow.nakshatra == fullRow.nakshatra)
            #expect(snapshotRow.isRetrograde == fullRow.isRetrograde)
            #expect(snapshotRow.isCombust == fullRow.isCombust)
            #expect(snapshotRow.karaka == nil)
        }
    }

    /// Same idea, for computeVargaSnapshot (used when the transit scrubber
    /// opens on a specific divisional chart, e.g. D3, instead of D1) --
    /// must match the corresponding VargaChart out of computeChart's own
    /// `vargas` array for the same moment.
    @Test("Chart 1 - Sydney: computeVargaSnapshot(D3) matches computeChart's D3", arguments: [chart1Sydney])
    func chart1D3SnapshotMatchesFullCompute(_ chart: ReferenceChart) async throws {
        let full = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let fullD3 = try #require(full.vargas.first { $0.varga == .d3 })
        let snapshot = try await ChartCalculator.computeVargaSnapshot(
            varga: .d3, birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )

        #expect(snapshot == fullD3)
    }
}

/// D3 is trine-based (same/5th/9th sign by decan), and a sign's trine
/// partners always share its element -- so no point can ever cross
/// elements between D1 and D3. This is a structural property of the
/// formula itself, not something that needs hand-checking per point: if
/// it ever fails for any body/Ascendant on any reference chart, that's an
/// instant sign of a broken D3 formula, independent of the specific
/// expected D3 sign values already covered elsewhere.
@Suite("D3 invariant: same element/triplicity as D1")
struct D3TriplicityInvariantTests {
    @Test("Chart 1 - Sydney", arguments: [chart1Sydney])
    func chart1(_ chart: ReferenceChart) { assertD3SharesElement(chart) }

    @Test("Chart 2 - Reykjavik", arguments: [chart2Reykjavik])
    func chart2(_ chart: ReferenceChart) { assertD3SharesElement(chart) }

    @Test("Chart 3 - Mumbai", arguments: [chart3Mumbai])
    func chart3(_ chart: ReferenceChart) { assertD3SharesElement(chart) }

    private func assertD3SharesElement(_ chart: ReferenceChart) {
        for body in CelestialBody.allCases {
            let longitude = chart.expected[body]!.longitude
            let d1Sign = Rasi.containing(longitude: longitude)
            let d3Sign = DivisionalChart.d3.rasi(forLongitude: longitude)
            #expect(d3Sign.element == d1Sign.element, "\(body): D1=\(d1Sign) but D3=\(d3Sign)")
        }

        let d1Ascendant = Rasi.containing(longitude: chart.expectedAscendant)
        let d3Ascendant = DivisionalChart.d3.rasi(forLongitude: chart.expectedAscendant)
        #expect(d3Ascendant.element == d1Ascendant.element, "Ascendant: D1=\(d1Ascendant) but D3=\(d3Ascendant)")
    }
}
