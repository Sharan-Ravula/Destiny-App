import Foundation
import DestinyEngine

extension CelestialBody {
    var abbreviation: String {
        switch self {
        case .sun: return "Su"
        case .moon: return "Mo"
        case .mercury: return "Me"
        case .venus: return "Ve"
        case .mars: return "Ma"
        case .jupiter: return "Ju"
        case .saturn: return "Sa"
        case .rahu: return "Ra"
        case .ketu: return "Ke"
        }
    }

    var displayName: String {
        switch self {
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .mercury: return "Mercury"
        case .venus: return "Venus"
        case .mars: return "Mars"
        case .jupiter: return "Jupiter"
        case .saturn: return "Saturn"
        case .rahu: return "Rahu"
        case .ketu: return "Ketu"
        }
    }
}

extension Rasi {
    var displayName: String {
        switch self {
        case .aries: return "Aries"
        case .taurus: return "Taurus"
        case .gemini: return "Gemini"
        case .cancer: return "Cancer"
        case .leo: return "Leo"
        case .virgo: return "Virgo"
        case .libra: return "Libra"
        case .scorpio: return "Scorpio"
        case .sagittarius: return "Sagittarius"
        case .capricorn: return "Capricorn"
        case .aquarius: return "Aquarius"
        case .pisces: return "Pisces"
        }
    }
}

extension Nakshatra {
    var displayName: String {
        switch self {
        case .ashwini: return "Ashwini"
        case .bharani: return "Bharani"
        case .krittika: return "Krittika"
        case .rohini: return "Rohini"
        case .mrigashira: return "Mrigashira"
        case .ardra: return "Ardra"
        case .punarvasu: return "Punarvasu"
        case .pushya: return "Pushya"
        case .ashlesha: return "Ashlesha"
        case .magha: return "Magha"
        case .purvaPhalguni: return "Purva Phalguni"
        case .uttaraPhalguni: return "Uttara Phalguni"
        case .hasta: return "Hasta"
        case .chitra: return "Chitra"
        case .swati: return "Swati"
        case .vishakha: return "Vishakha"
        case .anuradha: return "Anuradha"
        case .jyeshtha: return "Jyeshtha"
        case .mula: return "Mula"
        case .purvaAshadha: return "Purva Ashadha"
        case .uttaraAshadha: return "Uttara Ashadha"
        case .shravana: return "Shravana"
        case .dhanishta: return "Dhanishta"
        case .shatabhisha: return "Shatabhisha"
        case .purvaBhadrapada: return "Purva Bhadrapada"
        case .uttaraBhadrapada: return "Uttara Bhadrapada"
        case .revati: return "Revati"
        }
    }
}
