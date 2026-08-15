import CSwissEphemeris

public enum Ayanamsa: String, CaseIterable, Codable, Sendable {
    case lahiri
    case raman
    case kp
    case faganBradley

    var swissEphemerisMode: Int32 {
        switch self {
        case .lahiri: return SE_SIDM_LAHIRI
        case .raman: return SE_SIDM_RAMAN
        case .kp: return SE_SIDM_KRISHNAMURTI
        case .faganBradley: return SE_SIDM_FAGAN_BRADLEY
        }
    }
}
