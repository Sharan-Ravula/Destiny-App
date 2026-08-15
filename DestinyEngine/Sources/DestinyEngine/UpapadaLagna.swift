/// Upapada Lagna (UL / A12): the Arudha of the 12th house from Lagna, used
/// primarily for marriage/relationship significations in Jaimini. Same
/// BhavaArudha algorithm as Arudha Lagna, applied to house 12 instead of
/// house 1 -- no separate rule to source or confirm.
public enum UpapadaLagna {
    public static func compute(ascendantRasi: Rasi, lordPlacement: [CelestialBody: Rasi]) -> Rasi {
        BhavaArudha.compute(from: ascendantRasi.offset(11), lordPlacement: lordPlacement)
    }
}
