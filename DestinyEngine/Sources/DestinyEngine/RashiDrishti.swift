/// Rashi drishti (Jaimini sign-to-sign aspects) -- distinct from graha
/// drishti (planet-to-house aspects). Confirmed with user before
/// implementation, low ambiguity: movable signs aspect all 4 fixed signs
/// except the one immediately following (adjacent); fixed signs aspect
/// all 4 movable signs except the one immediately preceding (adjacent);
/// dual signs aspect the other 3 dual signs, no exception. The "adjacent"
/// fixed/movable sign is always exactly the following/preceding sign --
/// movable signs are always immediately followed by a fixed sign, and
/// fixed signs immediately preceded by a movable one -- so the exception
/// reduces to a fixed offset.
public enum RashiDrishti {
    public static func aspectedSigns(for rasi: Rasi) -> [Rasi] {
        if rasi.isMovable {
            let excluded = rasi.offset(1)
            return Rasi.allCases.filter { $0.isFixed && $0 != excluded }
        } else if rasi.isFixed {
            let excluded = rasi.offset(-1)
            return Rasi.allCases.filter { $0.isMovable && $0 != excluded }
        } else {
            return Rasi.allCases.filter { $0.isDual && $0 != rasi }
        }
    }
}

public struct RashiAspect: Codable, Sendable, Equatable {
    public let fromRasi: Rasi
    public let toRasi: Rasi

    public init(fromRasi: Rasi, toRasi: Rasi) {
        self.fromRasi = fromRasi
        self.toRasi = toRasi
    }
}
