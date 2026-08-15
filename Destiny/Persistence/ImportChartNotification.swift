import Foundation

/// Posted by the File > Open Chart... menu command (DestinyApp.swift),
/// handled by SavedChartsListView, which is where a ModelContext is
/// actually available to save the imported chart.
extension Notification.Name {
    static let importChartRequested = Notification.Name("importChartRequested")
}
