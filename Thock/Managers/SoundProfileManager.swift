import Foundation

extension Notification.Name {
    /// Posted after the active Input Source and/or Sound Profile changed.
    /// `userInfo["transition"]` holds a `SoundProfileManager.Transition`.
    static let activeSoundProfileDidChange = Notification.Name("activeSoundProfileDidChange")
}

/// Owns "which Sound Profile is active right now".
///
///     macOS Input Source ──▶ SoundProfileResolver ──▶ active profile ──▶ next key press
///
/// The active profile is a plain in-memory value, so looking it up while typing is a lock + copy.
/// It is updated from two directions, both synchronous and both idempotent:
///  1. `InputSourceMonitor`'s change notification (`apply(inputSource:)`).
///  2. `profileForKeyPress()`, called for the first press of each key, which re-reads the Input Source
///     directly. This closes the race where the user switches language and types immediately while the
///     system notification has not been delivered yet: the key press itself observes the new source
///     *before* its sound is chosen. No sleep, no debounce.
final class SoundProfileManager {
    static let shared = SoundProfileManager()

    struct State: Equatable {
        var source: InputSourceInfo?
        var profile: SoundProfile
    }

    struct Transition {
        let from: State
        let to: State
    }

    /// Called synchronously (same thread as the trigger) when the Input Source changed profile or source.
    var onTransition: ((Transition) -> Void)?

    private let store: LanguageSoundStore
    private let querySource: () -> InputSourceInfo?
    private let lock = NSLock()
    private var state: State
    private var tracksInputSource: Bool
    private var configObserver: NSObjectProtocol?

    init(
        store: LanguageSoundStore = .shared,
        querySource: @escaping () -> InputSourceInfo? = { InputSourceMonitor.shared.queryCurrent() }
    ) {
        self.store = store
        self.querySource = querySource
        let config = store.configuration
        state = State(source: nil, profile: config.defaultProfile)
        tracksInputSource = config.needsInputSourceTracking

        configObserver = NotificationCenter.default.addObserver(
            forName: .languageSoundConfigurationDidChange,
            object: store,
            queue: nil
        ) { [weak self] _ in
            self?.configurationDidChange()
        }
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    }

    // MARK: - Reading

    var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    var currentProfile: SoundProfile { currentState.profile }

    /// Hot path. Returns the profile for a key that was just pressed, after verifying the Input Source.
    /// Skipped entirely (no TIS call) while nothing depends on the language.
    func profileForKeyPress() -> SoundProfile {
        lock.lock()
        let shouldCheck = tracksInputSource
        lock.unlock()
        if shouldCheck {
            apply(inputSource: querySource())
        }
        return currentProfile
    }

    // MARK: - Updating

    /// Reads the Input Source now and updates state. Call once at launch.
    func syncNow() {
        apply(inputSource: querySource())
    }

    /// Applies an observed Input Source. No-op if it is the one already active.
    @discardableResult
    func apply(inputSource: InputSourceInfo?) -> Transition? {
        guard let inputSource else { return nil }

        lock.lock()
        let old = state
        if old.source == inputSource {
            lock.unlock()
            return nil
        }
        let profile = SoundProfileResolver(configuration: store.configuration)
            .resolve(inputSourceID: inputSource.id, languages: inputSource.languages)
        let new = State(source: inputSource, profile: profile)
        state = new
        lock.unlock()

        let transition = Transition(from: old, to: new)
        onTransition?(transition)
        NotificationCenter.default.post(name: .activeSoundProfileDidChange, object: self, userInfo: ["transition": transition])
        return transition
    }

    /// The profile whose switch sound should play for `transition`, if any.
    /// Only when the audible profile really changes (Arabic -> ABC), not for ABC -> U.S., and never for
    /// the initial detection at launch.
    func switchSoundProfile(for transition: Transition) -> SoundProfile? {
        guard store.configuration.switchSoundEnabled,
              transition.from.source != nil,
              transition.from.profile.id != transition.to.profile.id else { return nil }
        return transition.to.profile
    }

    // MARK: - Configuration changes

    private func configurationDidChange() {
        let config = store.configuration
        lock.lock()
        tracksInputSource = config.needsInputSourceTracking
        let old = state
        let profile = SoundProfileResolver(configuration: config)
            .resolve(inputSourceID: old.source?.id, languages: old.source?.languages ?? [])
        let changed = profile != old.profile
        if changed { state.profile = profile }
        let new = state
        lock.unlock()

        if changed {
            // Mapping edited by the user: update silently (no switch sound), refresh UI.
            NotificationCenter.default.post(
                name: .activeSoundProfileDidChange,
                object: self,
                userInfo: ["transition": Transition(from: old, to: new)]
            )
        }
    }
}
