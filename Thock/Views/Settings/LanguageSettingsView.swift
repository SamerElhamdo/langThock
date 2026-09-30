import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Settings tab for language-aware sounds: Input Source mapping, Sound Profiles and switch sounds.
struct LanguageSettingsView: View {
    private let store = LanguageSoundStore.shared
    
    @State private var config = LanguageSoundStore.shared.configuration
    @State private var sources: [InputSourceInfo] = InputSourceMonitor.enabledSources()
    @State private var soundpacks: [Soundpack] = SoundpackDatabase().getSoundpacks(for: "keyboard")
    @State private var active = SoundProfileManager.shared.currentState
    @State private var switchVolume: Double = Double(LanguageSoundStore.shared.configuration.switchSoundVolume)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Spacer().frame(height: 30)
                
                statusSection
                inputSourcesSection
                profilesSection
                switchSection
                
                Spacer()
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .languageSoundConfigurationDidChange)) { _ in
            config = store.configuration
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeSoundProfileDidChange)) { _ in
            active = SoundProfileManager.shared.currentState
        }
        .onReceive(NotificationCenter.default.publisher(for: .soundpackLibraryDidChange)) { _ in
            soundpacks = SoundpackDatabase().getSoundpacks(for: "keyboard")
        }
        .onAppear {
            sources = InputSourceMonitor.enabledSources()
            soundpacks = SoundpackDatabase().getSoundpacks(for: "keyboard")
        }
    }
    
    // MARK: - Status
    
    private var statusSection: some View {
        SettingsSectionView(title: LangL10n.currentInputSource.replacingOccurrences(of: ":", with: "")) {
            SettingsRowView(
                title: LangL10n.status(active.source?.name),
                subtitle: active.source?.id,
                control: AnyView(Text(LangL10n.status(active.profile.name)).foregroundColor(.secondary)),
                isLast: true
            )
        }
    }
    
    // MARK: - Input Sources
    
    private var inputSourcesSection: some View {
        SettingsSectionView(title: LangL10n.inputSources) {
            SettingsRowView(title: LangL10n.inputSourcesSubtitle, subtitle: nil, control: AnyView(EmptyView()), isLast: sources.isEmpty)
            ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                SettingsRowView(
                    title: source.name,
                    subtitle: source.id,
                    control: AnyView(profilePicker(for: source)),
                    isLast: index == sources.count - 1
                )
            }
        }
    }
    
    private func profilePicker(for source: InputSourceInfo) -> some View {
        let selection = Binding<String>(
            get: {
                SoundProfileResolver(configuration: config)
                    .resolve(inputSourceID: source.id, languages: source.languages).id
            },
            set: { newID in store.update { $0.inputSourceMap[source.id] = newID } }
        )
        return Picker("", selection: selection) {
            ForEach(config.profiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: 180)
    }
    
    // MARK: - Sound Profiles
    
    private var profilesSection: some View {
        SettingsSectionView(title: LangL10n.soundProfiles, trailing: {
            Button(LangL10n.newProfile) { addProfile() }
                .controlSize(.small)
        }) {
            SettingsRowView(title: LangL10n.soundProfilesSubtitle, subtitle: nil, control: AnyView(EmptyView()))
            ForEach(Array(config.profiles.enumerated()), id: \.element.id) { index, profile in
                profileRow(profile, isLast: index == config.profiles.count - 1)
            }
        }
    }
    
    private func profileRow(_ profile: SoundProfile, isLast: Bool) -> some View {
        let soundpackSelection = Binding<UUID?>(
            get: { profile.soundpackId },
            set: { newID in updateProfile(profile.id) { $0.soundpackId = newID } }
        )
        let nameBinding = Binding<String>(
            get: { profile.name },
            set: { newName in updateProfile(profile.id) { $0.name = newName } }
        )
        
        return VStack(spacing: 0) {
            HStack {
                if profile.isBuiltIn {
                    Text(profile.name).font(.system(size: 13, weight: .medium))
                } else {
                    TextField("", text: nameBinding).textFieldStyle(.roundedBorder).frame(width: 160)
                }
                Spacer()
                Picker("", selection: soundpackSelection) {
                    Text(LangL10n.useCurrentSoundpack).tag(UUID?.none)
                    ForEach(soundpacks, id: \.id) { pack in
                        Text(pack.name).tag(Optional(pack.id))
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 220)
                if !profile.isBuiltIn {
                    Button(LangL10n.deleteProfile) { deleteProfile(profile.id) }.controlSize(.small)
                }
            }
            HStack(spacing: 6) {
                Text(LangL10n.preview).font(.system(size: 11)).foregroundColor(.secondary)
                previewButton(LangL10n.previewKey, profile, "a")
                previewButton(LangL10n.previewSpace, profile, "space")
                previewButton(LangL10n.previewEnter, profile, "enter")
                previewButton(LangL10n.previewBackspace, profile, "del")
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLast { Divider().padding(.horizontal, 10) }
        }
    }
    
    private func previewButton(_ title: String, _ profile: SoundProfile, _ keyType: String) -> some View {
        Button("▶ \(title)") { SoundEngine.shared.preview(profile: profile, keyType: keyType) }
            .controlSize(.small)
    }
    
    // MARK: - Language Switch
    
    private var switchSection: some View {
        SettingsSectionView(title: LangL10n.languageSwitch) {
            SettingsRowView(
                title: LangL10n.playSwitchSound,
                subtitle: LangL10n.playSwitchSoundSubtitle,
                control: AnyView(
                    Toggle("", isOn: Binding(
                        get: { config.switchSoundEnabled },
                        set: { value in store.update { $0.switchSoundEnabled = value } }
                    ))
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                )
            )
            
            ForEach(config.profiles) { profile in
                SettingsRowView(
                    title: "\(profile.name) switch sound",
                    subtitle: config.switchSoundPaths[profile.id].map { URL(fileURLWithPath: $0).lastPathComponent } ?? LangL10n.none,
                    control: AnyView(
                        HStack {
                            Button("▶") { SoundEngine.shared.playSwitchSound(for: profile) }
                                .controlSize(.small)
                                .disabled(config.switchSoundPaths[profile.id] == nil)
                            Button(LangL10n.select) { chooseSwitchSound(for: profile.id) }.controlSize(.small)
                            Button(LangL10n.clear) {
                                store.update { $0.switchSoundPaths[profile.id] = nil }
                            }
                            .controlSize(.small)
                            .disabled(config.switchSoundPaths[profile.id] == nil)
                        }
                    )
                )
            }
            
            SettingsRowView(
                title: LangL10n.switchSoundVolume,
                subtitle: nil,
                control: AnyView(
                    Slider(value: $switchVolume, in: 0...1) { editing in
                        if !editing { store.update { $0.switchSoundVolume = Float(switchVolume) } }
                    }
                    .frame(width: 180)
                ),
                isLast: true
            )
        }
    }
    
    // MARK: - Actions
    
    private func updateProfile(_ id: String, _ edit: @escaping (inout SoundProfile) -> Void) {
        store.update { cfg in
            if let i = cfg.profiles.firstIndex(where: { $0.id == id }) { edit(&cfg.profiles[i]) }
        }
    }
    
    private func addProfile() {
        store.update { cfg in
            let n = cfg.profiles.filter { !$0.isBuiltIn }.count + 1
            cfg.profiles.append(SoundProfile(id: "custom-\(UUID().uuidString)", name: "Custom \(n)", soundpackId: nil, isBuiltIn: false))
        }
    }
    
    private func deleteProfile(_ id: String) {
        store.update { cfg in
            cfg.profiles.removeAll { $0.id == id && !$0.isBuiltIn }
            cfg.inputSourceMap = cfg.inputSourceMap.filter { $0.value != id }
            cfg.languageMap = cfg.languageMap.filter { $0.value != id }
            cfg.switchSoundPaths[id] = nil
            if cfg.defaultProfileID == id { cfg.defaultProfileID = SoundProfile.defaultID }
        }
    }
    
    private func chooseSwitchSound(for profileID: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.update { $0.switchSoundPaths[profileID] = url.path }
    }
}

#Preview("Settings/Languages") {
    LanguageSettingsView()
        .frame(width: 500, height: 600)
}
