import Testing
import Foundation
@testable import Thock

// MARK: - Helpers

private func source(_ id: String, _ languages: [String] = []) -> InputSourceInfo {
    InputSourceInfo(id: id, name: id, languages: languages)
}

private let arabic = source("com.apple.keylayout.Arabic", ["ar"])
private let abc = source("com.apple.keylayout.ABC", ["en"])
private let us = source("com.apple.keylayout.US", ["en"])

/// Mutable stand-in for the macOS Input Source, so tests can "switch language" deterministically.
private final class FakeInputSource {
    var current: InputSourceInfo?
    init(_ current: InputSourceInfo?) { self.current = current }
}

private func makeManager(
    fake: FakeInputSource,
    edit: (inout LanguageSoundConfiguration) -> Void = { _ in }
) -> SoundProfileManager {
    let suite = "langthock-tests-\(UUID().uuidString)"
    let store = LanguageSoundStore(defaults: UserDefaults(suiteName: suite)!)
    store.update(edit)
    return SoundProfileManager(store: store, querySource: { fake.current })
}

// MARK: - Input Source -> Profile mapping

struct InputSourceMappingTests {
    private let resolver = SoundProfileResolver(configuration: .default)

    @Test func arabicInputSourceMapsToArabicProfile() {
        #expect(resolver.resolve(inputSourceID: arabic.id, languages: arabic.languages).id == SoundProfile.arabicID)
    }

    @Test func abcMapsToEnglishProfile() {
        #expect(resolver.resolve(inputSourceID: abc.id, languages: abc.languages).id == SoundProfile.englishID)
    }

    @Test func usMapsToEnglishProfile() {
        #expect(resolver.resolve(inputSourceID: us.id, languages: us.languages).id == SoundProfile.englishID)
    }

    @Test func unknownInputSourceMapsToDefaultProfile() {
        #expect(resolver.resolve(inputSourceID: "com.example.unknown", languages: []).id == SoundProfile.defaultID)
        #expect(resolver.resolve(inputSourceID: nil).id == SoundProfile.defaultID)
    }

    @Test func unknownIDFallsBackToLanguage() {
        #expect(resolver.resolve(inputSourceID: "com.example.arabic-variant", languages: ["ar-SA"]).id == SoundProfile.arabicID)
    }

    @Test func explicitIDMappingWinsOverLanguage() {
        var config = LanguageSoundConfiguration.default
        config.inputSourceMap["com.apple.keylayout.Arabic"] = SoundProfile.englishID
        let resolved = SoundProfileResolver(configuration: config)
            .resolve(inputSourceID: "com.apple.keylayout.Arabic", languages: ["ar"])
        #expect(resolved.id == SoundProfile.englishID)
    }

    @Test func mappingToDeletedProfileFallsBackToDefault() {
        var config = LanguageSoundConfiguration.default
        config.inputSourceMap["com.apple.keylayout.ABC"] = "custom-gone"
        config.languageMap = [:]
        let resolved = SoundProfileResolver(configuration: config).resolve(inputSourceID: "com.apple.keylayout.ABC")
        #expect(resolved.id == SoundProfile.defaultID)
    }

    @Test func configurationSurvivesJSONRoundTripAndPartialJSON() throws {
        let data = try JSONEncoder().encode(LanguageSoundConfiguration.default)
        #expect(try JSONDecoder().decode(LanguageSoundConfiguration.self, from: data) == .default)
        // Older/partial config: missing keys take defaults instead of failing.
        let partial = try JSONDecoder().decode(LanguageSoundConfiguration.self, from: Data("{\"switchSoundEnabled\":true}".utf8))
        #expect(partial.switchSoundEnabled)
        #expect(partial.inputSourceMap == LanguageSoundConfiguration.default.inputSourceMap)
    }
}

// MARK: - Transitions and first key press

struct SoundProfileTransitionTests {
    @Test func arabicToEnglish() {
        let fake = FakeInputSource(arabic)
        let manager = makeManager(fake: fake)
        manager.apply(inputSource: arabic)
        #expect(manager.currentProfile.id == SoundProfile.arabicID)
        manager.apply(inputSource: abc)
        #expect(manager.currentProfile.id == SoundProfile.englishID)
    }

    @Test func englishToArabic() {
        let fake = FakeInputSource(abc)
        let manager = makeManager(fake: fake)
        manager.apply(inputSource: abc)
        manager.apply(inputSource: arabic)
        #expect(manager.currentProfile.id == SoundProfile.arabicID)
    }

    @Test func arabicEnglishArabic() {
        let manager = makeManager(fake: FakeInputSource(arabic))
        manager.apply(inputSource: arabic)
        manager.apply(inputSource: abc)
        manager.apply(inputSource: arabic)
        #expect(manager.currentProfile.id == SoundProfile.arabicID)
    }

    @Test func sameSourceIsNoTransition() {
        let manager = makeManager(fake: FakeInputSource(abc))
        #expect(manager.apply(inputSource: abc) != nil)
        #expect(manager.apply(inputSource: abc) == nil)
    }

    /// The race: user switches language and types at once, before the system notification arrives.
    /// The first key press re-reads the Input Source, so it already gets the new profile.
    @Test func firstKeyPressAfterSwitchUsesNewProfileEvenWithoutNotification() {
        let fake = FakeInputSource(arabic)
        let manager = makeManager(fake: fake) { $0.switchSoundEnabled = true }   // enables key-press tracking
        manager.syncNow()
        #expect(manager.profileForKeyPress().id == SoundProfile.arabicID)

        fake.current = abc   // macOS switched; no notification delivered to the app yet
        #expect(manager.profileForKeyPress().id == SoundProfile.englishID)

        fake.current = arabic
        #expect(manager.profileForKeyPress().id == SoundProfile.arabicID)
        fake.current = abc
        #expect(manager.profileForKeyPress().id == SoundProfile.englishID)
    }

    @Test func keyPressDoesNotQueryInputSourceWhenNothingDependsOnLanguage() {
        let fake = FakeInputSource(arabic)
        let manager = makeManager(fake: fake)   // no profile soundpack, switch sounds off
        manager.syncNow()
        fake.current = abc
        #expect(manager.profileForKeyPress().id == SoundProfile.arabicID)   // hot path skipped the TIS call
    }

    @Test func switchSoundOnlyWhenEnabledAndProfileChanges() {
        let fake = FakeInputSource(arabic)
        let manager = makeManager(fake: fake) { $0.switchSoundEnabled = true }
        let initial = manager.apply(inputSource: arabic)!
        #expect(manager.switchSoundProfile(for: initial) == nil)              // launch detection is silent

        let toEnglish = manager.apply(inputSource: abc)!
        #expect(manager.switchSoundProfile(for: toEnglish)?.id == SoundProfile.englishID)

        let toUS = manager.apply(inputSource: us)!                            // ABC -> U.S.: same profile
        #expect(manager.switchSoundProfile(for: toUS) == nil)

        let toArabic = manager.apply(inputSource: arabic)!
        #expect(manager.switchSoundProfile(for: toArabic)?.id == SoundProfile.arabicID)
    }

    @Test func switchSoundDisabledPlaysNothing() {
        let manager = makeManager(fake: FakeInputSource(arabic))
        manager.apply(inputSource: arabic)
        let t = manager.apply(inputSource: abc)!
        #expect(manager.switchSoundProfile(for: t) == nil)
    }

    @Test func editingMappingUpdatesActiveProfileWithoutSourceChange() {
        let suite = "langthock-tests-\(UUID().uuidString)"
        let store = LanguageSoundStore(defaults: UserDefaults(suiteName: suite)!)
        let manager = SoundProfileManager(store: store, querySource: { abc })
        manager.apply(inputSource: abc)
        #expect(manager.currentProfile.id == SoundProfile.englishID)
        store.update { $0.inputSourceMap[abc.id] = SoundProfile.arabicID }
        #expect(manager.currentProfile.id == SoundProfile.arabicID)
    }
}

// MARK: - Per-key behavior stays independent of the profile

struct KeyMappingTests {
    @Test func specialKeysKeepTheirNames() {
        #expect(KeyMapper.fromKeyCode(49) == "space")
        #expect(KeyMapper.fromKeyCode(36) == "enter")
        #expect(KeyMapper.fromKeyCode(51) == "del")
        #expect(KeyMapper.fromKeyCode(48) == "tab")
        #expect(KeyMapper.fromKeyCode(53) == "esc")
        #expect(KeyMapper.fromKeyCode(123) == "arrLeft")
        #expect(KeyMapper.fromKeyCode(122) == "f1")
        #expect(KeyMapper.fromKeyCode(56) == "shiftLeft")
    }

    @Test func packFallsBackToDefaultKey() {
        let pack = ProfileSoundBank.Pack(down: ["default": ["p/k1.wav"], "space": ["p/s.wav"]], up: [:])
        #expect(pack.downSounds(for: "space") == ["p/s.wav"])
        #expect(pack.downSounds(for: "a") == ["p/k1.wav"])
        #expect(pack.upSounds(for: "a").isEmpty)
    }
}

// MARK: - Arabic file names / encoding

struct ArabicEncodingTests {
    @Test func decomposedArabicFileNamesAreNormalizedToComposedForm() throws {
        let composed = "\u{0623}-key.wav"                              // "أ" as one scalar
        let decomposed = composed.decomposedStringWithCanonicalMapping   // "ا" + hamza above
        // Swift's == is canonical-equivalence based, so compare the raw scalars.
        #expect(Array(composed.unicodeScalars) != Array(decomposed.unicodeScalars))

        let json = "{\"down\":[\"\(decomposed)\"],\"up\":[]}"
        let sound = try JSONDecoder().decode(KeySound.self, from: Data(json.utf8))
        #expect(Array(sound.down[0].unicodeScalars) == Array(composed.unicodeScalars))
    }

    @Test func configurationKeepsArabicProfileNames() throws {
        var config = LanguageSoundConfiguration.default
        config.profiles.append(SoundProfile(id: "custom-1", name: "عربي مخصص", soundpackId: nil, isBuiltIn: false))
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LanguageSoundConfiguration.self, from: data)
        #expect(decoded.profiles.last?.name == "عربي مخصص")
    }
}
