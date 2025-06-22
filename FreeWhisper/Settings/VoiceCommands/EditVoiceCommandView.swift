import SwiftUI

struct EditVoiceCommandView: View {
    @Environment(\.dismiss) var dismiss
    let command: VoiceCommand
    let onCommandUpdated: (VoiceCommand) -> Void
    let onCommandDeleted: (VoiceCommand) -> Void
    
    @State private var phrase: String
    @State private var selectedActionType: ActionType
    @State private var selectedApp: AppInfo?
    @State private var customShellCommand: String
    @State private var selectedModifiers: Set<KeyModifier> = []
    @State private var selectedKey: String
    @State private var isEnabled: Bool
    @State private var availableApps: [AppInfo] = []
    @State private var isLoadingApps = true
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    
    enum ActionType: String, CaseIterable, Identifiable {
        case launchApp = "Launch App"
        case keyboardShortcut = "Keyboard Shortcut"
        case customCommand = "Custom Command"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .launchApp: return "app.badge"
            case .keyboardShortcut: return "keyboard"
            case .customCommand: return "terminal"
            }
        }
    }
    
    init(command: VoiceCommand, onCommandUpdated: @escaping (VoiceCommand) -> Void = { _ in }, onCommandDeleted: @escaping (VoiceCommand) -> Void = { _ in }) {
        self.command = command
        self.onCommandUpdated = onCommandUpdated
        self.onCommandDeleted = onCommandDeleted
        
        // Initialize state from the command
        _phrase = State(initialValue: command.phrase)
        _isEnabled = State(initialValue: command.isEnabled)
        
        // Determine action type and initialize related state
        switch command.action {
        case .shellCommand(let cmd):
            if cmd.hasPrefix("open -a") {
                _selectedActionType = State(initialValue: .launchApp)
                _customShellCommand = State(initialValue: "")
                _selectedKey = State(initialValue: "")
                
                // Extract app name from command - will be set after apps load
                let appNamePattern = "open -a '(.+)'"
                if let regex = try? NSRegularExpression(pattern: appNamePattern),
                   let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
                   let range = Range(match.range(at: 1), in: cmd) {
                    let appName = String(cmd[range])
                    // selectedApp will be set when apps are loaded
                    _searchText = State(initialValue: appName)
                }
            } else {
                _selectedActionType = State(initialValue: .customCommand)
                _customShellCommand = State(initialValue: cmd)
                _selectedKey = State(initialValue: "")
            }
            
        case .keyboardShortcut(let combo):
            _selectedActionType = State(initialValue: .keyboardShortcut)
            _customShellCommand = State(initialValue: "")
            _selectedModifiers = State(initialValue: Set(combo.modifiers))
            _selectedKey = State(initialValue: combo.key)
        }
    }
    
    var isFormValid: Bool {
        let phraseValid = !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        switch selectedActionType {
        case .launchApp:
            return phraseValid && selectedApp != nil
        case .keyboardShortcut:
            return phraseValid && !selectedKey.isEmpty && !selectedModifiers.isEmpty
        case .customCommand:
            return phraseValid && !customShellCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return availableApps
        } else {
            return availableApps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Voice Command")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Modify your voice-activated action")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Status Toggle
            HStack(spacing: 12) {
                Text("Status:")
                    .font(.system(size: 14, weight: .medium))
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(isEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                    
                    Text(isEnabled ? "Active" : "Disabled")
                        .font(.system(size: 14))
                        .foregroundColor(isEnabled ? .green : .gray)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(ModernToggleStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Phrase Input Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Phrase")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    TextField("Say this phrase to trigger the action...", text: $phrase)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            Divider()
            
            // Action Type Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Action Type")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                // Modern segmented control
                HStack(spacing: 8) {
                    ForEach(ActionType.allCases) { type in
                        ActionTypeButton(
                            type: type,
                            isSelected: selectedActionType == type,
                            onSelect: { selectedActionType = type }
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // Action configuration
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedActionType {
                        case .launchApp:
                            AppSelectionView(
                                selectedApp: $selectedApp,
                                availableApps: filteredApps,
                                searchText: $searchText,
                                isLoading: isLoadingApps
                            )
                            
                        case .keyboardShortcut:
                            KeyboardShortcutView(
                                selectedModifiers: $selectedModifiers,
                                selectedKey: $selectedKey
                            )
                            
                        case .customCommand:
                            CustomCommandView(command: $customShellCommand)
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DangerButtonStyle())
                            .alert("Delete Voice Command", isPresented: $showDeleteConfirmation) {
                                Button("Cancel", role: .cancel) { }
                                Button("Delete", role: .destructive) {
                                    onCommandDeleted(command)
                                    dismiss()
                                }
                            } message: {
                                Text("Are you sure you want to delete this voice command? This action cannot be undone.")
                            }
                            
                            Button(action: saveCommand) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                    Text("Save Changes")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!isFormValid)
                        }
                        .padding(.top, 16)
                        
                        if let lastUsed = command.lastUsed {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                
                                Text("Last used: \(formattedDate(lastUsed))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 600)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            loadApps()
        }
    }
    
    private func loadApps() {
        Task {
            let apps = await AppInfoLoader.loadInstalledApps()
            await MainActor.run {
                self.availableApps = apps
                
                // Set selected app if this is an app launch command
                if case .shellCommand(let cmd) = command.action, cmd.hasPrefix("open -a") {
                    let appNamePattern = "open -a '(.+)'"
                    if let regex = try? NSRegularExpression(pattern: appNamePattern),
                       let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
                       let range = Range(match.range(at: 1), in: cmd) {
                        let appName = String(cmd[range])
                        selectedApp = apps.first { $0.name == appName }
                    }
                }
                
                self.isLoadingApps = false
            }
        }
    }
    
    private func saveCommand() {
        let action: VoiceCommandAction
        
        switch selectedActionType {
        case .launchApp:
            if let app = selectedApp {
                action = .shellCommand("open -a '\(app.name)'")
            } else {
                return
            }
        case .keyboardShortcut:
            action = .keyboardShortcut(KeyCombination(
                modifiers: Array(selectedModifiers),
                key: selectedKey
            ))
        case .customCommand:
            action = .shellCommand(customShellCommand)
        }
        
        let updatedCommand = VoiceCommand(
            id: command.id,
            phrase: phrase,
            action: action,
            isEnabled: isEnabled,
            createdAt: command.createdAt,
            lastUsed: command.lastUsed
        )
        
        onCommandUpdated(updatedCommand)
        dismiss()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ActionTypeButton: View {
    let type: EditVoiceCommandView.ActionType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red)
                    .opacity(configuration.isPressed ? 0.9 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    EditVoiceCommandView(command: VoiceCommand(
        id: UUID(),
        phrase: "Open Safari",
        action: .shellCommand("open -a 'Safari'"),
        isEnabled: true,
        createdAt: Date(),
        lastUsed: Date().addingTimeInterval(-3600)
    ))
} 