import Testing
import Foundation
@testable import DestinyEngine

// MARK: - Rasi

@Suite("Rasi")
struct RasiTests {
    @Test func boundaries() {
        #expect(Rasi.containing(longitude: 0) == .aries)
        #expect(Rasi.containing(longitude: 29.999) == .aries)
        #expect(Rasi.containing(longitude: 30) == .taurus)
        #expect(Rasi.containing(longitude: 359.999) == .pisces)
        #expect(Rasi.containing(longitude: 360) == .aries) // wraps
        #expect(Rasi.containing(longitude: 720 + 45) == .taurus) // >360 input normalizes
    }

    @Test func lordTable() {
        #expect(Rasi.aries.lord == .mars)
        #expect(Rasi.taurus.lord == .venus)
        #expect(Rasi.gemini.lord == .mercury)
        #expect(Rasi.cancer.lord == .moon)
        #expect(Rasi.leo.lord == .sun)
        #expect(Rasi.virgo.lord == .mercury)
        #expect(Rasi.libra.lord == .venus)
        #expect(Rasi.scorpio.lord == .mars)
        #expect(Rasi.sagittarius.lord == .jupiter)
        #expect(Rasi.capricorn.lord == .saturn)
        #expect(Rasi.aquarius.lord == .saturn)
        #expect(Rasi.pisces.lord == .jupiter)
    }
}

// MARK: - Nakshatra

@Suite("Nakshatra")
struct NakshatraTests {
    @Test func boundaries() {
        #expect(Nakshatra.containing(longitude: 0) == .ashwini)
        #expect(Nakshatra.containing(longitude: 13.32) == .ashwini)
        #expect(Nakshatra.containing(longitude: 13.34) == .bharani)
        #expect(Nakshatra.containing(longitude: 359.99) == .revati)
    }

    @Test func padaQuarters() {
        // Ashwini spans 0-13.32; each pada is 3.333deg.
        #expect(Nakshatra.pada(forLongitude: 0) == 1)
        #expect(Nakshatra.pada(forLongitude: 3.0) == 1)
        #expect(Nakshatra.pada(forLongitude: 3.34) == 2)
        #expect(Nakshatra.pada(forLongitude: 6.7) == 3)
        #expect(Nakshatra.pada(forLongitude: 10.1) == 4)
        #expect(Nakshatra.pada(forLongitude: 13.3) == 4)
        // Second nakshatra (Bharani, starts 13.34) resets to pada 1.
        #expect(Nakshatra.pada(forLongitude: 13.34) == 1)
    }

    @Test func lordCycleRepeatsEveryNine() {
        #expect(Nakshatra.ashwini.lord == .ketu)
        #expect(Nakshatra.bharani.lord == .venus)
        #expect(Nakshatra.ashlesha.lord == .mercury) // end of first cycle (index 8)
        #expect(Nakshatra.magha.lord == .ketu) // second cycle restarts (index 9)
        #expect(Nakshatra.purvaBhadrapada.lord == .jupiter) // index 24: 24 % 9 == 6 -> jupiter
        #expect(Nakshatra.revati.lord == .mercury) // index 26, last of third cycle
    }
}

// MARK: - Combustion

@Suite("Combustion")
struct CombustionTests {
    @Test func moonOrbTwelveDegreesNoRetrogradeVariant() {
        #expect(Combustion.isCombust(body: .moon, longitude: 11, sunLongitude: 0, isRetrograde: false))
        #expect(!Combustion.isCombust(body: .moon, longitude: 13, sunLongitude: 0, isRetrograde: false))
    }

    @Test func mercuryDirectVsRetrogradeOrbDiffers() {
        // 13 degrees separation: combust direct (orb 14), not combust retrograde (orb 12)
        #expect(Combustion.isCombust(body: .mercury, longitude: 13, sunLongitude: 0, isRetrograde: false))
        #expect(!Combustion.isCombust(body: .mercury, longitude: 13, sunLongitude: 0, isRetrograde: true))
    }

    @Test func marsDirectVsRetrogradeOrbDiffers() {
        #expect(Combustion.isCombust(body: .mars, longitude: 10, sunLongitude: 0, isRetrograde: false))
        #expect(Combustion.isCombust(body: .mars, longitude: 10, sunLongitude: 0, isRetrograde: true) == false)
    }

    @Test func sunRahuKetuNeverCombust() {
        #expect(!Combustion.isCombust(body: .sun, longitude: 0, sunLongitude: 0, isRetrograde: false))
        #expect(!Combustion.isCombust(body: .rahu, longitude: 0, sunLongitude: 0, isRetrograde: true))
        #expect(!Combustion.isCombust(body: .ketu, longitude: 0, sunLongitude: 0, isRetrograde: true))
    }

    @Test func wrapsAroundZero() {
        // 5 degrees apart across the 0/360 seam
        #expect(Combustion.isCombust(body: .jupiter, longitude: 358, sunLongitude: 3, isRetrograde: false))
    }
}

// MARK: - KarakaCalculator

@Suite("KarakaCalculator")
struct KarakaCalculatorTests {
    @Test func ranksByDescendingDegree() {
        let degrees: [CelestialBody: Double] = [
            .sun: 5, .moon: 25, .mars: 15, .mercury: 20, .jupiter: 10, .venus: 29, .saturn: 1,
        ]
        let result = KarakaCalculator.sevenKarakaAssignments(degreesWithinSign: degrees)
        #expect(result[.venus] == .atmaKaraka)
        #expect(result[.moon] == .amatyaKaraka)
        #expect(result[.mercury] == .bhratriKaraka)
        #expect(result[.mars] == .matriKaraka)
        #expect(result[.jupiter] == .putraKaraka)
        #expect(result[.sun] == .gnatiKaraka)
        #expect(result[.saturn] == .daraKaraka)
    }

    @Test func exactTieBreaksByFixedPlanetaryOrder() {
        // Sun and Moon tied -- Sun (earlier in Sun>Moon>Mars>Mercury>Jupiter>Venus>Saturn) wins the higher rank.
        let degrees: [CelestialBody: Double] = [
            .sun: 15, .moon: 15, .mars: 10, .mercury: 8, .jupiter: 6, .venus: 4, .saturn: 2,
        ]
        let result = KarakaCalculator.sevenKarakaAssignments(degreesWithinSign: degrees)
        #expect(result[.sun] == .atmaKaraka)
        #expect(result[.moon] == .amatyaKaraka)
    }
}

// MARK: - Full-chart integration against Sprint 0's validated reference charts

@Suite("ChartCalculator against Sprint 0 reference charts")
struct ChartCalculatorIntegrationTests {
    @Test("Chart 1 - Sydney: karakas, nakshatra, combustion", arguments: [chart1Sydney])
    func chart1(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        printTable(chart.name, computation)

        let byBody = Dictionary(uniqueKeysWithValues: computation.rows.map { ($0.body, $0) })
        // Hand-derived from Sprint 0's validated longitudes: degree-within-sign
        // ranking is Venus(28.6) > Mercury(19.0) > Moon(18.7) > Jupiter(14.2) >
        // Mars(6.32) > Saturn(4.42) > Sun(0.88).
        #expect(byBody[.venus]?.karaka == .atmaKaraka)
        #expect(byBody[.mercury]?.karaka == .amatyaKaraka)
        #expect(byBody[.moon]?.karaka == .bhratriKaraka)
        #expect(byBody[.jupiter]?.karaka == .matriKaraka)
        #expect(byBody[.mars]?.karaka == .putraKaraka)
        #expect(byBody[.saturn]?.karaka == .gnatiKaraka)
        #expect(byBody[.sun]?.karaka == .daraKaraka)

        // Sun at Pisces 0-53' falls in Purva Bhadrapada (lord Jupiter).
        #expect(byBody[.sun]?.nakshatra == .purvaBhadrapada)
        #expect(byBody[.sun]?.nakshatra.lord == .jupiter)

        // No planet is within orb of the Sun in this chart.
        for body: CelestialBody in [.moon, .mercury, .venus, .mars, .jupiter, .saturn] {
            #expect(byBody[body]?.isCombust == false, "\(body) unexpectedly combust")
        }
    }

    @Test("Chart 2 - Reykjavik: karakas, combustion (Mercury combust)", arguments: [chart2Reykjavik])
    func chart2(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        printTable(chart.name, computation)

        let byBody = Dictionary(uniqueKeysWithValues: computation.rows.map { ($0.body, $0) })
        // Degree-within-sign ranking: Saturn(29.93) > Jupiter(23.47) >
        // Mercury(23.05) > Mars(21.6) > Moon(18.03) > Sun(6.12) > Venus(2.12).
        #expect(byBody[.saturn]?.karaka == .atmaKaraka)
        #expect(byBody[.jupiter]?.karaka == .amatyaKaraka)
        #expect(byBody[.mercury]?.karaka == .bhratriKaraka)
        #expect(byBody[.mars]?.karaka == .matriKaraka)
        #expect(byBody[.moon]?.karaka == .putraKaraka)
        #expect(byBody[.sun]?.karaka == .gnatiKaraka)
        #expect(byBody[.venus]?.karaka == .daraKaraka)

        // Sun-Mercury separation ~13.07 degrees, under the 14-degree direct orb.
        #expect(byBody[.mercury]?.isCombust == true)
        for body: CelestialBody in [.moon, .venus, .mars, .jupiter, .saturn] {
            #expect(byBody[body]?.isCombust == false, "\(body) unexpectedly combust")
        }
    }

    @Test("Chart 3 - Mumbai: karakas, combustion (Moon combust)", arguments: [chart3Mumbai])
    func chart3(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        printTable(chart.name, computation)

        let byBody = Dictionary(uniqueKeysWithValues: computation.rows.map { ($0.body, $0) })
        // Degree-within-sign ranking: Mercury(28.12) > Moon(27.87) >
        // Mars(18.35) > Sun(16.45) > Saturn(11.27) > Venus(7.85) > Jupiter(4.22).
        #expect(byBody[.mercury]?.karaka == .atmaKaraka)
        #expect(byBody[.moon]?.karaka == .amatyaKaraka)
        #expect(byBody[.mars]?.karaka == .bhratriKaraka)
        #expect(byBody[.sun]?.karaka == .matriKaraka)
        #expect(byBody[.saturn]?.karaka == .putraKaraka)
        #expect(byBody[.venus]?.karaka == .gnatiKaraka)
        #expect(byBody[.jupiter]?.karaka == .daraKaraka)

        // Sun-Moon separation ~11.42 degrees (both in Libra), under the 12-degree orb.
        #expect(byBody[.moon]?.isCombust == true)
        for body: CelestialBody in [.mercury, .venus, .mars, .jupiter, .saturn] {
            #expect(byBody[body]?.isCombust == false, "\(body) unexpectedly combust")
        }
    }
}

private func printTable(_ name: String, _ computation: ChartComputation) {
    print("\n=== \(name) ===")
    print("Body     Lon      DegInSign  Rasi         RasiLord  Nakshatra           NakLord   R  C  Karaka")
    for row in computation.rows {
        print("\(row.body.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) "
            + "\(String(format: "%7.3f", row.absoluteLongitude))  "
            + "\(String(format: "%9.3f", row.degreeWithinSign))  "
            + "\(String(describing: row.rasi).padding(toLength: 12, withPad: " ", startingAt: 0)) "
            + "\(String(describing: row.rasi.lord).padding(toLength: 9, withPad: " ", startingAt: 0)) "
            + "\(String(describing: row.nakshatra).padding(toLength: 19, withPad: " ", startingAt: 0)) "
            + "\(String(describing: row.nakshatra.lord).padding(toLength: 9, withPad: " ", startingAt: 0)) "
            + "\(row.isRetrograde ? "^" : " ")  \(row.isCombust ? "*" : " ")  \(row.karaka?.rawValue ?? "")")
    }
    print("Ascendant: \(String(format: "%.3f", computation.ascendant.absoluteLongitude)) "
        + "\(computation.ascendant.rasi) / \(computation.ascendant.nakshatra) (lord \(computation.ascendant.nakshatra.lord))")
}
