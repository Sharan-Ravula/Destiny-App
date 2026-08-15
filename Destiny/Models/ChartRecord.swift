import Foundation
import DestinyEngine

struct ChartInput: Codable, Equatable {
    var name: String
    var placeName: String
    var latitude: Double
    var longitude: Double
    var birthMoment: BirthMoment
    var gender: Gender?

    init(name: String, placeName: String, latitude: Double, longitude: Double, birthMoment: BirthMoment, gender: Gender?) {
        self.name = name
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.birthMoment = birthMoment
        self.gender = gender
    }

    private enum CodingKeys: String, CodingKey {
        case name, placeName, latitude, longitude, birthMoment, gender
    }

    /// Custom decode so charts saved while latitude/longitude briefly lived
    /// elsewhere (or didn't exist as separate fields yet) still load instead
    /// of throwing a missing-key error -- ChartFile's own decoder recovers
    /// the real values for that specific case; this just keeps a bare
    /// decode of `input` from crashing. gender is decodeIfPresent (nil for
    /// files saved before it existed) via the same optional-property
    /// synthesis Codable would have used automatically.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        placeName = try container.decode(String.self, forKey: .placeName)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        birthMoment = try container.decode(BirthMoment.self, forKey: .birthMoment)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    }
}

/// Exactly what's written to disk: the chart's own facts, plus an id (so
/// editing a chart's name/DOB still updates the same file/entry in place)
/// and the engine version that last saved it. The computed chart itself is
/// deliberately NOT persisted -- ChartStore recomputes it fresh from
/// `input` every time a chart is loaded (see ChartStore.load), so this file
/// stays small and holds only what a person actually typed in.
struct ChartFile: Codable {
    var id: UUID?
    var engineVersion: String?
    var input: ChartInput

    init(id: UUID?, engineVersion: String?, input: ChartInput) {
        self.id = id
        self.engineVersion = engineVersion
        self.input = input
    }

    private enum CodingKeys: String, CodingKey {
        case id, engineVersion, input, computation
    }

    /// id/engineVersion are decodeIfPresent -- older files didn't have them
    /// at the top level at all (ChartStore.load backfills id from the
    /// chart's already-known ChartIndexEntry in that case).
    ///
    /// Briefly (one round of changes), latitude/longitude lived nested
    /// under a "computation" block instead of `input` -- that block isn't
    /// modeled here at all anymore, but if `input` came back with
    /// latitude/longitude defaulted to 0 (ChartInput's own lenient decode),
    /// this recovers the real values from "computation" if present, so
    /// charts saved during that round don't silently end up computed for
    /// the wrong location.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        engineVersion = try container.decodeIfPresent(String.self, forKey: .engineVersion)
        var decodedInput = try container.decode(ChartInput.self, forKey: .input)
        if decodedInput.latitude == 0, decodedInput.longitude == 0,
           let legacy = try? container.decode(LegacyComputationCoordinates.self, forKey: .computation) {
            decodedInput.latitude = legacy.latitude
            decodedInput.longitude = legacy.longitude
        }
        input = decodedInput
    }

    /// Written manually (not synthesized) since CodingKeys includes
    /// `computation`, which has no corresponding stored property -- this
    /// never writes a "computation" key, only id/engineVersion/input.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(engineVersion, forKey: .engineVersion)
        try container.encode(input, forKey: .input)
    }
}

private struct LegacyComputationCoordinates: Decodable {
    let latitude: Double
    let longitude: Double
}

/// In-memory representation used throughout the UI: a ChartFile plus its
/// freshly computed chart (computed once at save time, or recomputed by
/// ChartStore.load when reading a saved file back in).
struct ChartRecord {
    var id: UUID
    var engineVersion: String
    var input: ChartInput
    var computation: ChartComputation

    var file: ChartFile {
        ChartFile(id: id, engineVersion: engineVersion, input: input)
    }
}
