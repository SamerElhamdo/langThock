import Foundation
import OSLog

/// Preloaded sounds for language profiles that point at their own soundpack.
///
/// Everything is decoded and loaded ahead of time on a background queue (at launch and whenever profiles or
/// the soundpack library change). While typing, `pack(for:)` is a lock + dictionary read.
final class ProfileSoundBank {
    static let shared = ProfileSoundBank()
    
    /// Sound names are already namespaced for `SoundManager.playNamespaced`.
    struct Pack {
        let down: [String: [String]]
        let up: [String: [String]]
        
        func downSounds(for key: String) -> [String] {
            down[key] ?? down[KeyMapper.keyCodeNotFound] ?? []
        }
        
        func upSounds(for key: String) -> [String] {
            up[key] ?? up[KeyMapper.keyCodeNotFound] ?? []
        }
    }
    
    private let lock = NSLock()
    private var packs: [UUID: Pack] = [:]
    private let queue = DispatchQueue(label: "dev.langthock.profile-bank", qos: .userInitiated)
    private static let packPrefix = "pack:"
    static let switchPrefix = "switch:"
    
    private init() {}
    
    func pack(for soundpackId: UUID) -> Pack? {
        lock.lock()
        defer { lock.unlock() }
        return packs[soundpackId]
    }
    
    /// (Re)loads every soundpack referenced by a profile, and every switch sound. Asynchronous.
    func reload(configuration: LanguageSoundConfiguration) {
        queue.async { [weak self] in self?.performReload(configuration) }
    }
    
    // MARK: - Private
    
    private func performReload(_ configuration: LanguageSoundConfiguration) {
        let database = SoundpackDatabase()
        let wanted = Set(configuration.profiles.compactMap { $0.soundpackId })
        
        lock.lock()
        let alreadyLoaded = Set(packs.keys)
        lock.unlock()
        
        for id in alreadyLoaded.subtracting(wanted) {
            SoundManager.shared.removeNamespacedSounds(withPrefix: "\(Self.packPrefix)\(id.uuidString)/")
            lock.lock(); packs[id] = nil; lock.unlock()
        }
        
        for id in wanted.subtracting(alreadyLoaded) {
            guard let soundpack = database.getSoundpack(by: id),
                  let config = SoundpackConfigManager.shared.config(for: soundpack) else {
                Logger.audio.warning("Language profile soundpack \(id.uuidString) is not installed")
                continue
            }
            let namespace = "\(Self.packPrefix)\(id.uuidString)"
            let files = config.sounds.values.flatMap { $0.down + $0.up }
            SoundManager.shared.loadNamespacedSounds(namespace: namespace, soundpack: soundpack, fileNames: files)
            
            func namespaced(_ pick: (KeySound) -> [String]) -> [String: [String]] {
                config.sounds.mapValues { pick($0).map { "\(namespace)/\($0)" } }
            }
            let pack = Pack(down: namespaced { $0.down }, up: namespaced { $0.up })
            lock.lock(); packs[id] = pack; lock.unlock()
        }
        
        SoundManager.shared.removeNamespacedSounds(withPrefix: Self.switchPrefix)
        for (profileID, path) in configuration.switchSoundPaths {
            SoundManager.shared.loadNamespacedSound(
                key: "\(Self.switchPrefix)\(profileID)",
                url: URL(fileURLWithPath: path),
                gain: configuration.switchSoundVolume
            )
        }
        Logger.audio.info("Profile sound bank ready: \(wanted.count) pack(s)")
    }
}
