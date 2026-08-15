public struct VargaChart: Codable, Sendable, Equatable {
    public let varga: DivisionalChart
    public let ascendant: Rasi
    public let ascendantDegreeWithinSign: Double
    public let placements: [CelestialBody: Rasi]
    /// This varga's own scaled degree within `placements[body]`'s sign --
    /// see DivisionalChart.degreeWithinResultingSign for what that means
    /// and why. Not the planet's D1 degree.
    public let degreesWithinSign: [CelestialBody: Double]
    /// Conjunctions/graha drishti/rashi drishti/house lordships computed
    /// from this varga's own placements -- see VargaAnalysis's doc comment
    /// for which categories extend per-varga vs. stay D1-only.
    public let analysis: VargaAnalysis

    public init(varga: DivisionalChart, ascendant: Rasi, ascendantDegreeWithinSign: Double,
                placements: [CelestialBody: Rasi], degreesWithinSign: [CelestialBody: Double], analysis: VargaAnalysis) {
        self.varga = varga
        self.ascendant = ascendant
        self.ascendantDegreeWithinSign = ascendantDegreeWithinSign
        self.placements = placements
        self.degreesWithinSign = degreesWithinSign
        self.analysis = analysis
    }
}
