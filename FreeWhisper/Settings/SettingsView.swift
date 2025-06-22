import AppKit
import Carbon
import Combine
import Foundation
import KeyboardShortcuts
import SwiftUI

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
        .frame(width: 1000, height: 700)
        .onAppear {
            previousModelURL = viewModel.selectedModelURL
        }
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
                    Text(category.fullName)
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
        case .voiceCommands: return "Manage voice commands"
        case .model: return "Manage AI models and storage"
        case .transcription: return "Language and output settings"
        case .advanced: return "Performance and debugging options"
        }
    }
} 


#Preview {
    // Completely standalone preview without any dependencies
    NavigationSplitView {
        // Sidebar
        List {
            NavigationLink("Shortcuts", destination: Text("Shortcuts Settings"))
            NavigationLink("Voice Commands", destination: Text("Voice Commands Settings"))
            NavigationLink("Model", destination: Text("Model Settings"))
        }
        .navigationTitle("Settings")
    } detail: {
        // Detail view
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Select a category from the sidebar")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
    .frame(width: 800, height: 600)
}
