import Foundation

enum AngleMath {
    /// Normalizes to 0..<360.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    static func degreeWithinSign(_ longitude: Double) -> Double {
        normalizedDegrees(longitude).truncatingRemainder(dividingBy: 30)
    }

    /// Shortest angular separation between two longitudes, 0...180.
    static func separation(_ a: Double, _ b: Double) -> Double {
        let raw = abs(normalizedDegrees(a) - normalizedDegrees(b))
        return raw > 180 ? 360 - raw : raw
    }
}
