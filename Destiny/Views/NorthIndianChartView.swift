import SwiftUI
import DestinyEngine

/// North Indian style: house positions are fixed (house 1 is always the
/// top diamond), and it's the rasi shown in each house that shifts with
/// the Ascendant. Standard construction: outer square + both diagonals +
/// a diamond through the side midpoints, which together divide the square
/// into the 12 conventional house regions.
struct NorthIndianChartView: View {
    let layout: ChartLayoutData
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    private var theme: ColorTheme { ColorTheme.theme(forID: colorThemeID) }
    @State private var hoveredRasi: Rasi?

    private var aspectedRasis: Set<Rasi> {
        hoveredRasi.map(layout.aspectedRasis(hovering:)) ?? []
    }

    /// The house regions here are irregular diamond tips/corner triangles
    /// (not a uniform grid like South Indian), so instead of filling the
    /// exact polygon, the highlight is a rounded rect behind the house's
    /// label cluster -- a deliberate simplification, not a geometric fill
    /// of the true house shape.
    private func cellHighlight(for rasi: Rasi) -> Color {
        if rasi == hoveredRasi {
            return theme.accent.opacity(0.28)
        }
        if aspectedRasis.contains(rasi) {
            return theme.accent.opacity(0.14)
        }
        return .clear
    }

    /// Fractional (x, y) label anchor per house number, matching the
    /// conventional layout (houses 1/4/7/10 are the diamond tips at top/
    /// left/bottom/right; the rest are the corner/edge triangles).
    private static let anchors: [Int: (Double, Double)] = [
        1: (0.5, 0.22), 2: (0.27, 0.13), 3: (0.13, 0.27), 4: (0.22, 0.5),
        5: (0.13, 0.73), 6: (0.27, 0.87), 7: (0.5, 0.78), 8: (0.73, 0.87),
        9: (0.87, 0.73), 10: (0.78, 0.5), 11: (0.87, 0.27), 12: (0.73, 0.13),
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                gridLines(size: size)
                ForEach(1...12, id: \.self) { house in
                    houseLabel(house: house, layout: layout, size: size)
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func gridLines(size: Double) -> some View {
        Path { path in
            path.addRect(CGRect(x: 0, y: 0, width: size, height: size))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: size))
            path.move(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: size))
            path.move(to: CGPoint(x: size / 2, y: 0))
            path.addLine(to: CGPoint(x: size, y: size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: size))
            path.addLine(to: CGPoint(x: 0, y: size / 2))
            path.closeSubpath()
        }
        .stroke(Color.secondary, lineWidth: 1)
    }

    private func houseLabel(house: Int, layout: ChartLayoutData, size: Double) -> some View {
        let rasiIndex = (layout.ascendantRasi.rawValue + house - 1) % 12
        let rasi = Rasi(rawValue: rasiIndex)!
        let (fx, fy) = Self.anchors[house]!

        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text("\(rasiIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if house == 1 {
                    Text("Asc").font(.caption.bold())
                }
                if rasi == layout.arudhaLagnaRasi {
                    Text("Ar").font(.caption.bold())
                }
                if rasi == layout.upapadaLagnaRasi {
                    Text("Up").font(.caption.bold())
                }
                if rasi == layout.karakamsaRasi {
                    Text("Kk").font(.caption.bold())
                }
            }
            layout.planetText(for: rasi, theme: theme)
                .font(.callout)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        }
        .padding(3)
        .background(cellHighlight(for: rasi), in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onHover { hovering in
            guard (layout.planetsByRasi[rasi]?.isEmpty ?? true) == false else { return }
            hoveredRasi = hovering ? rasi : (hoveredRasi == rasi ? nil : hoveredRasi)
        }
        .position(x: fx * size, y: fy * size)
    }
}
