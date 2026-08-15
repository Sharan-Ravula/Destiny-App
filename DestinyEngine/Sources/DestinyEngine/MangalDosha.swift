/// Mangal (Kuja) Dosha: Mars in houses 1, 2, 4, 7, 8, or 12 -- checked
/// independently from Lagna, Moon, and Venus (afflicted from any one of
/// the three counts as present). Confirmed with user before
/// implementation: the de facto universal software convention, though not
/// traceable to a single BPHS verse (the direct BPHS citation found was
/// narrower -- Mars in 7th, for female nativities specifically, ch. 81).
public struct MangalDoshaResult: Codable, Sendable, Equatable {
    public let fromLagna: Bool
    public let fromMoon: Bool
    public let fromVenus: Bool

    public var isPresent: Bool { fromLagna || fromMoon || fromVenus }

    public init(fromLagna: Bool, fromMoon: Bool, fromVenus: Bool) {
        self.fromLagna = fromLagna
        self.fromMoon = fromMoon
        self.fromVenus = fromVenus
    }
}

public enum MangalDosha {
    private static let afflictedHouses: Set<Int> = [1, 2, 4, 7, 8, 12]

    public static func evaluate(marsLongitude: Double, lagnaLongitude: Double, moonLongitude: Double, venusLongitude: Double) -> MangalDoshaResult {
        MangalDoshaResult(
            fromLagna: afflictedHouses.contains(WholeSignHouses.house(ascendantLongitude: lagnaLongitude, forLongitude: marsLongitude)),
            fromMoon: afflictedHouses.contains(WholeSignHouses.house(ascendantLongitude: moonLongitude, forLongitude: marsLongitude)),
            fromVenus: afflictedHouses.contains(WholeSignHouses.house(ascendantLongitude: venusLongitude, forLongitude: marsLongitude))
        )
    }
}
