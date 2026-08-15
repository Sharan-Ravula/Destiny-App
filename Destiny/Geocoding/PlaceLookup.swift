import Foundation
import SQLite3

/// Fully offline place-of-birth search over a bundled GeoNames extract
/// (cities1000 + admin1CodesASCII + countryInfo, trimmed to just the
/// columns we need and pre-indexed at build time -- see VENDOR.md). No
/// network access, no CLGeocoder/MapKit.
final class PlaceLookup {
    static let shared = PlaceLookup()

    private var db: OpaquePointer?

    private init() {
        guard let url = Bundle.main.url(forResource: "GeoNamesCities", withExtension: "db") else {
            assertionFailure("GeoNamesCities.db missing from app bundle")
            return
        }
        // SQLITE_OPEN_READONLY: the bundled db is never written to at runtime.
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            assertionFailure("Failed to open GeoNamesCities.db")
            db = nil
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func search(prefix: String, limit: Int32 = 20) -> [PlaceSearchResult] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let db else { return [] }

        let sql = """
        SELECT c.name, a.name, co.name, c.latitude, c.longitude, c.timezone, c.population
        FROM cities c
        LEFT JOIN admin1 a ON a.code = c.country_code || '.' || c.admin1_code
        LEFT JOIN countries co ON co.code = c.country_code
        WHERE c.ascii_name LIKE ? || '%'
        ORDER BY c.population DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, trimmed, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_int(statement, 2, limit)

        var results: [PlaceSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 0))
            let admin1Name = sqlite3_column_text(statement, 1).map { String(cString: $0) }
            let countryName = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
            let latitude = sqlite3_column_double(statement, 3)
            let longitude = sqlite3_column_double(statement, 4)
            let timezone = String(cString: sqlite3_column_text(statement, 5))
            let population = Int(sqlite3_column_int64(statement, 6))

            results.append(PlaceSearchResult(
                name: name, admin1Name: admin1Name, countryName: countryName,
                latitude: latitude, longitude: longitude,
                timezoneIdentifier: timezone, population: population
            ))
        }
        return results
    }
}

/// SQLite's own SQLITE_TRANSIENT constant is a C macro ((sqlite3_destructor_type)-1)
/// that doesn't import into Swift automatically.
private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
