enum ChartRenderStyle: String, CaseIterable, Identifiable {
    case northIndian = "North Indian"
    case southIndian = "South Indian"
    var id: String { rawValue }
}
