import Foundation
import OSLog

extension Notification.Name {
    /// Posted (object: the store) after the language-sound configuration was edited.
    static let languageSoundConfigurationDidChange = Notification.Name("languageSoundConfigurationDidChange")
}

/// Persists `LanguageSoundConfiguration` in UserDefaults (local only) and keeps a copy in memory.
/// Reads never touch disk, so the key-press path can use the configuration freely.
final class LanguageSoundStore {
    static let shared = LanguageSoundStore()

    private let defaults: UserDefaults
    private let defaultsKey = "languageSoundConfiguration"
    private let lock = NSLock()
    private var current: LanguageSoundConfiguration

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(LanguageSoundConfiguration.self, from: data) {
            current = decoded
        } else {
            current = .default
        }
    }

    var configuration: LanguageSoundConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// Applies an edit, persists it and notifies observers.
    func update(_ edit: (inout LanguageSoundConfiguration) -> Void) {
        lock.lock()
        var updated = current
        edit(&updated)
        guard updated != current else {
            lock.unlock()
            return
        }
        current = updated
        lock.unlock()

        do {
            defaults.set(try JSONEncoder().encode(updated), forKey: defaultsKey)
        } catch {
            Logger.engine.error("Failed to persist language sound configuration: \(error)")
        }
        NotificationCenter.default.post(name: .languageSoundConfigurationDidChange, object: self)
    }
}
