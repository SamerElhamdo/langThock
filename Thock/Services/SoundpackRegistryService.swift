import Foundation


@MainActor
final class SoundpackRegistryService: ObservableObject {
    @Published var keyboardEntries: [SoundpackRegistryEntry] = []
    @Published var mouseEntries: [SoundpackRegistryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var downloadingIds: Set<UUID> = []
    @Published var installedIds: Set<UUID> = []
    @Published var customKeyboardSoundpacks: [Soundpack] = []
    @Published var customMouseSoundpacks: [Soundpack] = []
    
    init() {
        refreshInstalledIds()
    }
    
    func fetchManifest() async {
        isLoading = true
        errorMessage = nil
        
        // LangThock is strictly local: the online soundpack library is disabled. Installed and custom
        // soundpacks (Application Support/Thock/Soundpacks) are still listed.
        refreshInstalledIds()
        
        refreshCustomSoundpacks()
        isLoading = false
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    func install(_ entry: SoundpackRegistryEntry) async {
        guard !downloadingIds.contains(entry.id) else { return }
        downloadingIds.insert(entry.id)
        
        // Downloading is disabled (strictly local app). Install soundpacks by copying a folder into
        // ~/Library/Application Support/Thock/Soundpacks/.
        downloadingIds.remove(entry.id)
    }
    
    func uninstall(_ entry: SoundpackRegistryEntry) {
        let folder = customSoundsDirectory().appendingPathComponent(entry.id.uuidString)
        try? FileManager.default.removeItem(at: folder)
        SoundpackEngine.shared.reloadAfterRemoval(for: entry.category)
        refreshInstalledIds()
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    func refreshInstalledIds() {
        let base = customSoundsDirectory()
        guard let subdirs = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil
        ) else {
            installedIds = []
            return
        }
        installedIds = Set(subdirs.compactMap { UUID(uuidString: $0.lastPathComponent) })
    }
    
    func refreshCustomSoundpacks() {
        let registryIds = Set(keyboardEntries.map(\.id) + mouseEntries.map(\.id))
        let allInstalled = SoundpackDatabase.loadInstalled()
        let custom = allInstalled.filter { !registryIds.contains($0.id) }
        customKeyboardSoundpacks = custom.filter { $0.category == "keyboard" }
        customMouseSoundpacks = custom.filter { $0.category == "mouse" }
    }
    
    func uninstallCustom(_ soundpack: Soundpack) {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock")
        let folder = base.appendingPathComponent(soundpack.path)
        try? FileManager.default.removeItem(at: folder)
        SoundpackEngine.shared.reloadAfterRemoval(for: soundpack.category)
        refreshInstalledIds()
        refreshCustomSoundpacks()
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    private func customSoundsDirectory() -> URL {
        return CustomSoundpackHelper.getCustomSoundpackDirectory()
    }
}

extension Notification.Name {
    static let soundpackLibraryDidChange = Notification.Name("soundpackLibraryDidChange")
}
