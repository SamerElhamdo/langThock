import Foundation

/// Strings for the language-aware features. English only for now; the existing `L10n` table
/// (9 languages) is left untouched.
enum LangL10n {
    static let currentInputSource = "Current Input Source:"
    static let currentSoundProfile = "Current Sound Profile:"
    static let languageSwitchSounds = "Language Switch Sounds"
    static let languagesTab = "Languages"
    
    static func status(_ name: String?) -> String { "● \(name ?? "Unknown")" }
    
    // Settings
    static let inputSources = "Input Sources"
    static let inputSourcesSubtitle = "Choose which sound profile plays for each keyboard layout you have enabled in macOS."
    static let soundProfiles = "Sound Profiles"
    static let soundProfilesSubtitle = "A profile plays the sounds of one installed keyboard soundpack. Install soundpacks under Application Support/Thock/Soundpacks."
    static let useCurrentSoundpack = "Current keyboard soundpack"
    static let newProfile = "New Custom Profile"
    static let deleteProfile = "Delete"
    static let languageSwitch = "Language Switch"
    static let playSwitchSound = "Play sound when input source changes"
    static let playSwitchSoundSubtitle = "Plays the sound of the profile you switch to. Not played when both sources use the same profile."
    static let switchSoundVolume = "Switch sound volume"
    static let select = "Select"
    static let clear = "Clear"
    static let none = "None"
    static let preview = "Preview"
    static let previewKey = "Key"
    static let previewSpace = "Space"
    static let previewEnter = "Enter"
    static let previewBackspace = "Backspace"
    
    // Permissions onboarding
    static let permissionTitle = "Keyboard monitoring permission"
    static let permissionBody = "LangThock needs keyboard monitoring permission to detect key presses and play sounds. It never stores or sends what you type."
    static let openSystemSettings = "Open System Settings"
}
