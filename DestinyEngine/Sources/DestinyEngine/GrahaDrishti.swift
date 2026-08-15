/// Graha drishti (planetary aspects). Confirmed with user before
/// implementation: the universal 7th-house aspect for all 7 classical
/// planets, plus special extra aspects for Mars (4th & 8th from itself),
/// Jupiter (5th & 9th), Saturn (3rd & 10th) -- all BPHS-standard, no
/// dispute. Rahu/Ketu get no special aspects (7th only), matching BPHS
/// literally. Re-confirmed with user after dedicated research: this is a
/// genuinely disputed area (KP and much North Indian practice give both
/// nodes Jupiter-style 5th/7th/9th; South Indian tradition differentiates
/// Rahu=Jupiter-style/Ketu=Mars-style) -- kept as 7th-only deliberately,
/// not by default/oversight.
public enum GrahaDrishti {
    /// Classical house-numbers (counted inclusively from the occupied
    /// house = 1) that a body aspects, always including 7.
    public static func aspectedHouseNumbers(for body: CelestialBody) -> [Int] {
        switch body {
        case .mars: return [4, 7, 8]
        case .jupiter: return [5, 7, 9]
        case .saturn: return [3, 7, 10]
        default: return [7]
        }
    }
}

/// Every aspect a body casts, whether or not anything actually occupies
/// the target house -- an aspect is a property of where the caster sits,
/// not of what happens to be sitting opposite it. `toOccupants` is how to
/// tell which of these happen to land on another planet.
public struct PlanetAspect: Codable, Sendable, Equatable {
    public let from: CelestialBody
    /// Classical house-number this aspect represents (3, 4, 5, 7, 8, 9, or 10).
    public let houseNumber: Int
    /// Absolute house (1-12, relative to the Ascendant) this aspect lands on.
    public let toHouse: Int
    public let toRasi: Rasi
    /// Bodies actually occupying toHouse, if any -- empty when the aspect
    /// lands on an unoccupied house.
    public let toOccupants: [CelestialBody]

    public init(from: CelestialBody, houseNumber: Int, toHouse: Int, toRasi: Rasi, toOccupants: [CelestialBody]) {
        self.from = from
        self.houseNumber = houseNumber
        self.toHouse = toHouse
        self.toRasi = toRasi
        self.toOccupants = toOccupants
    }
}
