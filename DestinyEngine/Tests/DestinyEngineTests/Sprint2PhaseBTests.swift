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
    @Test func marsInSecondFromVenusIsAfflicted() {
        // Venus at Pisces 28.6 (house 1), Mars at Aries 6.3 (house 2 from Venus).
        let result = MangalDosha.evaluate(marsLongitude: 6.33, lagnaLongitude: 200, moonLongitude: 100, venusLongitude: 358.6)
        #expect(result.fromVenus == true)
    }

    @Test func marsInThirdIsNotAfflicted() {
        // House 3 is not in the classical 1,2,4,7,8,12 list.
        let result = MangalDosha.evaluate(marsLongitude: 65, lagnaLongitude: 0, moonLongitude: 200, venusLongitude: 200)
        #expect(result.fromLagna == false)
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
        print("Mangal Dosha: fromLagna=\(summary.mangalDosha.fromLagna) fromMoon=\(summary.mangalDosha.fromMoon) fromVenus=\(summary.mangalDosha.fromVenus)")
        print("Sarpa Dosha present: \(summary.sarpaDosha.isPresent)")
        print("Aspects: \(summary.aspects.map { "\($0.from.rawValue)->\($0.toRasi) (\($0.houseNumber)) occupants=\($0.toOccupants.map(\.rawValue))" })")

        // Hand-derived from the already-validated Sprint 0 longitudes:
        // Pisces holds Sun/Mercury/Venus, Aries holds Mars/Rahu.
        #expect(summary.conjunctions.contains { $0.rasi == .pisces && Set($0.bodies) == [.sun, .mercury, .venus] })
        #expect(summary.conjunctions.contains { $0.rasi == .aries && Set($0.bodies) == [.mars, .rahu] })

        // Mars (Aries) is the 2nd house from Venus (Pisces) -- afflicted.
        // Not afflicted from Lagna (house 11) or Moon (house 5).
        #expect(summary.mangalDosha.fromVenus == true)
        #expect(summary.mangalDosha.fromLagna == false)
        #expect(summary.mangalDosha.fromMoon == false)

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
