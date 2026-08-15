import Foundation

/// Varga (divisional chart) sign-mapping formulas, BPHS-derived. Every
/// varga divides each 30-degree sign into N equal parts (D30 is the one
/// exception -- 5 unequal parts) and maps each part to a resulting sign;
/// what differs between vargas is which sign each part maps to.
///
/// D16's start-triad rule and D60's part-index formula are the two
/// lowest-confidence items from research (single/inconsistent secondary
/// sourcing, no primary text reached) -- unverified, cross-check against
/// an external reference site planned once Sprint 2 Phases A-D are
/// complete (per user, 2026-08-14), not an open-ended gap.
public enum DivisionalChart: String, Sendable, CaseIterable, Codable {
    case d1 = "D1", d2 = "D2", d3 = "D3", d4 = "D4", d7 = "D7", d9 = "D9", d10 = "D10", d12 = "D12"
    case d16 = "D16", d20 = "D20", d24 = "D24", d27 = "D27", d30 = "D30", d40 = "D40", d45 = "D45", d60 = "D60"

    public var divisionsPerSign: Int {
        switch self {
        case .d1: return 1
        case .d2: return 2
        case .d3: return 3
        case .d4: return 4
        case .d7: return 7
        case .d9: return 9
        case .d10: return 10
        case .d12: return 12
        case .d16: return 16
        case .d20: return 20
        case .d24: return 24
        case .d27: return 27
        case .d30: return 30 // unequal parts -- see d30Rasi
        case .d40: return 40
        case .d45: return 45
        case .d60: return 60
        }
    }

    public func rasi(forLongitude longitude: Double) -> Rasi {
        let sign = Rasi.containing(longitude: longitude)
        let degreeInSign = AngleMath.degreeWithinSign(longitude)

        switch self {
        case .d1:
            return sign
        case .d2:
            return Self.d2Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d3:
            return Self.trinePart(sign: sign, degreeInSign: degreeInSign)
        case .d4:
            return Self.kendraPart(sign: sign, degreeInSign: degreeInSign)
        case .d7:
            return Self.d7Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d9:
            return Self.d9Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d10:
            return Self.d10Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d12:
            return Self.samePart(sign: sign, degreeInSign: degreeInSign, partSize: 2.5)
        case .d16:
            return Self.triadFromZero(sign: sign, degreeInSign: degreeInSign, partSize: 30.0 / 16)
        case .d20:
            return Self.d20Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d24:
            return Self.d24Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d27:
            return Self.d27Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d30:
            return Self.d30Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d40:
            return Self.d40Rasi(sign: sign, degreeInSign: degreeInSign)
        case .d45:
            return Self.triadFromZero(sign: sign, degreeInSign: degreeInSign, partSize: 30.0 / 45)
        case .d60:
            return Self.d60Rasi(sign: sign, degreeInSign: degreeInSign)
        }
    }

    /// Where within the *resulting* varga sign this longitude falls,
    /// scaled to fill the full 0-30 range -- e.g. 3.5 degrees into D3's 3rd
    /// 10-degree-wide part becomes 10.5 degrees in the resulting D3 sign.
    /// Confirmed with user before implementation: there's no single
    /// classical convention for a varga "degree", so this uses the most
    /// common software approach (proportional position within whichever
    /// division determined the resulting sign) -- consistent across every
    /// varga including D30's unequal-width divisions.
    public func degreeWithinResultingSign(forLongitude longitude: Double) -> Double {
        let sign = Rasi.containing(longitude: longitude)
        let degreeInSign = AngleMath.degreeWithinSign(longitude)

        if self == .d1 {
            return degreeInSign
        }
        if self == .d30 {
            return Self.d30DegreeWithinResultingSign(sign: sign, degreeInSign: degreeInSign)
        }
        let partSize = 30.0 / Double(divisionsPerSign)
        return degreeInSign.truncatingRemainder(dividingBy: partSize) / partSize * 30.0
    }

    // MARK: - Helpers

    private static func partIndex(_ degreeInSign: Double, partSize: Double) -> Int {
        Int(degreeInSign / partSize)
    }

    /// Always counts from the sign itself, regardless of odd/even (D12).
    private static func samePart(sign: Rasi, degreeInSign: Double, partSize: Double) -> Rasi {
        sign.offset(partIndex(degreeInSign, partSize: partSize))
    }

    /// Movable->Aries, Fixed->Leo/Sagittarius family starting at rawValue 0,
    /// i.e. counted from Aries itself rather than from the occupied sign
    /// (D16, D45's triad start, which both begin their fixed/dual anchors
    /// at Leo/Sagittarius rather than "9th/5th from the occupied sign").
    private static func triadFromZero(sign: Rasi, degreeInSign: Double, partSize: Double) -> Rasi {
        let start: Rasi = sign.isMovable ? .aries : (sign.isFixed ? .leo : .sagittarius)
        return start.offset(partIndex(degreeInSign, partSize: partSize))
    }

    /// D3: same sign, then trine (5th, 9th) -- offsets of 0, 4, 8.
    private static func trinePart(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 10)
        return sign.offset(part * 4)
    }

    /// D4: same sign, then kendra (4th, 7th, 10th) -- offsets of 0, 3, 6, 9.
    private static func kendraPart(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 7.5)
        return sign.offset(part * 3)
    }

    private static func d2Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let firstHalf = degreeInSign < 15
        if sign.isOdd {
            return firstHalf ? .leo : .cancer
        } else {
            return firstHalf ? .cancer : .leo
        }
    }

    private static func d7Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let partSize = 30.0 / 7
        let part = partIndex(degreeInSign, partSize: partSize)
        let start = sign.isOdd ? sign : sign.offset(6)
        return start.offset(part)
    }

    private static func d9Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let partSize = 30.0 / 9
        let part = partIndex(degreeInSign, partSize: partSize)
        let start: Rasi = sign.isMovable ? sign : (sign.isFixed ? sign.offset(8) : sign.offset(4))
        return start.offset(part)
    }

    private static func d10Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 3)
        let start = sign.isOdd ? sign : sign.offset(8)
        return start.offset(part)
    }

    private static func d20Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 1.5)
        let start: Rasi = sign.isMovable ? .aries : (sign.isFixed ? .sagittarius : .leo)
        return start.offset(part)
    }

    private static func d24Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 1.25)
        let start: Rasi = sign.isOdd ? .leo : .cancer
        return start.offset(part)
    }

    private static func d27Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let partSize = 30.0 / 27
        let part = partIndex(degreeInSign, partSize: partSize)
        let start: Rasi
        switch sign.element {
        case .fire: start = .aries
        case .earth: start = .cancer
        case .air: start = .libra
        case .water: start = .capricorn
        }
        return start.offset(part)
    }

    /// Each ruler's width is fixed regardless of position: Mars 5deg,
    /// Saturn 5deg, Jupiter 8deg, Mercury 7deg, Venus 5deg. Odd signs
    /// apply them in that order starting from Aries (Mars' own sign);
    /// even signs apply the same five widths in reverse ruler order,
    /// starting from Libra (Venus' own sign).
    private static func d30Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let oddOrder: [(width: Double, land: Rasi)] = [
            (5, .aries), (5, .aquarius), (8, .sagittarius), (7, .gemini), (5, .libra),
        ]
        let evenOrder: [(width: Double, land: Rasi)] = [
            (5, .libra), (7, .gemini), (8, .sagittarius), (5, .aquarius), (5, .aries),
        ]
        let sequence = sign.isOdd ? oddOrder : evenOrder
        var cursor = 0.0
        for entry in sequence {
            if degreeInSign < cursor + entry.width {
                return entry.land
            }
            cursor += entry.width
        }
        return sequence.last!.land
    }

    /// Same odd/even width sequence as d30Rasi, but returning how far
    /// through whichever ruler's segment the degree falls, scaled to 0-30.
    private static func d30DegreeWithinResultingSign(sign: Rasi, degreeInSign: Double) -> Double {
        let oddWidths: [Double] = [5, 5, 8, 7, 5]
        let evenWidths: [Double] = [5, 7, 8, 5, 5]
        let widths = sign.isOdd ? oddWidths : evenWidths
        var cursor = 0.0
        for width in widths {
            if degreeInSign < cursor + width {
                return (degreeInSign - cursor) / width * 30.0
            }
            cursor += width
        }
        return 30.0
    }

    private static func d40Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 0.75)
        let start: Rasi = sign.isOdd ? .aries : .libra
        return start.offset(part)
    }

    /// 60 parts of 0.5deg each; part index mod 12 gives the offset from
    /// the occupied sign (own sign repeats every 12 parts, so exactly 5
    /// full cycles through all 12 signs across the 60 parts).
    private static func d60Rasi(sign: Rasi, degreeInSign: Double) -> Rasi {
        let part = partIndex(degreeInSign, partSize: 0.5)
        return sign.offset(part % 12)
    }
}
