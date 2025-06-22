import SwiftUI

struct VoiceCommandsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @StateObject private var voiceCommandStore = VoiceCommandStore.shared
    @State private var showingAddCommand = false
    @State private var editingCommand: VoiceCommand?
    @State private var commandToDelete: VoiceCommand?
    @State private var showingDeleteConfirmation = false
    
    // Add state variables for the toggle switches
    @State private var isVoiceCommandsEnabled = true
    @State private var showFeedback = true
    @State private var preventSavingCommands = false
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Voice Commands",
                subtitle: "Configure voice commands to control your system",
                icon: "mic.fill"
            ) {
                VStack(spacing: 16) {
                    // Toggle switches
                    VStack(spacing: 12) {
                        SettingRow(
                            title: "Enable Voice Commands",
                            subtitle: "Allow voice commands to trigger actions",
                            icon: "mic.circle"
                        ) {
                            Toggle("", isOn: $isVoiceCommandsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        }
                        
                        SettingRow(
                            title: "Show Feedback",
                            subtitle: "Display notifications when commands are executed",
                            icon: "bell.circle"
                        ) {
                            Toggle("", isOn: $showFeedback)
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        }
                        
                        SettingRow(
                            title: "Prevent Saving Commands",
                            subtitle: "Don't save voice commands as transcriptions",
                            icon: "minus.circle"
                        ) {
                            Toggle("", isOn: $preventSavingCommands)
                                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Commands management
                    HStack {
                        Text("Voice Commands")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Add Command") {
                            showingAddCommand = true
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    
                    if voiceCommandStore.commands.isEmpty {
                        EmptyCommandsView()
                    } else {
                        CommandsList(commands: voiceCommandStore.commands) { command in
                            editingCommand = command
                        } onDelete: { command in
                            commandToDelete = command
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            
            QuickExamplesCard()
        }
        .sheet(isPresented: $showingAddCommand) {
            AddVoiceCommandView { command in
                Task {
                    await voiceCommandStore.addCommand(command)
                }
            }
        }
        .sheet(item: $editingCommand) { command in
            EditVoiceCommandView(command: command) { updatedCommand in
                Task {
                    await voiceCommandStore.updateCommand(updatedCommand)
                }
            } onCommandDeleted: { deletedCommand in
                commandToDelete = deletedCommand
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete Voice Command",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let command = commandToDelete {
                Task {
                        await voiceCommandStore.deleteCommand(command)
                    }
                }
                commandToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                commandToDelete = nil
            }
        } message: {
            if let command = commandToDelete {
                Text("Are you sure you want to delete the voice command \"\(command.phrase)\"? This action cannot be undone.")
            }
        }
        .task {
            await voiceCommandStore.loadCommands()
        }
    }
}

struct EmptyCommandsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Voice Commands")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Add your first voice command to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
    }
}

struct CommandsList: View {
    let commands: [VoiceCommand]
    let onEdit: (VoiceCommand) -> Void
    let onDelete: (VoiceCommand) -> Void
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(commands) { command in
                CommandRow(command: command, onEdit: onEdit, onDelete: onDelete)
            }
        }
    }
}

struct CommandRow: View {
    let command: VoiceCommand
    let onEdit: (VoiceCommand) -> Void
    let onDelete: (VoiceCommand) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(command.phrase)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(actionDescription(for: command.action))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Edit") {
                    onEdit(command)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
                
                Button("Delete") {
                    onDelete(command)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func actionDescription(for action: VoiceCommandAction) -> String {
        switch action {
        case .shellCommand(let command):
            return "Shell: \(command)"
        case .keyboardShortcut(let combination):
            let modifiers = combination.modifiers.map { $0.symbol }.joined()
            return "Shortcut: \(modifiers)\(combination.key)"
        }
    }
}

struct QuickExamplesCard: View {
    var body: some View {
        GlassCard(
            title: "Quick Examples",
            subtitle: "Common voice commands you can add",
            icon: "lightbulb"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                let examples = [
                    ("Say phrases like \"open spotify\" to launch apps", "app.badge"),
                    ("Use \"align right\" for keyboard shortcuts", "keyboard"),
                    ("Try \"take screenshot\" for system actions", "camera.viewfinder")
                ]
                
                ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                    FeaturePoint(text: example.0, icon: example.1)
                }
            }
        }
    }
}

struct FeaturePoint: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    // Completely standalone preview without any custom components
    ScrollView {
        VStack(spacing: 20) {
            // Header Card
            VStack(spacing: 16) {
                // Title section
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Voice Commands")
                            .font(.headline)
                        Text("Configure voice commands to control your system")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Toggle switches
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Voice Commands")
                                .font(.system(size: 14, weight: .medium))
                            Text("Allow voice commands to trigger actions")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Feedback")
                                .font(.system(size: 14, weight: .medium))
                            Text("Display notifications when commands are executed")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prevent Saving Commands")
                                .font(.system(size: 14, weight: .medium))
                            Text("Don't save voice commands as transcriptions")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(false))
                    }
                }
                
                Divider()
                
                // Commands header
                HStack {
                    Text("Voice Commands")
                        .font(.headline)
                    Spacer()
                    Button("Add Command") { }
                        .buttonStyle(.borderedProminent)
                }
                
                // Sample commands
                VStack(spacing: 8) {
                    // Sample command 1
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("open spotify")
                                .font(.system(size: 14, weight: .medium))
                            Text("Shell: open -a 'Spotify'")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit") { }
                            .foregroundColor(.blue)
                        Button("Delete") { }
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Sample command 2
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("take screenshot")
                                .font(.system(size: 14, weight: .medium))
                            Text("Shortcut: ⌘⇧4")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit") { }
                            .foregroundColor(.blue)
                        Button("Delete") { }
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Examples Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Quick Examples")
                            .font(.headline)
                        Text("Common voice commands you can add")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "app.badge")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Say phrases like \"open spotify\" to launch apps")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Use \"align right\" for keyboard shortcuts")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Try \"take screenshot\" for system actions")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding()
    }
    .frame(width: 600, height: 700)
} 