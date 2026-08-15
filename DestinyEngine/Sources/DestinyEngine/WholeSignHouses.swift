import Foundation

/// Vedic whole-sign houses: house N is exactly the Nth sign counted from the
/// Ascendant's sign, with no sub-division within a sign.
///
/// Swiss Ephemeris's built-in 'W' house system, when combined with
/// SEFLG_SIDEREAL, computes cusps in the tropical frame first and only then
/// shifts the whole set by the ayanamsa. That shift does NOT land cusps back
/// on exact sign boundaries -- it produces sidereal-shifted versions of what
/// were tropical whole-sign cusps, which is wrong for sidereal whole-sign.
/// So we don't call swe_houses_ex for cusps at all; we take the (correctly
/// sidereal) Ascendant longitude from EphemerisEngine.ascendant and derive
/// whole-sign house numbers ourselves, which is unambiguous.
public enum WholeSignHouses {
    /// 0-11, 0 = Aries.
    public static func signIndex(forLongitude longitude: Double) -> Int {
        let normalized = longitude.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return Int(positive / 30.0)
    }

    /// 1-12.
    public static func house(ascendantLongitude: Double, forLongitude longitude: Double) -> Int {
        let ascendantSign = signIndex(forLongitude: ascendantLongitude)
        let bodySign = signIndex(forLongitude: longitude)
        return ((bodySign - ascendantSign + 12) % 12) + 1
    }
}
