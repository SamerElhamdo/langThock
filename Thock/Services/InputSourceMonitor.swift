import Foundation
import Carbon.HIToolbox
import OSLog

/// A macOS keyboard Input Source (layout or input mode).
struct InputSourceInfo: Equatable {
    /// e.g. `com.apple.keylayout.Arabic`
    let id: String
    /// Localized display name, e.g. "Arabic"
    let name: String
    /// BCP-47 language codes the source declares, e.g. `["ar"]`
    let languages: [String]
}

/// Reads the current macOS Input Source and forwards Input Source changes.
///
/// Detection is event-driven, never polled:
///  * `kTISNotifySelectedKeyboardInputSourceChanged` (Text Input Source Services, posted by macOS on the
///    distributed notification center) tells us as soon as the user switches source.
///  * `queryCurrent()` is a direct, synchronous TIS read. `KeyboardEventTracker` calls it on the first key
///    press of each key so the profile is right even if the notification is delivered late.
///
/// The source is identified through TIS (`kTISPropertyInputSourceID`), never by the character a key produced.
/// TIS must be used from the main thread; the event tap and the notification both run there.
final class InputSourceMonitor {
    static let shared = InputSourceMonitor()

    private var observer: NSObjectProtocol?
    private var onChange: ((InputSourceInfo?) -> Void)?

    private init() {}

    /// Starts observing. `onChange` is called on the main thread with the newly selected source.
    func start(onChange: @escaping (InputSourceInfo?) -> Void) {
        stop()
        self.onChange = onChange
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main,
            suspensionBehavior: .deliverImmediately
        ) { [weak self] _ in
            guard let self else { return }
            self.onChange?(self.queryCurrent())
        }
        Logger.engine.info("InputSourceMonitor started")
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        onChange = nil
    }

    // MARK: - Queries

    /// The currently selected keyboard Input Source (main thread only).
    func queryCurrent() -> InputSourceInfo? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.info(from: source)
    }

    /// Keyboard Input Sources the user has enabled in System Settings (main thread only).
    static func enabledSources() -> [InputSourceInfo] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue(),
              let sources = list as? [TISInputSource] else { return [] }

        var seen = Set<String>()
        return sources
            .compactMap { info(from: $0) }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Private

    private static func info(from source: TISInputSource) -> InputSourceInfo? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else { return nil }
        let name = stringProperty(source, kTISPropertyLocalizedName) ?? id
        var languages: [String] = []
        if let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
            languages = (Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String]) ?? []
        }
        return InputSourceInfo(id: id, name: name, languages: languages)
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
