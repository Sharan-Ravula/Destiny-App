/// Combustion (asta) orbs from BPHS (Brihat Parashara Hora Shastra, ch. 28),
/// as commonly reproduced across modern sources. The Sun cannot combust
/// itself and Rahu/Ketu (shadow points, no light of their own) are never
/// checked. Only Mars, Mercury, and Venus have distinct retrograde orbs in
/// the source material; Moon/Jupiter/Saturn use the same orb regardless of
/// motion.
public enum Combustion {
    private static let directOrbs: [CelestialBody: Double] = [
        .moon: 12, .mars: 17, .mercury: 14, .jupiter: 11, .venus: 10, .saturn: 15,
    ]
    private static let retrogradeOrbs: [CelestialBody: Double] = [
        .mars: 8, .mercury: 12, .venus: 8,
    ]

    public static func isCombust(body: CelestialBody, longitude: Double, sunLongitude: Double, isRetrograde: Bool) -> Bool {
        guard let orb = (isRetrograde ? retrogradeOrbs[body] : nil) ?? directOrbs[body] else {
            return false // Sun, Rahu, Ketu
        }
        return AngleMath.separation(longitude, sunLongitude) < orb
    }
}
