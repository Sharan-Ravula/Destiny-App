import Foundation
import SwiftData
import DestinyEngine

enum ChartStoreError: Error {
    case notFound(UUID)
}

/// One JSON file per chart (raw inputs only -- see ChartFile), named
/// "<Name> - <DOB>.json" for discoverability in Finder, with a lightweight
/// SwiftData index kept in sync alongside it (including each chart's
/// absolute file path) so the saved-charts list doesn't need to parse
/// every file, or scan any directory, just to show a name/date/place or
/// resolve where a chart's file currently lives.
///
/// Charts aren't confined to one directory: the user picks a folder per
/// new chart (see ChartInputFormView), and each entry remembers its own
/// absolute path, so changing where *future* charts get saved never
/// breaks the location of charts already saved elsewhere.
enum ChartStore {
    static var defaultChartsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Charts", isDirectory: true)
    }

    static func fileURL(for entry: ChartIndexEntry) -> URL {
        URL(fileURLWithPath: entry.filePath)
    }

    private static func baseFileName(for input: ChartInput) -> String {
        let moment = input.birthMoment
        let dateString = String(format: "%04d-%02d-%02d", moment.year, moment.month, moment.day)
        return "\(sanitize(input.name)) - \(dateString)"
    }

    private static func sanitize(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let cleaned = raw.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// "<directory>/<Name> - <DOB>.json", or with a short id suffix if that
    /// exact path is already used by a *different* chart.
    private static func resolveFileURL(for input: ChartInput, id: UUID, in directory: URL, context: ModelContext) throws -> URL {
        let base = baseFileName(for: input)
        let candidate = directory.appendingPathComponent(base + ".json").path
        let descriptor = FetchDescriptor<ChartIndexEntry>(
            predicate: #Predicate { $0.filePath == candidate && $0.id != id }
        )
        let hasCollision = try !context.fetch(descriptor).isEmpty
        guard hasCollision else { return URL(fileURLWithPath: candidate) }
        return directory.appendingPathComponent("\(base) - \(id.uuidString.prefix(8)).json")
    }

    /// - Parameter directory: where to save a *new* chart. Ignored when
    ///   updating an existing chart, which always stays in its current
    ///   location. Defaults to `defaultChartsDirectory` if nil and there's
    ///   no existing entry to inherit a location from (e.g. programmatic
    ///   saves that don't go through the folder-picker UI).
    static func save(_ record: ChartRecord, in context: ModelContext, directory: URL? = nil) throws {
        let id = record.id
        let descriptor = FetchDescriptor<ChartIndexEntry>(predicate: #Predicate { $0.id == id })
        let existing = try context.fetch(descriptor).first

        let targetDirectory = existing.map { URL(fileURLWithPath: $0.filePath).deletingLastPathComponent() }
            ?? directory
            ?? defaultChartsDirectory
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let newURL = try resolveFileURL(for: record.input, id: record.id, in: targetDirectory, context: context)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record.file)

        if let existing {
            let oldURL = URL(fileURLWithPath: existing.filePath)
            try data.write(to: newURL, options: .atomic)
            if oldURL != newURL {
                try? FileManager.default.removeItem(at: oldURL)
            }
            existing.name = record.input.name
            existing.dateOfBirth = try record.input.birthMoment.resolvedUTCDate()
            existing.placeName = record.input.placeName
            existing.timeZoneIdentifier = record.input.birthMoment.timeZoneIdentifier
            existing.filePath = newURL.path
            existing.gender = record.input.gender?.rawValue ?? ""
        } else {
            try data.write(to: newURL, options: .atomic)
            let entry = ChartIndexEntry(
                id: record.id,
                name: record.input.name,
                dateOfBirth: try record.input.birthMoment.resolvedUTCDate(),
                placeName: record.input.placeName,
                timeZoneIdentifier: record.input.birthMoment.timeZoneIdentifier,
                filePath: newURL.path,
                gender: record.input.gender?.rawValue ?? ""
            )
            context.insert(entry)
        }
        try context.save()
    }

    /// Cheap, synchronous read of just the raw saved facts -- no chart
    /// computation. Used where the full computed chart isn't needed (e.g.
    /// the legacy-timezone repair pass in SavedChartsListView).
    static func loadFile(from entry: ChartIndexEntry) throws -> ChartFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: fileURL(for: entry))
        return try decoder.decode(ChartFile.self, from: data)
    }

    /// Loads the raw saved facts and recomputes the full chart from them --
    /// the file itself never stores the computed chart, by design.
    static func load(from entry: ChartIndexEntry) async throws -> ChartRecord {
        let file = try loadFile(from: entry)
        let computation = try await ChartCalculator.computeChart(
            birthMoment: file.input.birthMoment, latitude: file.input.latitude, longitude: file.input.longitude
        )
        // Older files didn't have an id/engineVersion at all -- entry.id is
        // already the stable identity SwiftData has been using for this
        // chart regardless, so that's the correct fallback (not a fresh
        // random UUID, which would make the next save create a duplicate).
        return ChartRecord(
            id: file.id ?? entry.id, engineVersion: file.engineVersion ?? "unknown",
            input: file.input, computation: computation
        )
    }

    static func delete(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<ChartIndexEntry>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            try? FileManager.default.removeItem(at: fileURL(for: existing))
            context.delete(existing)
            try context.save()
        }
    }
}
