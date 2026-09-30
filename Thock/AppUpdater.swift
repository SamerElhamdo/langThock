import Foundation

/// LangThock is strictly local: it never contacts a server, so there is no update check.
/// Kept as a stub so the existing menu/settings call sites keep working unchanged.
class AppUpdater {
    static let shared = AppUpdater()

    private init() {}

    func checkForUpdates(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }
}
