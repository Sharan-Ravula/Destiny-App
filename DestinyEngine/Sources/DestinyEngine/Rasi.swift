public enum Rasi: Int, Codable, CaseIterable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    /// Classical rulership (no outer planets).
    public var lord: CelestialBody {
        switch self {
        case .aries: return .mars
        case .taurus: return .venus
        case .gemini: return .mercury
        case .cancer: return .moon
        case .leo: return .sun
        case .virgo: return .mercury
        case .libra: return .venus
        case .scorpio: return .mars
        case .sagittarius: return .jupiter
        case .capricorn: return .saturn
        case .aquarius: return .saturn
        case .pisces: return .jupiter
        }
    }

    public static func containing(longitude: Double) -> Rasi {
        let index = Int(AngleMath.normalizedDegrees(longitude) / 30)
        return Rasi(rawValue: min(index, 11))!
    }

    /// Aries, Cancer, Libra, Capricorn.
    public var isMovable: Bool { rawValue % 3 == 0 }
    /// Taurus, Leo, Scorpio, Aquarius.
    public var isFixed: Bool { rawValue % 3 == 1 }
    /// Gemini, Virgo, Sagittarius, Pisces.
    public var isDual: Bool { rawValue % 3 == 2 }

    /// True for Aries/Gemini/Leo/Libra/Sagittarius/Aquarius (odd in the
    /// traditional 1-indexed numbering, i.e. even rawValue here).
    public var isOdd: Bool { rawValue % 2 == 0 }

    public enum Element: Equatable {
        case fire, earth, air, water
    }

    /// Fire: Aries/Leo/Sagittarius. Earth: Taurus/Virgo/Capricorn.
    /// Air: Gemini/Libra/Aquarius. Water: Cancer/Scorpio/Pisces.
    public var element: Element {
        switch rawValue % 4 {
        case 0: return .fire
        case 1: return .earth
        case 2: return .air
        default: return .water
        }
    }

    /// Offset houses (0-11) counted forward, wrapping. Offset 0 = self.
    public func offset(_ houses: Int) -> Rasi {
        Rasi(rawValue: ((rawValue + houses) % 12 + 12) % 12)!
    }

    public enum Gender: Equatable {
        case male, female
    }

    /// Purusha (masculine) rashis are the odd-numbered signs in the
    /// traditional 1-indexed count -- Aries/Gemini/Leo/Libra/Sagittarius/
    /// Aquarius (isOdd above); Stri (feminine) rashis are the other six.
    /// A direct restatement of isOdd under its classical name, exposed
    /// separately so both read clearly on their own in serialized output.
    public var gender: Gender { isOdd ? .male : .female }

    public enum Direction: Equatable {
        case east, south, west, north
    }

    /// Dik (cardinal direction): Fire signs -> East, Earth -> South,
    /// Air -> West, Water -> North. Moderate confidence -- sourced from
    /// two independent secondary references (not a primary classical
    /// text), same sourcing tier as the D16/D60 caveats in
    /// DivisionalChart.swift. Distinct from the unrelated 8-direction
    /// Vastu Purusha Mandala scheme (Agni/Indra/Yama/etc.) -- don't
    /// conflate the two.
    public var direction: Direction {
        switch element {
        case .fire: return .east
        case .earth: return .south
        case .air: return .west
        case .water: return .north
        }
    }
}
