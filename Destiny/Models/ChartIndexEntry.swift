import Foundation
import SwiftData

@Model
final class ChartIndexEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateOfBirth: Date
    var placeName: String
    /// dateOfBirth is stored as an absolute UTC instant -- this is needed
    /// alongside it to reformat back into the original birth-local
    /// wall-clock date/time for display (e.g. in the saved-charts list).
    /// Empty string is a sentinel for entries saved before this field
    /// existed (lightweight migration default) -- SavedChartsListView
    /// backfills those from their JSON file on launch.
    var timeZoneIdentifier: String = ""
    /// Absolute path to this chart's JSON file. Stored per-chart (not
    /// derived from a single global directory) so that letting the user
    /// pick a different save folder for future charts never breaks the
    /// location of charts already saved elsewhere -- each entry just
    /// keeps pointing at wherever its file actually is.
    var filePath: String

    init(id: UUID, name: String, dateOfBirth: Date, placeName: String, timeZoneIdentifier: String, filePath: String) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.placeName = placeName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.filePath = filePath
    }
}
