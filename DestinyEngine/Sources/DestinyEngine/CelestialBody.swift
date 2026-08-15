import CSwissEphemeris

public enum CelestialBody: String, CaseIterable, Codable, Sendable {
    case sun, moon, mercury, venus, mars, jupiter, saturn, rahu, ketu
}

/// Whether the lunar nodes (Rahu/Ketu) are computed as the mean node or the
/// osculating true node. Classical Vedic sources disagree on which to use;
/// this is picked empirically per Sprint 0 validation against reference charts.
public enum LunarNodeType: String, Codable, Sendable {
    case mean
    case trueNode
}
