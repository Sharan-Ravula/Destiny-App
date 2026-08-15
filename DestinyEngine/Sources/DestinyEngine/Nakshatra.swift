public enum Nakshatra: Int, Codable, CaseIterable, Sendable {
    case ashwini, bharani, krittika, rohini, mrigashira, ardra, punarvasu, pushya, ashlesha
    case magha, purvaPhalguni, uttaraPhalguni, hasta, chitra, swati, vishakha, anuradha, jyeshtha
    case mula, purvaAshadha, uttaraAshadha, shravana, dhanishta, shatabhisha, purvaBhadrapada, uttaraBhadrapada, revati

    /// The Vimshottari 9-lord cycle -- both the nakshatra-lord assignment
    /// below and VimshottariDasha's mahadasha sequence are the same cycle,
    /// just applied differently, so it's shared rather than duplicated.
    public static let vimshottariLordCycle: [CelestialBody] = [.ketu, .venus, .sun, .moon, .mars, .rahu, .jupiter, .saturn, .mercury]

    /// Vimshottari dasha lord, cycling through the 9 lords 3 times across the 27 nakshatras.
    public var lord: CelestialBody {
        Self.vimshottariLordCycle[rawValue % 9]
    }

    public static let span = 360.0 / 27.0 // 13deg20'

    public static func containing(longitude: Double) -> Nakshatra {
        let index = Int(AngleMath.normalizedDegrees(longitude) / span)
        return Nakshatra(rawValue: min(index, 26))!
    }

    /// 1-4: which quarter (3deg20') of the nakshatra's own 13deg20' span
    /// this longitude falls in -- each pada corresponds to a specific
    /// Navamsa sign (the same 3deg20' division D9 itself uses), a
    /// standard column in most chart tables alongside nakshatra/lord.
    public static func pada(forLongitude longitude: Double) -> Int {
        let normalized = AngleMath.normalizedDegrees(longitude)
        let withinNakshatra = normalized.truncatingRemainder(dividingBy: span)
        let padaSpan = span / 4.0
        return min(Int(withinNakshatra / padaSpan), 3) + 1
    }
}
