import SwiftUI

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