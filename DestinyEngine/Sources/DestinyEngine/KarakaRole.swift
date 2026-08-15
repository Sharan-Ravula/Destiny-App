/// Jaimini chara karaka roles, 7-karaka scheme (Rahu excluded, Pitrikaraka
/// dropped) -- the modern-software default (e.g. Parashara's Light), chosen
/// over the 8-karaka scheme for Sprint 1.
public enum KarakaRole: String, Codable, CaseIterable, Sendable {
    case atmaKaraka = "AK"
    case amatyaKaraka = "AmK"
    case bhratriKaraka = "BK"
    case matriKaraka = "MK"
    case putraKaraka = "PK"
    case gnatiKaraka = "GK"
    case daraKaraka = "DK"
}
