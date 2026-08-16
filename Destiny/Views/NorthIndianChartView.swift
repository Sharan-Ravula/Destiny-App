import SwiftUI
import DestinyEngine

/// North Indian style: house positions are fixed (house 1 is always the
/// top diamond), and it's the rasi shown in each house that shifts with
/// the Ascendant. Standard construction: outer square + both diagonals +
/// a diamond through the side midpoints, which together divide the square
/// into the 12 conventional house regions.
struct NorthIndianChartView: View {
    let layout: ChartLayoutData
    /// Set only by ChartPDFExporter, to force a light/print-friendly theme
    /// regardless of the live app theme.
    var overrideTheme: ColorTheme?
    @AppStorage("colorTheme") private var colorThemeID: String = ColorTheme.system.id
    private var theme: ColorTheme { overrideTheme ?? ColorTheme.theme(forID: colorThemeID) }
    @State private var hoveredRasi: Rasi?

    private var aspectedRasis: Set<Rasi> {
        hoveredRasi.map(layout.aspectedRasis(hovering:)) ?? []
    }

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

    /// Exact vertices (fractional 0-1, scaled by `size` at draw time) for
    /// each of the 12 house regions -- derived directly from the same grid
    /// construction gridLines() draws (outer square corners/midpoints,
    /// both full diagonals, and the inner diamond through the side
    /// midpoints): each diagonal crosses the diamond's boundary at the
    /// midpoint between a diamond vertex and the center, so the diamond
    /// splits into 4 kite quadrilaterals (houses 1/4/7/10) and each outer
    /// corner splits into 2 triangles (the rest) where its diagonal cuts
    /// across it. Every polygon's centroid was checked against `anchors`
    /// above to confirm the house-number mapping.
    private static let housePolygons: [Int: [(Double, Double)]] = [
        1: [(0.5, 0), (0.75, 0.25), (0.5, 0.5), (0.25, 0.25)],
        2: [(0, 0), (0.5, 0), (0.25, 0.25)],
        3: [(0, 0), (0.25, 0.25), (0, 0.5)],
        4: [(0, 0.5), (0.25, 0.25), (0.5, 0.5), (0.25, 0.75)],
        5: [(0, 1), (0, 0.5), (0.25, 0.75)],
        6: [(0.5, 1), (0, 1), (0.25, 0.75)],
        7: [(0.5, 1), (0.25, 0.75), (0.5, 0.5), (0.75, 0.75)],
        8: [(1, 1), (0.5, 1), (0.75, 0.75)],
        9: [(1, 0.5), (1, 1), (0.75, 0.75)],
        10: [(1, 0.5), (0.75, 0.75), (0.5, 0.5), (0.75, 0.25)],
        11: [(1, 0), (1, 0.5), (0.75, 0.25)],
        12: [(0.5, 0), (1, 0), (0.75, 0.25)],
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                gridLines(size: size)
                // Highlight fill layer first (exact polygon per house),
                // then the text labels on top so the fill never covers them.
                ForEach(1...12, id: \.self) { house in
                    housePolygonFill(house: house, layout: layout, size: size)
                }
                ForEach(1...12, id: \.self) { house in
                    houseLabelText(house: house, layout: layout, size: size)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            // A single hover-tracking region for the whole chart, with an
            // explicit point-in-polygon test to find which house it's
            // over -- per-shape .onHover on 12 stacked, exactly-adjacent
            // Path views turned out unreliable (SwiftUI/AppKit's hover
            // tracking areas didn't respect .contentShape precisely enough
            // when the shapes fully tile the same canvas, so only one
            // house ever actually received hover events). This is
            // deterministic instead of depending on that dispatch.
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    updateHover(at: location, size: size)
                case .ended:
                    hoveredRasi = nil
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func updateHover(at location: CGPoint, size: Double) {
        guard let house = house(containing: location, size: size) else {
            hoveredRasi = nil
            return
        }
        let rasiIndex = (layout.ascendantRasi.rawValue + house - 1) % 12
        let rasi = Rasi(rawValue: rasiIndex)!
        hoveredRasi = (layout.planetsByRasi[rasi]?.isEmpty ?? true) ? nil : rasi
    }

    private func house(containing point: CGPoint, size: Double) -> Int? {
        (1...12).first { pointInPolygon(point, house: $0, size: size) }
    }

    /// Standard ray-casting point-in-polygon test.
    private func pointInPolygon(_ point: CGPoint, house: Int, size: Double) -> Bool {
        let polygon = Self.housePolygons[house]!
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].0 * size, yi = polygon[i].1 * size
            let xj = polygon[j].0 * size, yj = polygon[j].1 * size
            if (yi > point.y) != (yj > point.y),
               point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
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

    private func housePath(house: Int, size: Double) -> Path {
        let points = Self.housePolygons[house]!
        var path = Path()
        path.move(to: CGPoint(x: points[0].0 * size, y: points[0].1 * size))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * size, y: point.1 * size))
        }
        path.closeSubpath()
        return path
    }

    private func housePolygonFill(house: Int, layout: ChartLayoutData, size: Double) -> some View {
        let rasiIndex = (layout.ascendantRasi.rawValue + house - 1) % 12
        let rasi = Rasi(rawValue: rasiIndex)!
        return housePath(house: house, size: size).fill(cellHighlight(for: rasi))
    }

    /// Purely decorative -- hover/highlight is handled entirely by the
    /// polygon layer beneath, so this doesn't need its own hit-testing.
    private func houseLabelText(house: Int, layout: ChartLayoutData, size: Double) -> some View {
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
        .allowsHitTesting(false)
        .position(x: fx * size, y: fy * size)
    }
}
