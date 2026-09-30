import Foundation

// MARK: - Sound Engine

/// Orchestrates sound playback by coordinating between keyboard events,
/// sound selection, and the low-level audio manager.
final class SoundEngine {
    static let shared = SoundEngine()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Sound Loading
    
    func preloadSounds(for soundpack: Soundpack) {
        SoundManager.shared.preloadSounds(for: soundpack)
    }
    
    func preloadMouseSounds(for soundpack: Soundpack, config: SoundpackConfig) {
        SoundManager.shared.preloadMouseSoundsFromPack(for: soundpack, config: config)
    }
    
    // MARK: - Playback
    
    /// Plays sound for a keyboard event by selecting appropriate sound and delegating to manager
    /// - Parameters:
    ///   - keyCode: The keyboard key code
    ///   - isKeyDown: true for key press, false for key release
    ///   - latencyId: Optional UUID for latency measurement tracking
    ///   - soundpackId: Soundpack of the active language profile; nil uses the current keyboard soundpack
    func play(for keyCode: Int64, isKeyDown: Bool, soundpackId: UUID? = nil, latencyId: UUID? = nil) {
        // Don't play if app is disabled
        guard AppEngine.shared.isEnabled() else { return }
        
        recordLatencyCheckpoint(latencyId, point: .soundEngineInvoked)
        
        // Map key code to key type and get appropriate sounds
        let keyType = KeyMapper.fromKeyCode(keyCode)
        
        // Language profile with its own soundpack: preloaded, namespaced sounds.
        if let soundpackId, let pack = ProfileSoundBank.shared.pack(for: soundpackId) {
            let list = isKeyDown ? pack.downSounds(for: keyType) : pack.upSounds(for: keyType)
            if let name = list.randomElement() {
                recordLatencyCheckpoint(latencyId, point: .soundSelected)
                SoundManager.shared.playNamespaced(
                    name,
                    pitchVariation: SettingsEngine.shared.getPitchVariation(),
                    latencyId: latencyId
                )
            }
            return
        }
        
        let keySoundList = isKeyDown
        ? SoundpackEngine.shared.getKeyDownSounds(for: keyType)
        : SoundpackEngine.shared.getKeyUpSounds(for: keyType)
        
        // Play random sound from the list
        if let soundFileName = keySoundList.randomElement() {
            recordLatencyCheckpoint(latencyId, point: .soundSelected)
            play(sound: soundFileName, latencyId: latencyId)
        }
    }
    
    /// Plays a specific sound by name
    /// - Parameters:
    ///   - name: The sound file name
    ///   - latencyId: Optional UUID for latency measurement tracking
    func play(sound name: String, latencyId: UUID? = nil) {
        let pitchVariation = SettingsEngine.shared.getPitchVariation()
        SoundManager.shared.play(sound: name, pitchVariation: pitchVariation, latencyId: latencyId)
    }
    
    // MARK: - Language profiles
    
    /// Plays the "switch to <profile>" sound, if one is configured.
    func playSwitchSound(for profile: SoundProfile) {
        SoundManager.shared.playNamespaced("\(ProfileSoundBank.switchPrefix)\(profile.id)")
    }
    
    /// Preview of one key type of a profile through the normal engine. Returns false if nothing to play.
    @discardableResult
    func preview(profile: SoundProfile, keyType: String) -> Bool {
        if let id = profile.soundpackId, let pack = ProfileSoundBank.shared.pack(for: id) {
            guard let name = pack.downSounds(for: keyType).randomElement() else { return false }
            SoundManager.shared.playNamespaced(name)
            return true
        }
        guard let name = SoundpackEngine.shared.getKeyDownSounds(for: keyType).randomElement() else { return false }
        play(sound: name)
        return true
    }
}
