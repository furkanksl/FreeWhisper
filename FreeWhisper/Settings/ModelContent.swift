import SwiftUI

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