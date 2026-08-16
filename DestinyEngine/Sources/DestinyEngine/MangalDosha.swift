/// Mangal (Kuja) Dosha: Mars in houses 1, 2, 4, 7, 8, or 12 counted from
/// Lagna only. (Previously also checked from Moon and Venus -- the de
/// facto convention in some software -- but narrowed to Lagna-only per
/// user request.)
public struct MangalDoshaResult: Codable, Sendable, Equatable {
    public let isPresent: Bool
    /// Whole-sign house (1-12) Mars occupies counted from Lagna --
    /// carried along regardless of isPresent so callers can display e.g.
    /// "1st house" without redoing the house math themselves.
    public let house: Int

    public init(isPresent: Bool, house: Int) {
        self.isPresent = isPresent
        self.house = house
    }
}

public enum MangalDosha {
    private static let afflictedHouses: Set<Int> = [1, 2, 4, 7, 8, 12]

    public static func evaluate(marsLongitude: Double, lagnaLongitude: Double) -> MangalDoshaResult {
        let house = WholeSignHouses.house(ascendantLongitude: lagnaLongitude, forLongitude: marsLongitude)
        return MangalDoshaResult(isPresent: afflictedHouses.contains(house), house: house)
    }
}
