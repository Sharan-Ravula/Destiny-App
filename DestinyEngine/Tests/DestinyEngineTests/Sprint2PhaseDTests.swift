import Testing
import Foundation
@testable import DestinyEngine

@Suite("RashiDrishti")
struct RashiDrishtiTests {
    @Test func movableExcludesTheFollowingFixedSign() {
        let aspected = RashiDrishti.aspectedSigns(for: .aries)
        #expect(Set(aspected) == [.leo, .scorpio, .aquarius])
        #expect(!aspected.contains(.taurus)) // adjacent fixed sign, excluded
    }

    @Test func fixedExcludesThePrecedingMovableSign() {
        let aspected = RashiDrishti.aspectedSigns(for: .scorpio)
        #expect(Set(aspected) == [.aries, .cancer, .capricorn])
        #expect(!aspected.contains(.libra)) // adjacent movable sign, excluded
    }

    @Test func dualAspectsOtherDualsNoException() {
        let aspected = RashiDrishti.aspectedSigns(for: .gemini)
        #expect(Set(aspected) == [.virgo, .sagittarius, .pisces])
    }
}

@Suite("ArudhaLagna")
struct ArudhaLagnaTests {
    @Test func lordInOwnHouseGivesTenthFromLagna() {
        // Lagna Aries, lord Mars in Aries itself (1st) -> exception ->
        // 10th from Lagna = Capricorn.
        let result = ArudhaLagna.compute(ascendantRasi: .aries, lordPlacement: [.mars: .aries])
        #expect(result == .capricorn)
    }

    @Test func lordInSeventhAlsoGivesTenthFromLagna() {
        // Lagna Aries, lord Mars in Libra (7th) -> raw lands back on Lagna
        // itself -> same exception -> 10th from Lagna = Capricorn.
        let result = ArudhaLagna.compute(ascendantRasi: .aries, lordPlacement: [.mars: .libra])
        #expect(result == .capricorn)
    }
}

@Suite("UpapadaLagna")
struct UpapadaLagnaTests {
    @Test func sameAlgorithmAppliedToTwelfthHouse() {
        // 12th from Aries is Pisces. Pisces's lord Jupiter placed in Cancer:
        // offsetToLord = (3-11+12)%12 = 4, raw = Pisces.offset(8) = Scorpio,
        // no exception (doesn't land on Pisces or its 7th, Virgo).
        let result = UpapadaLagna.compute(ascendantRasi: .aries, lordPlacement: [.jupiter: .cancer])
        #expect(result == .scorpio)
    }
}

@Suite("Phase D against Sprint 0 reference charts")
struct Sprint2PhaseDReferenceTests {
    @Test("Chart 1 - Sydney: Karakamsa, Arudha Lagna, Rashi aspects", arguments: [chart1Sydney])
    func chart1(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let summary = computation.summary

        print("\n=== Chart 1 - Sydney: Phase D ===")
        print("Karakamsa: \(String(describing: summary.karakamsa))")
        print("Arudha Lagna: \(summary.arudhaLagna)")
        print("Upapada Lagna: \(summary.upapadaLagna)")
        print("Rashi aspects: \(summary.rashiAspects.map { "\($0.fromRasi)->\($0.toRasi)" })")

        // AK = Venus (Sprint 1), Venus's D9 = Pisces (Phase A printout).
        #expect(summary.karakamsa == .pisces)

        // Lagna Gemini, lord Mercury in Pisces: offsetToLord = 9, raw =
        // Gemini.offset(18 % 12 = 6) = Sagittarius = Lagna's own 7th house
        // -> exception -> 10th from that landed position = Virgo.
        #expect(summary.arudhaLagna == .virgo)

        // 12th from Gemini is Taurus, lord Venus in Pisces: offsetToLord =
        // 10, raw = Taurus.offset(20 % 12 = 8) = Capricorn, no exception.
        #expect(summary.upapadaLagna == .capricorn)

        // All 12 Arudha Padas (A1-A12) must agree with the two individually-
        // computed convenience fields at their respective indices.
        #expect(summary.arudhaPadas.count == 12)
        #expect(summary.arudhaPadas[0] == summary.arudhaLagna)
        #expect(summary.arudhaPadas[11] == summary.upapadaLagna)

        // Occupied rasis: Pisces (Sun/Mercury/Venus), Sagittarius (Moon),
        // Aries (Mars/Rahu), Capricorn (Jupiter), Scorpio (Saturn), Libra
        // (Ketu). Every occupied sign casts all 3 of its rashi drishti
        // targets regardless of whether the target itself is occupied --
        // dual signs (Pisces/Sagittarius) aspect the other 2 duals aside
        // from each other (Gemini, Virgo, and each other); movable signs
        // (Aries/Capricorn/Libra) aspect all 4 fixed signs except the one
        // immediately following; Scorpio (fixed) aspects all 4 movable
        // signs except the one immediately preceding (Libra).
        let aspectPairs = Set(summary.rashiAspects.map { "\($0.fromRasi)->\($0.toRasi)" })
        #expect(aspectPairs == [
            "pisces->gemini", "pisces->virgo", "pisces->sagittarius",
            "sagittarius->gemini", "sagittarius->virgo", "sagittarius->pisces",
            "aries->leo", "aries->scorpio", "aries->aquarius",
            "capricorn->taurus", "capricorn->leo", "capricorn->scorpio",
            "scorpio->aries", "scorpio->cancer", "scorpio->capricorn",
            "libra->taurus", "libra->leo", "libra->aquarius",
        ])
    }
}
