import Foundation

/// Strings for the language-aware features: English and Arabic. The existing `L10n` table (now 10 languages)
/// is used for everything else. Any language other than Arabic falls back to English here.
enum LangL10n {
    private static var isArabic: Bool { LocalizationManager.shared.current == .arabic }
    private static func t(_ en: String, _ ar: String) -> String { isArabic ? ar : en }

    // Menu bar
    static var currentInputSource: String { t("Current Input Source:", "مصدر الإدخال الحالي:") }
    static var currentSoundProfile: String { t("Current Sound Profile:", "ملف الصوت الحالي:") }
    static var languageSwitchSounds: String { t("Language Switch Sounds", "أصوات تبديل اللغة") }
    static var languagesTab: String { t("Languages", "اللغات") }
    static var unknown: String { t("Unknown", "غير معروف") }

    static func status(_ name: String?) -> String { "● \(name ?? unknown)" }

    // Settings
    static var inputSources: String { t("Input Sources", "مصادر الإدخال") }
    static var inputSourcesSubtitle: String {
        t("Choose which sound profile plays for each keyboard layout you have enabled in macOS.",
          "اختر ملف الصوت الذي يُشغَّل لكل تخطيط لوحة مفاتيح مفعّل في macOS.")
    }
    static var soundProfiles: String { t("Sound Profiles", "ملفات الصوت") }
    static var soundProfilesSubtitle: String {
        t("A profile plays the sounds of one installed keyboard soundpack. Install soundpacks under Application Support/Thock/Soundpacks.",
          "يشغّل كل ملف أصوات حزمة واحدة مثبّتة من حزم لوحة المفاتيح. ضع الحزم في Application Support/Thock/Soundpacks.")
    }
    static var useCurrentSoundpack: String { t("Current keyboard soundpack", "حزمة لوحة المفاتيح الحالية") }
    static var newProfile: String { t("New Custom Profile", "ملف مخصص جديد") }
    static var deleteProfile: String { t("Delete", "حذف") }
    static var languageSwitch: String { t("Language Switch", "تبديل اللغة") }
    static var playSwitchSound: String { t("Play sound when input source changes", "تشغيل صوت عند تغيّر مصدر الإدخال") }
    static var playSwitchSoundSubtitle: String {
        t("Plays the sound of the profile you switch to. Not played when both sources use the same profile.",
          "يشغّل صوت الملف الذي انتقلت إليه. لا يُشغَّل إذا كان المصدران يستخدمان الملف نفسه.")
    }
    static var switchSoundVolume: String { t("Switch sound volume", "مستوى صوت التبديل") }
    static func switchSound(for profileName: String) -> String {
        t("\(profileName) switch sound", "صوت التبديل إلى «\(profileName)»")
    }
    static var select: String { t("Select", "اختيار") }
    static var clear: String { t("Clear", "مسح") }
    static var none: String { t("None", "لا شيء") }
    static var preview: String { t("Preview", "معاينة") }
    static var previewKey: String { t("Key", "حرف") }
    static var previewSpace: String { t("Space", "مسافة") }
    static var previewEnter: String { t("Enter", "إدخال") }
    static var previewBackspace: String { t("Backspace", "حذف") }
    static func customProfileName(_ n: Int) -> String { t("Custom \(n)", "مخصص \(n)") }

    // Permissions onboarding
    static var permissionTitle: String { t("Keyboard monitoring permission", "صلاحية مراقبة لوحة المفاتيح") }
    static var permissionBody: String {
        t("LangThock needs keyboard monitoring permission to detect key presses and play sounds. It never stores or sends what you type.",
          "يحتاج LangThock إلى صلاحية مراقبة لوحة المفاتيح ليكتشف الضغطات ويشغّل الأصوات. لا يخزّن ما تكتبه ولا يرسله أبداً.")
    }
    static var openSystemSettings: String { t("Open System Settings", "فتح إعدادات النظام") }

    /// Text/layout direction for the current app language.
    static var isRightToLeft: Bool { isArabic }
}

extension SoundProfile {
    /// Built-in profiles are shown in the app language; custom profiles keep the name the user typed.
    var displayName: String {
        guard isBuiltIn else { return name }
        switch id {
        case SoundProfile.defaultID: return LocalizationManager.shared.current == .arabic ? "الافتراضي" : name
        case SoundProfile.arabicID: return LocalizationManager.shared.current == .arabic ? "العربية" : name
        case SoundProfile.englishID: return LocalizationManager.shared.current == .arabic ? "الإنجليزية" : name
        default: return name
        }
    }
}
