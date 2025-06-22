import SwiftUI

struct SettingsDetailView: View {
    let category: SettingsCategory
    @ObservedObject var viewModel: SettingsViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.fullName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(headerDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Content
                VStack(spacing: 32) {
                    switch category {
                    case .shortcuts:
                        ShortcutsContent(viewModel: viewModel)
                    case .voiceCommands:
                        VoiceCommandsContent(viewModel: viewModel)
                    case .model:
                        ModelContent(viewModel: viewModel)
                    case .transcription:
                        TranscriptionContent(viewModel: viewModel)
                    case .advanced:
                        AdvancedContent(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.windowBackgroundColor))
        .frame(minWidth: 600)
    }
    
    private var headerDescription: String {
        switch category {
        case .shortcuts:
            return "Configure global keyboard shortcuts"
        case .voiceCommands:
            return "Create and manage voice-activated actions"
        case .model:
            return "Select and manage Whisper models"
        case .transcription:
            return "Configure speech recognition settings"
        case .advanced:
            return "Fine-tune app behavior and performance"
        }
    }
} 