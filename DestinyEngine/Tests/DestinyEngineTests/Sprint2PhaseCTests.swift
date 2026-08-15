import Testing
import Foundation
@testable import DestinyEngine

@Suite("CharaDasha")
struct CharaDashaTests {
    @Test func lordInOwnSignIsAlwaysTwelveYears() {
        let placement: [CelestialBody: Rasi] = [.mars: .aries]
        #expect(CharaDasha.years(for: .aries, lordPlacement: placement) == 12)
    }

    @Test func exaltedLordAddsOneYear() {
        // Venus (Libra's lord) exalted in Pisces: base distance Libra(6)->Pisces(11)
        // odd sign, forward: (11-6+12)%12+1 = 6, +1 for exaltation = 7.
        let placement: [CelestialBody: Rasi] = [.venus: .pisces]
        #expect(CharaDasha.years(for: .libra, lordPlacement: placement) == 7)
    }

    @Test func debilitatedLordSubtractsOneYearFlooredAtOne() {
        // Jupiter (Sagittarius's lord) debilitated in Capricorn: base
        // distance Sagittarius(8)->Capricorn(9) odd, forward: 2, -1 = 1.
        let placement: [CelestialBody: Rasi] = [.jupiter: .capricorn]
        #expect(CharaDasha.years(for: .sagittarius, lordPlacement: placement) == 1)
    }

    @Test func oddSignCountsForwardEvenSignCountsBackward() {
        // Gemini (odd) lord Mercury in Leo (not Mercury's exalt/debil sign,
        // to isolate direction from the adjustment): forward count
        // Gemini->Leo = 3.
        #expect(CharaDasha.years(for: .gemini, lordPlacement: [.mercury: .leo]) == 3)
        // Cancer (even) lord Moon in Sagittarius (also not Moon's
        // exalt/debil sign): backward count Cancer->Sagittarius = 8.
        #expect(CharaDasha.years(for: .cancer, lordPlacement: [.moon: .sagittarius]) == 8)
    }

    @Test("Chart 1 - Sydney: full 12-sign Chara Dasha sequence", arguments: [chart1Sydney])
    func chart1Sequence(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let sequence = computation.charaDasha

        print("\n=== Chart 1 - Sydney: Chara Dasha sequence ===")
        for period in sequence {
            print("\(period.rasi) : \(period.years) years")
        }

        // Hand-derived from the already-validated D1 placements (Sun/Mercury/
        // Venus in Pisces, Moon in Sagittarius, Mars in Aries, Jupiter in
        // Capricorn, Saturn in Scorpio, Lagna Gemini -- odd, so sequence
        // runs forward: Gemini, Cancer, Leo, Virgo, Libra, Scorpio,
        // Sagittarius, Capricorn, Aquarius, Pisces, Aries, Taurus.
        let expected: [(Rasi, Double)] = [
            (.gemini, 9), (.cancer, 8), (.leo, 8), (.virgo, 6), (.libra, 7), (.scorpio, 8),
            (.sagittarius, 1), (.capricorn, 3), (.aquarius, 10), (.pisces, 2), (.aries, 12), (.taurus, 4),
        ]
        #expect(sequence.count == 12)
        for (period, (rasi, years)) in zip(sequence, expected) {
            #expect(period.rasi == rasi)
            #expect(period.years == years)
        }
        #expect(sequence[0].startDate == (try chart.moment.resolvedUTCDate()))
    }

    @Test("Chart 1 - Sydney: Chara Antardasha sub-periods", arguments: [chart1Sydney])
    func chart1Antardasha(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let sequence = computation.charaDasha

        // Every mahadasha's own span divides into 12 equal antardashas,
        // starting at the mahadasha's own rasi and running in the same
        // (Lagna-parity-fixed) forward/backward direction as the mahadasha
        // sequence itself -- not each antardasha rasi's own odd/even rule.
        for period in sequence {
            #expect(period.subPeriods.count == 12)
            let expectedSubYears = period.years / 12
            for subPeriod in period.subPeriods {
                #expect(subPeriod.years == expectedSubYears)
            }
            #expect(period.subPeriods.first?.startDate == period.startDate)
            #expect(period.subPeriods.last?.endDate == period.endDate)
        }

        // Gemini mahadasha (9 years, Lagna odd so forward direction):
        // antardashas run Gemini, Cancer, Leo, ... Taurus at 0.75 years each.
        let geminiSubRasis = sequence[0].subPeriods.map(\.rasi)
        #expect(geminiSubRasis == [
            .gemini, .cancer, .leo, .virgo, .libra, .scorpio,
            .sagittarius, .capricorn, .aquarius, .pisces, .aries, .taurus,
        ])
        #expect(sequence[0].subPeriods[0].years == 0.75)

        // Cancer mahadasha (8 years) -- antardasha still starts at Cancer
        // and still runs forward (the fixed sequence direction), even
        // though Cancer itself is an even sign.
        let cancerSubRasis = sequence[1].subPeriods.map(\.rasi)
        #expect(cancerSubRasis == [
            .cancer, .leo, .virgo, .libra, .scorpio, .sagittarius,
            .capricorn, .aquarius, .pisces, .aries, .taurus, .gemini,
        ])
    }

    @Test("Chart 1 - Sydney: Chara Pratyantardasha (3rd level) sub-periods", arguments: [chart1Sydney])
    func chart1Pratyantardasha(_ chart: ReferenceChart) async throws {
        let computation = try await ChartCalculator.computeChart(
            birthMoment: chart.moment, latitude: chart.latitude, longitude: chart.longitude
        )
        let sequence = computation.charaDasha

        // Same equal-12-way-split rule applied one level deeper: an
        // antardasha's own span divides into 12 pratyantardashas, starting
        // at the antardasha's own rasi, same fixed direction.
        let geminiAntardasha = sequence[0].subPeriods[0] // Gemini/Gemini, 0.75 years
        #expect(geminiAntardasha.rasi == .gemini)
        #expect(geminiAntardasha.subPeriods.count == 12)
        let pratyantardashaRasis = geminiAntardasha.subPeriods.map(\.rasi)
        #expect(pratyantardashaRasis == [
            .gemini, .cancer, .leo, .virgo, .libra, .scorpio,
            .sagittarius, .capricorn, .aquarius, .pisces, .aries, .taurus,
        ])
        #expect(geminiAntardasha.subPeriods[0].years == 0.75 / 12)
        #expect(geminiAntardasha.subPeriods[0].subPeriods.isEmpty) // stops at 3 levels
        #expect(geminiAntardasha.subPeriods.first?.startDate == geminiAntardasha.startDate)
        #expect(geminiAntardasha.subPeriods.last?.endDate == geminiAntardasha.endDate)
    }
}
