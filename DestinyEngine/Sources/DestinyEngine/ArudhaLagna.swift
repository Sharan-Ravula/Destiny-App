/// Arudha of a house (BPHS/Jaimini), generalized: count from the house to
/// its lord's current placement (N houses, inclusive), then count N again
/// forward from the lord's position -- that's the raw Arudha. Exception:
/// if the raw result lands in the house itself or the 7th from it, move
/// to the 10th house from that landed position instead. This same rule
/// subsumes the commonly-cited special case ("if the lord sits in the 1st
/// or 7th house [from the house in question], the Arudha is directly the
/// 10th from it") without needing separate handling -- both a self-placed
/// and a 7th-placed lord land the raw count back on the house itself.
public enum BhavaArudha {
    public static func compute(from house: Rasi, lordPlacement: [CelestialBody: Rasi]) -> Rasi {
        let lord = house.lord
        guard let lordRasi = lordPlacement[lord] else { return house }

        let offsetToLord = (lordRasi.rawValue - house.rawValue + 12) % 12
        let raw = house.offset(2 * offsetToLord)

        if raw == house || raw == house.offset(6) {
            return raw.offset(9)
        }
        return raw
    }
}

/// Arudha Lagna (A1): the Arudha of the 1st house (Lagna). Confirmed with
/// user before implementation, no disagreement found across sources.
public enum ArudhaLagna {
    public static func compute(ascendantRasi: Rasi, lordPlacement: [CelestialBody: Rasi]) -> Rasi {
        BhavaArudha.compute(from: ascendantRasi, lordPlacement: lordPlacement)
    }
}
