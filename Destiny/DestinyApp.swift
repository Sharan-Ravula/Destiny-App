//
//  DestinyApp.swift
//  Destiny
//
//  Created by Sharan Ravula on 8/14/26.
//

import SwiftUI
import SwiftData

@main
struct DestinyApp: App {
    @AppStorage("fontZoomStep") private var fontZoomStep: Int = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ChartIndexEntry.self)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Chart...") {
                    NotificationCenter.default.post(name: .importChartRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                // "=" (not "+") is the shortcut's actual key equivalent --
                // matches Safari/Xcode's own Zoom In, so Cmd and the bare
                // +/= key works without needing Shift too.
                Button("Zoom In") {
                    fontZoomStep = min(fontZoomStep + 1, FontZoom.maxStep)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Zoom Out") {
                    fontZoomStep = max(fontZoomStep - 1, FontZoom.minStep)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    fontZoomStep = 0
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(fontZoomStep == 0)
            }
        }
    }
}
