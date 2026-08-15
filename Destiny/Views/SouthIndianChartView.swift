import SwiftUI
import DestinyEngine

/// South Indian style: rasi positions are fixed on a 4x4 grid (the 4
/// center cells are unused), planets go in the cell for their own rasi,
/// and house numbers (relative to the Ascendant) are shown as a small
/// label in each cell.
struct SouthIndianChartView: View {
    let layout: ChartLayoutData
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }
    @State private var hoveredRasi: Rasi?

    private var aspectedRasis: Set<Rasi> {
        hoveredRasi.map(layout.aspectedRasis(hovering:)) ?? []
    }

    /// Fixed clockwise layout starting at Pisces (top-left), matching the
    /// conventional South Indian grid.
    private static let gridRasis: [[Rasi?]] = [
        [.pisces, .aries, .taurus, .gemini],
        [.aquarius, nil, nil, .cancer],
        [.capricorn, nil, nil, .leo],
        [.sagittarius, .scorpio, .libra, .virgo],
    ]

    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / 4
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { col in
                            cell(rasi: Self.gridRasis[row][col], layout: layout)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cell(rasi: Rasi?, layout: ChartLayoutData) -> some View {
        if let rasi {
            ZStack {
                Rectangle().fill(cellHighlight(for: rasi))
                Rectangle().stroke(Color.secondary, lineWidth: 1)

                // Planet abbreviations centered in the box.
                layout.planetText(for: rasi, theme: theme)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .padding(4)

                // House number / Ascendant badge pinned to the top corners,
                // Arudha/Upapada Lagna badges pinned to the bottom-left.
                VStack {
                    HStack {
                        Text("\(layout.houseNumber(for: rasi))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if rasi == layout.ascendantRasi {
                            Text("Asc")
                                .font(.caption.bold())
                        }
                    }
                    Spacer()
                    HStack {
                        if rasi == layout.arudhaLagnaRasi {
                            Text("Ar")
                                .font(.caption.bold())
                        }
                        if rasi == layout.upapadaLagnaRasi {
                            Text("Up")
                                .font(.caption.bold())
                        }
                        if rasi == layout.karakamsaRasi {
                            Text("Kk")
                                .font(.caption.bold())
                        }
                        Spacer()
                    }
                }
                .padding(4)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                guard (layout.planetsByRasi[rasi]?.isEmpty ?? true) == false else { return }
                hoveredRasi = hovering ? rasi : (hoveredRasi == rasi ? nil : hoveredRasi)
            }
        } else {
            Rectangle().fill(Color.clear)
        }
    }

    /// Stronger tint on the hovered cell itself, lighter tint on the
    /// house(s) it aspects (Graha Drishti) -- so hovering a planet shows
    /// both "you are here" and "this is what you're aspecting" at once.
    private func cellHighlight(for rasi: Rasi) -> Color {
        if rasi == hoveredRasi {
            return theme.accent.opacity(0.28)
        }
        if aspectedRasis.contains(rasi) {
            return theme.accent.opacity(0.14)
        }
        return .clear
    }
}
