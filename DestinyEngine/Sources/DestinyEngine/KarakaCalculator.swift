public enum KarakaCalculator {
    /// Fixed precedence for the (practically unreachable, since we compare
    /// full double-precision degrees) case of an exact tie -- matches the
    /// convention cited for Jagannatha Hora / Parashara's Light.
    private static let fixedPriorityOrder: [CelestialBody] = [.sun, .moon, .mars, .mercury, .jupiter, .venus, .saturn]

    private static let rolesByRank: [KarakaRole] = [
        .atmaKaraka, .amatyaKaraka, .bhratriKaraka, .matriKaraka, .putraKaraka, .gnatiKaraka, .daraKaraka,
    ]

    /// - Parameter degreesWithinSign: degree-within-sign (0..<30) for exactly
    ///   the 7 classical planets (Sun through Saturn).
    public static func sevenKarakaAssignments(degreesWithinSign: [CelestialBody: Double]) -> [CelestialBody: KarakaRole] {
        let ranked = fixedPriorityOrder
            .compactMap { body -> (body: CelestialBody, degree: Double)? in
                guard let degree = degreesWithinSign[body] else { return nil }
                return (body, degree)
            }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.degree != rhs.element.degree {
                    return lhs.element.degree > rhs.element.degree
                }
                return lhs.offset < rhs.offset // fixedPriorityOrder tiebreak
            }
            .map(\.element)

        var assignments: [CelestialBody: KarakaRole] = [:]
        for (rank, entry) in ranked.enumerated() where rank < rolesByRank.count {
            assignments[entry.body] = rolesByRank[rank]
        }
        return assignments
    }
}
