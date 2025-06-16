//
//  Settings.swift
//  FreeWhisper
//
//  Created by user on 08.02.2025.
//

import AppKit
import Carbon
import Combine
import Foundation
import KeyboardShortcuts
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var selectedModelURL: URL? {
        didSet {
            if let url = selectedModelURL {
                AppPreferences.shared.selectedModelPath = url.path
            }
        }
    }

    @Published var availableModels: [URL] = []
    @Published var selectedLanguage: String {
        didSet {
            AppPreferences.shared.whisperLanguage = selectedLanguage
        }
    }

    @Published var translateToEnglish: Bool {
        didSet {
            AppPreferences.shared.translateToEnglish = translateToEnglish
        }
    }

    @Published var suppressBlankAudio: Bool {
        didSet {
            AppPreferences.shared.suppressBlankAudio = suppressBlankAudio
        }
    }

    @Published var showTimestamps: Bool {
        didSet {
            AppPreferences.shared.showTimestamps = showTimestamps
        }
    }
    
    @Published var temperature: Double {
        didSet {
            AppPreferences.shared.temperature = temperature
        }
    }

    @Published var noSpeechThreshold: Double {
        didSet {
            AppPreferences.shared.noSpeechThreshold = noSpeechThreshold
        }
    }

    @Published var initialPrompt: String {
        didSet {
            AppPreferences.shared.initialPrompt = initialPrompt
        }
    }

    @Published var useBeamSearch: Bool {
        didSet {
            AppPreferences.shared.useBeamSearch = useBeamSearch
        }
    }

    @Published var beamSize: Int {
        didSet {
            AppPreferences.shared.beamSize = beamSize
        }
    }

    @Published var debugMode: Bool {
        didSet {
            AppPreferences.shared.debugMode = debugMode
        }
    }
    
    @Published var playSoundOnRecordStart: Bool {
        didSet {
            AppPreferences.shared.playSoundOnRecordStart = playSoundOnRecordStart
        }
    }
    
    @Published var muteSystemAudioDuringRecording: Bool {
        didSet {
            AppPreferences.shared.muteSystemAudioDuringRecording = muteSystemAudioDuringRecording
        }
    }
    
    // New app behavior settings
    @Published var startAtLogin: Bool {
        didSet {
            LoginItemManager.shared.setStartAtLogin(startAtLogin)
        }
    }
    
    @Published var hideMainWindowOnReopen: Bool {
        didSet {
            AppPreferences.shared.hideMainWindowOnReopen = hideMainWindowOnReopen
        }
    }
    
    init() {
        let prefs = AppPreferences.shared
        self.selectedLanguage = prefs.whisperLanguage
        self.translateToEnglish = prefs.translateToEnglish
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.showTimestamps = prefs.showTimestamps
        self.temperature = prefs.temperature
        self.noSpeechThreshold = prefs.noSpeechThreshold
        self.initialPrompt = prefs.initialPrompt
        self.useBeamSearch = prefs.useBeamSearch
        self.beamSize = prefs.beamSize
        self.debugMode = prefs.debugMode
        self.playSoundOnRecordStart = prefs.playSoundOnRecordStart
        self.muteSystemAudioDuringRecording = prefs.muteSystemAudioDuringRecording
        self.startAtLogin = prefs.startAtLogin
        self.hideMainWindowOnReopen = prefs.hideMainWindowOnReopen
        
        if let savedPath = prefs.selectedModelPath {
            self.selectedModelURL = URL(fileURLWithPath: savedPath)
        }
        loadAvailableModels()
    }
    
    func loadAvailableModels() {
        availableModels = WhisperModelManager.shared.getAvailableModels()
        if selectedModelURL == nil {
            selectedModelURL = availableModels.first
        }
    }
}

struct Settings {
    var selectedLanguage: String
    var translateToEnglish: Bool
    var suppressBlankAudio: Bool
    var showTimestamps: Bool
    var temperature: Double
    var noSpeechThreshold: Double
    var initialPrompt: String
    var useBeamSearch: Bool
    var beamSize: Int
    
    init() {
        let prefs = AppPreferences.shared
        self.selectedLanguage = prefs.whisperLanguage
        self.translateToEnglish = prefs.translateToEnglish
        self.suppressBlankAudio = prefs.suppressBlankAudio
        self.showTimestamps = prefs.showTimestamps
        self.temperature = prefs.temperature
        self.noSpeechThreshold = prefs.noSpeechThreshold
        self.initialPrompt = prefs.initialPrompt
        self.useBeamSearch = prefs.useBeamSearch
        self.beamSize = prefs.beamSize
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: SettingsCategory = .shortcuts
    @State private var previousModelURL: URL?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SettingsSidebar(selectedCategory: $selectedCategory)
        } detail: {
            // Detail view
            SettingsDetailView(
                category: selectedCategory,
                viewModel: viewModel,
                onDismiss: {
                    if viewModel.selectedModelURL != previousModelURL {
                        if let modelPath = viewModel.selectedModelURL?.path {
                            TranscriptionService.shared.reloadModel(with: modelPath)
                        }
                    }
                    dismiss()
                }
            )
        }
        .frame(width: 800, height: 700)
        .onAppear {
            previousModelURL = viewModel.selectedModelURL
        }
    }
}

enum SettingsCategory: String, CaseIterable {
    case shortcuts = "Shortcuts"
    case model = "Model"
    case transcription = "Transcription"
    case advanced = "Advanced"
    
    var icon: String {
        switch self {
        case .shortcuts: return "command.circle.fill"
        case .model: return "cpu.fill"
        case .transcription: return "text.bubble.fill"
        case .advanced: return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .shortcuts: return .purple
        case .model: return .blue
        case .transcription: return .green
        case .advanced: return .orange
        }
    }
}

struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.linearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("FreeWhisper")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Navigation
            List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                SidebarRow(
                    category: category,
                    isSelected: selectedCategory == category
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack {
                    Text("v0.0.7")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        // Open about or help
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.controlBackgroundColor))
        .frame(width: 240)
    }
}

struct SidebarRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white  : Color.gray)
                    .frame(width: 28, height: 28)
                
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .white)
            }
            
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        )
        .contentShape(Rectangle())
    }
}

struct SettingsDetailView: View {
    let category: SettingsCategory
    @ObservedObject var viewModel: SettingsViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            DetailHeader(category: category, onDismiss: onDismiss)
            
            // Content
            ScrollView {
                LazyVStack(spacing: 24) {
                    switch category {
                    case .shortcuts:
                        ShortcutsContent(viewModel: viewModel)
                    case .model:
                        ModelContent(viewModel: viewModel)
                    case .transcription:
                        TranscriptionContent(viewModel: viewModel)
                    case .advanced:
                        AdvancedContent(viewModel: viewModel)
                    }
                }
                .padding(32)
            }
        }
        .background(Color(.windowBackgroundColor))
    }
}

struct DetailHeader: View {
    let category: SettingsCategory
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 16) {
                // Simplified icon - just outline with subtle accent
                Image(systemName: category.icon.replacingOccurrences(of: ".fill", with: ""))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(categoryDescription(category))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(GlassButtonStyle())
            .controlSize(.large)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color(.windowBackgroundColor).opacity(0.5))
                )
        )
    }
    
    private func categoryDescription(_ category: SettingsCategory) -> String {
        switch category {
        case .shortcuts: return "Configure global keyboard shortcuts"
        case .model: return "Manage AI models and storage"
        case .transcription: return "Language and output settings"
        case .advanced: return "Performance and debugging options"
        }
    }
}

// MARK: - Content Views

struct ShortcutsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Recording Controls",
                subtitle: "Global shortcuts for voice recording",
                icon: "command.square.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Toggle Recording",
                        subtitle: "Start or stop recording from anywhere",
                        icon: "record.circle"
                    ) {
                        KeyboardShortcuts.Recorder("", name: .toggleRecord)
                            .frame(width: 120)
                    }
                    
                    SettingRow(
                        title: "Sound Feedback",
                        subtitle: "Play sound when recording starts",
                        icon: "speaker.wave.2"
                    ) {
                        Toggle("", isOn: $viewModel.playSoundOnRecordStart)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    SettingRow(
                        title: "Mute System Audio",
                        subtitle: "Silence computer audio during recording",
                        icon: "speaker.slash.fill"
                    ) {
                        Toggle("", isOn: $viewModel.muteSystemAudioDuringRecording)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Quick Guide",
                subtitle: "How to use keyboard shortcuts",
                icon: "lightbulb.fill"
            ) {
                VStack(spacing: 12) {
                    GuideStep(number: 1, text: "Click the shortcut field above")
                    GuideStep(number: 2, text: "Press your desired key combination")
                    GuideStep(number: 3, text: "Use it globally across all apps")
                }
            }
        }
    }
}

struct ModelContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Active Model",
                subtitle: "Choose your transcription model",
                icon: "brain.head.profile.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Current Model",
                        subtitle: "Selected Whisper model",
                        icon: "cpu"
                    ) {
                        Picker("", selection: $viewModel.selectedModelURL) {
                            ForEach(viewModel.availableModels, id: \.self) { url in
                                Text(url.lastPathComponent)
                                    .tag(url as URL?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    SettingRow(
                        title: "Models Folder",
                        subtitle: "Open models directory",
                        icon: "folder"
                    ) {
                        Button("Open") {
                            NSWorkspace.shared.open(WhisperModelManager.shared.modelsDirectory)
                        }
                        .buttonStyle(GlassButtonStyle())
                        .controlSize(.small)
                    }
                }
            }
            
            GlassCard(
                title: "Download Models",
                subtitle: "Get additional Whisper models",
                icon: "arrow.down.circle.fill"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add GGML format models to the folder above, then restart the app.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Link("Browse Available Models", destination: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/tree/main")!)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct TranscriptionContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Language Settings",
                subtitle: "Configure input and output language",
                icon: "globe.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Source Language",
                        subtitle: "Language of your audio",
                        icon: "textformat.abc"
                    ) {
                        Picker("", selection: $viewModel.selectedLanguage) {
                            ForEach(LanguageUtil.availableLanguages, id: \.self) { code in
                                Text(LanguageUtil.languageNames[code] ?? code)
                                    .tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    SettingRow(
                        title: "Auto-translate",
                        subtitle: "Translate to English",
                        icon: "translate"
                    ) {
                        Toggle("", isOn: $viewModel.translateToEnglish)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Output Format",
                subtitle: "Customize transcription output",
                icon: "doc.text.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Include Timestamps",
                        subtitle: "Show timing information",
                        icon: "clock"
                    ) {
                        Toggle("", isOn: $viewModel.showTimestamps)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    SettingRow(
                        title: "Skip Silent Parts",
                        subtitle: "Suppress blank audio",
                        icon: "speaker.slash"
                    ) {
                        Toggle("", isOn: $viewModel.suppressBlankAudio)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Context Prompt",
                subtitle: "Guide the AI with context",
                icon: "text.cursor.fill"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    GlassTextEditor(text: $viewModel.initialPrompt)
                    
                    Text("Add names, terminology, or context to improve accuracy")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AdvancedContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // New App Behavior Card
            GlassCard(
                title: "App Behavior",
                subtitle: "Customize startup and window behavior",
                icon: "gearshape.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Start at Login",
                        subtitle: "Launch automatically when you log in",
                        icon: "arrow.right.circle"
                    ) {
                        Toggle("", isOn: $viewModel.startAtLogin)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    SettingRow(
                        title: "Hide Window on Reopen",
                        subtitle: "After setup, keep app in menu bar only",
                        icon: "eye.slash"
                    ) {
                        Toggle("", isOn: $viewModel.hideMainWindowOnReopen)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Processing Strategy",
                subtitle: "Control transcription behavior",
                icon: "gearshape.2.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Beam Search",
                        subtitle: "More accurate, slower processing",
                        icon: "arrow.triangle.branch"
                    ) {
                        Toggle("", isOn: $viewModel.useBeamSearch)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    if viewModel.useBeamSearch {
                        SettingRow(
                            title: "Beam Size",
                            subtitle: "Number of search paths",
                            icon: "number.square"
                        ) {
                            HStack {
                                Stepper("", value: $viewModel.beamSize, in: 1...10)
                                    .frame(width: 60)
                                Text("\(viewModel.beamSize)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(width: 30)
                            }
                        }
                    }
                }
            }
            
            GlassCard(
                title: "Model Parameters",
                subtitle: "Fine-tune AI behavior",
                icon: "slider.horizontal.3"
            ) {
                VStack(spacing: 20) {
                    SliderSetting(
                        title: "Temperature",
                        subtitle: "Randomness in output",
                        icon: "thermometer",
                        value: $viewModel.temperature,
                        range: 0.0...1.0
                    )
                    
                    SliderSetting(
                        title: "Silence Threshold",
                        subtitle: "Sensitivity for detecting speech",
                        icon: "waveform.path",
                        value: $viewModel.noSpeechThreshold,
                        range: 0.0...1.0
                    )
                }
            }
            
            GlassCard(
                title: "Development",
                subtitle: "Debug and troubleshooting",
                icon: "ladybug.fill"
            ) {
                SettingRow(
                    title: "Debug Mode",
                    subtitle: "Enable detailed logging",
                    icon: "terminal"
                ) {
                    Toggle("", isOn: $viewModel.debugMode)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct GlassCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: Content
    
    init(title: String, subtitle: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: Content
    
    init(title: String, subtitle: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content
        }
    }
}

struct SliderSetting: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.2f", value))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: 0.1)
                .tint(.accentColor)
        }
    }
}

struct GuideStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.linearGradient(colors: [.blue.opacity(0.7),], startPoint: .topLeading, endPoint: .bottomTrailing)))
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct GlassTextEditor: View {
    @Binding var text: String
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .frame(height: 80)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    SettingsView()
}
