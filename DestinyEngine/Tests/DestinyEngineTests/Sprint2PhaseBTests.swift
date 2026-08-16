import Testing
import Foundation
@testable import DestinyEngine

@Suite("GrahaDrishti")
struct GrahaDrishtiTests {
    @Test func specialAspects() {
        #expect(GrahaDrishti.aspectedHouseNumbers(for: .mars) == [4, 7, 8])
        #expect(GrahaDrishti.aspectedHouseNumbers(for: .jupiter) == [5, 7, 9])
        #expect(GrahaDrishti.aspectedHouseNumbers(for: .saturn) == [3, 7, 10])
    }

    @Test func everyoneElseIsSeventhOnly() {
        for body: CelestialBody in [.sun, .moon, .mercury, .venus, .rahu, .ketu] {
            #expect(GrahaDrishti.aspectedHouseNumbers(for: body) == [7])
        }
    }
}

@Suite("MangalDosha")
struct MangalDoshaTests {
    @Test func marsInFirstFromLagnaIsAfflicted() {
        // Lagna at Aries 0 (house 1), Mars at Aries 6.3 -- also house 1.
        let result = MangalDosha.evaluate(marsLongitude: 6.33, lagnaLongitude: 0)
        #expect(result.isPresent == true)
        #expect(result.house == 1)
    }

    @Test func marsInThirdIsNotAfflicted() {
        // House 3 is not in the classical 1,2,4,7,8,12 list.
        let result = MangalDosha.evaluate(marsLongitude: 65, lagnaLongitude: 0)
        #expect(result.isPresent == false)
        #expect(result.house == 3)
    }
}

@Suite("SarpaDosha")
struct SarpaDoshaTests {
    // Ranges: Cancer 10-30, Scorpio 0-20, Pisces 20-30 (degree-within-sign).
    @Test func cancerRangeBoundaries() {
        #expect(SarpaDosha.evaluate(longitudes: [.sun: 90 + 9.999]).isPresent == false) // just before 10
        #expect(SarpaDosha.evaluate(longitudes: [.sun: 90 + 10]).isPresent == true) // exactly 10, inclusive
        #expect(SarpaDosha.evaluate(longitudes: [.sun: 90 + 29.999]).isPresent == true) // just before 30
    }

    @Test func scorpioRangeBoundaries() {
        #expect(SarpaDosha.evaluate(longitudes: [.moon: 210 + 0]).isPresent == true) // exactly 0, inclusive
        #expect(SarpaDosha.evaluate(longitudes: [.moon: 210 + 19.999]).isPresent == true)
        #expect(SarpaDosha.evaluate(longitudes: [.moon: 210 + 20]).isPresent == false) // exactly 20, exclusive
    }

    @Test func piscesRangeBoundaries() {
        #expect(SarpaDosha.evaluate(longitudes: [.mars: 330 + 19.999]).isPresent == false)
        #expect(SarpaDosha.evaluate(longitudes: [.mars: 330 + 20]).isPresent == true)
        #expect(SarpaDosha.evaluate(longitudes: [.mars: 330 + 29.999]).isPresent == true)
    }

    @Test func otherSignsNeverTrigger() {
        let longitudes: [CelestialBody: Double] = [
            .sun: 15, .moon: 45, .mars: 75, .mercury: 135, .jupiter: 165, .venus: 195, .saturn: 255, .rahu: 285, .ketu: 315,
        ]
        #expect(SarpaDosha.evaluate(longitudes: longitudes).isPresent == false)
    }
}

@Suite("ChartSummary against Sprint 0 reference charts")
struct ChartSummaryReferenceTests {
    @Test("Chart 1 - Sydney: conjunctions, aspects, doshas", arguments: [chart1Sydney])
    func chart1(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let summary = computation.summary

        print("\n=== Chart 1 - Sydney: Summary ===")
        print("Conjunctions: \(summary.conjunctions.map { "\($0.rasi): \($0.bodies.map(\.rawValue))" })")
        print("Mangal Dosha present (Lagna-only): \(summary.mangalDosha.isPresent)")
        print("Sarpa Dosha present: \(summary.sarpaDosha.isPresent)")
        print("Aspects: \(summary.aspects.map { "\($0.from.rawValue)->\($0.toRasi) (\($0.houseNumber)) occupants=\($0.toOccupants.map(\.rawValue))" })")

        // Hand-derived from the already-validated Sprint 0 longitudes:
        // Pisces holds Sun/Mercury/Venus, Aries holds Mars/Rahu.
        #expect(summary.conjunctions.contains { $0.rasi == .pisces && Set($0.bodies) == [.sun, .mercury, .venus] })
        #expect(summary.conjunctions.contains { $0.rasi == .aries && Set($0.bodies) == [.mars, .rahu] })

        // Mars (Aries) is house 11 from Lagna -- not in the afflicted
        // {1,2,4,7,8,12} set, so Mangal Dosha (Lagna-only) is absent here,
        // even though Mars would be afflicted counted from Venus (no
        // longer checked).
        #expect(summary.mangalDosha.isPresent == false)

        // Venus at Pisces 28.6 (in [20,30)) and Saturn at Scorpio 4.4 (in
        // [0,20)) both fall in a Sarpa range; nobody else does.
        #expect(summary.sarpaDosha.isPresent == true)
        #expect(Set(summary.sarpaDosha.triggeringBodies) == [.venus, .saturn])

        // Saturn (Scorpio, house 6) aspects house 8 (Capricorn) via its
        // 3rd-from-self special aspect, landing on Jupiter.
        #expect(summary.aspects.contains { $0.from == .saturn && $0.toOccupants.contains(.jupiter) && $0.houseNumber == 3 })
    }

    @Test("Chart 2 - Reykjavik: Sarpa Dosha (Mars + Ketu)", arguments: [chart2Reykjavik])
    func chart2SarpaDosha(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        // Mars at Pisces 21.6 (in [20,30)) and Ketu at Cancer 15.65 (in
        // [10,30)) both fall in a Sarpa range.
        #expect(computation.summary.sarpaDosha.isPresent == true)
        #expect(Set(computation.summary.sarpaDosha.triggeringBodies) == [.mars, .ketu])
    }

    @Test("Chart 3 - Mumbai: Sarpa Dosha (Mars only)", arguments: [chart3Mumbai])
    func chart3SarpaDosha(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        // Mars at Scorpio 18.35 (in [0,20)) is the only body in a Sarpa range.
        #expect(computation.summary.sarpaDosha.isPresent == true)
        #expect(Set(computation.summary.sarpaDosha.triggeringBodies) == [.mars])
    }
}
