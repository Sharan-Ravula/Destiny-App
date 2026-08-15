public struct PlanetPosition: Codable, Sendable, Equatable {
    public let body: CelestialBody
    /// Sidereal ecliptic longitude, 0..<360.
    public let siderealLongitude: Double
    public let eclipticLatitude: Double
    /// Degrees/day. Negative means retrograde.
    public let speedLongitude: Double
    public let isRetrograde: Bool

    public init(body: CelestialBody, siderealLongitude: Double, eclipticLatitude: Double, speedLongitude: Double, isRetrograde: Bool) {
        self.body = body
        self.siderealLongitude = siderealLongitude
        self.eclipticLatitude = eclipticLatitude
        self.speedLongitude = speedLongitude
        self.isRetrograde = isRetrograde
    }
}
