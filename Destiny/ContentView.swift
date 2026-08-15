//
//  ContentView.swift
//  Destiny
//
//  Created by Sharan Ravula on 8/14/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    @AppStorage("fontZoomStep") private var fontZoomStep: Int = 0

    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }

    var body: some View {
        SavedChartsListView()
            .tint(theme.accent)
            .background(theme.background)
            .environment(\.fontZoomMultiplier, FontZoom.multiplier(forStep: fontZoomStep))
            .task(id: colorThemeID) {
                // "System" theme (forcedAppearance nil) just follows
                // whatever macOS is set to -- there's no separate
                // Appearance setting to fall back to anymore.
                NSApp.appearance = theme.forcedAppearance?.nsAppearance
            }
    }
}

#Preview {
    ContentView()
}
