import Foundation

/// User-editable configuration for language-aware sounds.
///
/// Pure value type (no AppKit / TIS / audio) so the mapping logic is unit-testable.
/// Loaded once into memory by `LanguageSoundStore`; nothing here is read from disk
/// while typing.
struct LanguageSoundConfiguration: Codable, Equatable {
    var profiles: [SoundProfile]
    /// macOS Input Source ID (e.g. `com.apple.keylayout.Arabic`) -> profile id.
    var inputSourceMap: [String: String]
    /// Fallback for IDs not listed above: primary language subtag (e.g. `ar`) -> profile id.
    var languageMap: [String: String]
    var defaultProfileID: String
    var switchSoundEnabled: Bool
    var switchSoundVolume: Float
    /// Destination profile id -> absolute path of the sound played when switching *to* it.
    var switchSoundPaths: [String: String]

    static let `default` = LanguageSoundConfiguration(
        profiles: SoundProfile.builtIn,
        inputSourceMap: [
            "com.apple.keylayout.Arabic": SoundProfile.arabicID,
            "com.apple.keylayout.Arabic-QWERTY": SoundProfile.arabicID,
            "com.apple.keylayout.ArabicPC": SoundProfile.arabicID,
            "com.apple.keylayout.ABC": SoundProfile.englishID,
            "com.apple.keylayout.US": SoundProfile.englishID,
            "com.apple.keylayout.USExtended": SoundProfile.englishID
        ],
        languageMap: [
            "ar": SoundProfile.arabicID,
            "en": SoundProfile.englishID
        ],
        defaultProfileID: SoundProfile.defaultID,
        switchSoundEnabled: false,
        switchSoundVolume: 0.7,
        switchSoundPaths: [:]
    )

    init(
        profiles: [SoundProfile],
        inputSourceMap: [String: String],
        languageMap: [String: String],
        defaultProfileID: String,
        switchSoundEnabled: Bool,
        switchSoundVolume: Float,
        switchSoundPaths: [String: String]
    ) {
        self.profiles = profiles
        self.inputSourceMap = inputSourceMap
        self.languageMap = languageMap
        self.defaultProfileID = defaultProfileID
        self.switchSoundEnabled = switchSoundEnabled
        self.switchSoundVolume = switchSoundVolume
        self.switchSoundPaths = switchSoundPaths
    }

    // Tolerant decoding so a config written by an older/newer build never resets the user's setup.
    init(from decoder: Decoder) throws {
        let d = LanguageSoundConfiguration.default
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([SoundProfile].self, forKey: .profiles) ?? d.profiles
        inputSourceMap = try c.decodeIfPresent([String: String].self, forKey: .inputSourceMap) ?? d.inputSourceMap
        languageMap = try c.decodeIfPresent([String: String].self, forKey: .languageMap) ?? d.languageMap
        defaultProfileID = try c.decodeIfPresent(String.self, forKey: .defaultProfileID) ?? d.defaultProfileID
        switchSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .switchSoundEnabled) ?? d.switchSoundEnabled
        switchSoundVolume = try c.decodeIfPresent(Float.self, forKey: .switchSoundVolume) ?? d.switchSoundVolume
        switchSoundPaths = try c.decodeIfPresent([String: String].self, forKey: .switchSoundPaths) ?? d.switchSoundPaths
    }

    // MARK: - Lookup

    func profile(withID id: String) -> SoundProfile? {
        profiles.first { $0.id == id }
    }

    /// The profile used when nothing else matches. Never fails: falls back to a synthetic
    /// "Default" profile if the configured one was deleted.
    var defaultProfile: SoundProfile {
        profile(withID: defaultProfileID)
            ?? profile(withID: SoundProfile.defaultID)
            ?? SoundProfile.builtIn[0]
    }

    /// True when the key-press hot path has any reason to look at the Input Source.
    var needsInputSourceTracking: Bool {
        switchSoundEnabled || profiles.contains { $0.soundpackId != nil }
    }
}

/// Input Source -> Sound Profile resolution. Order: exact Input Source ID, then language, then default.
struct SoundProfileResolver {
    let configuration: LanguageSoundConfiguration

    func resolve(inputSourceID: String?, languages: [String] = []) -> SoundProfile {
        if let inputSourceID,
           let profileID = configuration.inputSourceMap[inputSourceID],
           let profile = configuration.profile(withID: profileID) {
            return profile
        }
        for language in languages {
            let primary = language.split(separator: "-").first.map { String($0).lowercased() } ?? ""
            if let profileID = configuration.languageMap[primary],
               let profile = configuration.profile(withID: profileID) {
                return profile
            }
        }
        return configuration.defaultProfile
    }
}
