import Foundation

struct PlaceSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let admin1Name: String?
    let countryName: String
    let latitude: Double
    let longitude: Double
    let timezoneIdentifier: String
    let population: Int

    var displayName: String {
        var parts = [name]
        if let admin1Name, !admin1Name.isEmpty {
            parts.append(admin1Name)
        }
        parts.append(countryName)
        return parts.joined(separator: ", ")
    }
}
