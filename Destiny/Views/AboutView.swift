import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Destiny").font(.title.bold())
            Text("A Vedic astrology app.")

            Divider()

            Text("Data & Licensing").font(.headline)
            Text("Planetary calculations use the Swiss Ephemeris, \u{00A9} Astrodienst AG, licensed under AGPL-3.0.")
                .font(.callout)
            Text("Place-of-birth search uses the GeoNames geographical database (geonames.org), licensed under CC BY 4.0.")
                .font(.callout)
        }
        .padding(24)
        .frame(width: 420)
    }
}
