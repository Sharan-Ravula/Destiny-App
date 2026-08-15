import CSwissEphemeris
import Foundation

/// Swiss Ephemeris's C API is not thread-safe: it relies on process-global
/// mutable state (e.g. the sidereal mode set via `swe_set_sid_mode`), not
/// per-instance state. Actor isolation only serializes calls made through
/// the *same* actor instance, so this must be a singleton -- two separate
/// `EphemerisEngine` instances calling concurrently would still race on the
/// same underlying C state. Always go through `.shared`.
public actor EphemerisEngine {
    public static let shared = EphemerisEngine()

    public enum EngineError: Error, Sendable {
        case calculationFailed(String)
        case housesFailed(String)
    }

    private var ephePathConfigured = false

    private init() {}

    public func planetaryPositions(
        date: Date,
        latitude: Double,
        longitude: Double,
        ayanamsa: Ayanamsa,
        nodeType: LunarNodeType = .mean
    ) throws -> [PlanetPosition] {
        configureEphePathIfNeeded()
        swe_set_sid_mode(ayanamsa.swissEphemerisMode, 0, 0)

        let jdUT = try julianDayUT(for: date)
        let flags: Int32 = SEFLG_SWIEPH | SEFLG_SIDEREAL | SEFLG_SPEED

        let bodies: [(CelestialBody, Int32)] = [
            (.sun, SE_SUN),
            (.moon, SE_MOON),
            (.mercury, SE_MERCURY),
            (.venus, SE_VENUS),
            (.mars, SE_MARS),
            (.jupiter, SE_JUPITER),
            (.saturn, SE_SATURN),
            (.rahu, nodeType == .mean ? SE_MEAN_NODE : SE_TRUE_NODE),
        ]

        var positions: [PlanetPosition] = []
        var rahuLongitude = 0.0
        var rahuSpeed = 0.0

        for (body, id) in bodies {
            let position = try calc(body: body, id: id, jdUT: jdUT, flags: flags)
            positions.append(position)
            if body == .rahu {
                rahuLongitude = position.siderealLongitude
                rahuSpeed = position.speedLongitude
            }
        }

        // Ketu is always 180 degrees from Rahu and, by convention, always
        // shown retrograde regardless of the (mean-node) speed sign.
        let ketuLongitude = (rahuLongitude + 180).truncatingRemainder(dividingBy: 360)
        positions.append(PlanetPosition(
            body: .ketu,
            siderealLongitude: ketuLongitude,
            eclipticLatitude: 0,
            speedLongitude: rahuSpeed,
            isRetrograde: true
        ))

        return positions
    }

    public func ascendant(
        date: Date,
        latitude: Double,
        longitude: Double,
        ayanamsa: Ayanamsa
    ) throws -> Double {
        configureEphePathIfNeeded()
        swe_set_sid_mode(ayanamsa.swissEphemerisMode, 0, 0)

        let jdUT = try julianDayUT(for: date)
        var cusps = [Double](repeating: 0, count: 13)
        var ascmc = [Double](repeating: 0, count: 10)
        let flags: Int32 = SEFLG_SWIEPH | SEFLG_SIDEREAL
        // House system char is irrelevant here: ascmc[0] (the Ascendant) is
        // computed the same way regardless of which system's cusps we ask
        // for. We derive whole-sign cusps ourselves in WholeSignHouses.swift
        // rather than trust swisseph's built-in 'W' system under sidereal
        // mode -- see that file for why.
        let hsys = Int32(Character("W").asciiValue!)

        let result = swe_houses_ex(jdUT, flags, latitude, longitude, hsys, &cusps, &ascmc)
        if result < 0 {
            throw EngineError.housesFailed("swe_houses_ex returned \(result)")
        }
        return ascmc[0]
    }

    private func calc(body: CelestialBody, id: Int32, jdUT: Double, flags: Int32) throws -> PlanetPosition {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let result = swe_calc_ut(jdUT, id, flags, &xx, &serr)
        if result < 0 {
            throw EngineError.calculationFailed(Self.string(fromErrorBuffer: serr))
        }
        let speed = xx[3]
        return PlanetPosition(
            body: body,
            siderealLongitude: xx[0],
            eclipticLatitude: xx[1],
            speedLongitude: speed,
            isRetrograde: speed < 0
        )
    }

    private func configureEphePathIfNeeded() {
        guard !ephePathConfigured else { return }
        if let url = Bundle.module.url(forResource: "Ephemeris", withExtension: nil) {
            swe_set_ephe_path(url.path)
        }
        ephePathConfigured = true
    }

    private func julianDayUT(for date: Date) throws -> Double {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let hour = comps.hour, let minute = comps.minute, let second = comps.second else {
            throw EngineError.calculationFailed("Could not decompose date into UTC components")
        }

        var dret = [Double](repeating: 0, count: 2)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_utc_to_jd(Int32(year), Int32(month), Int32(day), Int32(hour), Int32(minute), Double(second), SE_GREG_CAL, &dret, &serr)
        if rc < 0 {
            throw EngineError.calculationFailed(Self.string(fromErrorBuffer: serr))
        }
        return dret[1] // UT1 Julian day, as expected by swe_calc_ut / swe_houses_ex
    }

    private static func string(fromErrorBuffer buffer: [CChar]) -> String {
        buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }
}
