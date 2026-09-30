import Foundation

/// A named set of keyboard sounds (e.g. "Arabic", "English").
///
/// A profile does not define a new sound format: it *points at an installed keyboard
/// soundpack*, so per-key sounds (key / space / enter / del / tab / arrows / ...) and
/// multiple random variations per key all come from that pack's `config.json`.
/// `soundpackId == nil` means "use whatever keyboard soundpack is currently selected".
struct SoundProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var soundpackId: UUID?
    var isBuiltIn: Bool

    static let defaultID = "default"
    static let arabicID = "arabic"
    static let englishID = "english"

    static let builtIn: [SoundProfile] = [
        SoundProfile(id: defaultID, name: "Default", soundpackId: nil, isBuiltIn: true),
        SoundProfile(id: arabicID, name: "Arabic", soundpackId: nil, isBuiltIn: true),
        SoundProfile(id: englishID, name: "English", soundpackId: nil, isBuiltIn: true)
    ]
}
