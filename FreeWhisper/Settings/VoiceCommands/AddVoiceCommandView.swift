import SwiftUI

struct AddVoiceCommandView: View {
    @Environment(\.dismiss) var dismiss
    let onCommandAdded: (VoiceCommand) -> Void
    @StateObject private var voiceCommandStore = VoiceCommandStore.shared
    @State private var phrase = ""
    @State private var selectedActionType: ActionType = .launchApp
    @State private var selectedApp: AppInfo?
    @State private var customShellCommand = ""
    @State private var selectedModifiers: Set<KeyModifier> = []
    @State private var selectedKey = ""
    @State private var availableApps: [AppInfo] = []
    @State private var isLoadingApps = true
    @State private var searchText = ""
    @State private var capturedShortcut = ""
    
    init(onCommandAdded: @escaping (VoiceCommand) -> Void = { _ in }) {
        self.onCommandAdded = onCommandAdded
    }
    
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
        
        var description: String {
            switch self {
            case .launchApp: return "Open applications with voice"
            case .keyboardShortcut: return "Trigger keyboard shortcuts"
            case .customCommand: return "Run shell commands"
            }
        }
    }
    
    var isFormValid: Bool {
        let phraseValid = !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        switch selectedActionType {
        case .launchApp:
            return phraseValid && selectedApp != nil
        case .keyboardShortcut:
            return phraseValid && !selectedKey.isEmpty
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
                    Text("Add Voice Command")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Create a new voice-activated action")
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
                
                Text("Example: \"Open Safari\" or \"Copy that\"")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
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
                        AddCommandActionTypeButton(
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
                                selectedKey: $selectedKey,
                                capturedShortcut: $capturedShortcut
                            )
                            
                        case .customCommand:
                            CustomCommandView(command: $customShellCommand)
                        }
                        
                        // Add some bottom spacing for the fixed button
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(14)
                }
            }
            
            // Fixed bottom button area
            VStack(spacing: 0) {
                Divider()
                
                Button(action: addCommand) {
                    Text("Add Command")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isFormValid)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(.windowBackgroundColor))
            }
        }
        .frame(width: 600, height: 800)
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
                self.isLoadingApps = false
            }
        }
    }
    
    private func addCommand() {
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
        
        let command = VoiceCommand(
            id: UUID(),
            phrase: phrase,
            action: action,
            isEnabled: true,
            createdAt: Date(),
            lastUsed: nil
        )
        
        onCommandAdded(command)
        dismiss()
    }
}

struct AddCommandActionTypeButton: View {
    let type: AddVoiceCommandView.ActionType
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
            .padding(.horizontal, 4)
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

struct AppSelectionView: View {
    @Binding var selectedApp: AppInfo?
    let availableApps: [AppInfo]
    @Binding var searchText: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(availableApps) { app in
                            AppRow(
                                app: app,
                                isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier,
                                onSelect: { selectedApp = app }
                            )
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .frame(height: 320)
            }
            
            if let app = selectedApp {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected: \(app.name)")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(app.bundleIdentifier)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }
}

struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                AppIcon(app: app, size: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct AppIcon: View {
    let app: AppInfo
    let size: CGFloat
    
    var body: some View {
        let nsImage = NSWorkspace.shared.icon(forFile: app.path)
        Image(nsImage: nsImage)
            .resizable()
            .frame(width: size, height: size)
            .cornerRadius(4)
    }
}

struct KeyboardShortcutView: View {
    @Binding var selectedModifiers: Set<KeyModifier>
    @Binding var selectedKey: String
    @Binding var capturedShortcut: String
    @State private var isListening = false
    @State private var showManualBuilder = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Preview of the shortcut - Moved to the top for better visibility
            if !selectedKey.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.accentColor)
                    
                    Text("Shortcut: \(capturedShortcut.isEmpty ? buildShortcutString() : capturedShortcut)")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Press Keyboard Shortcut")
                    .font(.system(size: 14, weight: .medium))
                
                KeyPressListener(
                    selectedKey: $selectedKey,
                    selectedModifiers: $selectedModifiers,
                    isListening: $isListening,
                    capturedShortcut: $capturedShortcut
                )
                
                Text("Click the button above and press any key combination (e.g., ⌘+C, ⌥+→, F1)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Divider with "OR" text
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("OR")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Manual Key Combination Builder
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Build Key Combination Manually")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Button(showManualBuilder ? "Hide Builder" : "Show Builder") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showManualBuilder.toggle()
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                }
                
                Text("Use this when macOS intercepts your key combination")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                if showManualBuilder {
                    ManualKeyBuilderView(
                        selectedModifiers: $selectedModifiers,
                        selectedKey: $selectedKey,
                        capturedShortcut: $capturedShortcut
                    )
                }
            }
        }
    }
    
    private func buildShortcutString() -> String {
        let modifierSymbols = selectedModifiers.sorted { $0.rawValue < $1.rawValue }.map { $0.symbol }
        let modifierString = modifierSymbols.joined()
        
        // Map key names to user-friendly symbols for display
        let displayKey: String
        switch selectedKey.lowercased() {
        case "left": displayKey = "←"
        case "right": displayKey = "→"
        case "up": displayKey = "↑"
        case "down": displayKey = "↓"
        case "space": displayKey = "Space"
        case "return": displayKey = "↩"
        case "tab": displayKey = "⇥"
        case "delete": displayKey = "⌫"
        case "escape": displayKey = "⎋"
        default: displayKey = selectedKey
        }
        
        return modifierString + displayKey
    }
    
    private func updateCapturedShortcut() {
        capturedShortcut = buildShortcutString()
    }
}

struct ManualKeyBuilderView: View {
    @Binding var selectedModifiers: Set<KeyModifier>
    @Binding var selectedKey: String
    @Binding var capturedShortcut: String
    
    let availableKeys = [
        // Function Keys
        "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
        // Letters
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        // Numbers
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        // Arrow Keys (using names that match VoiceCommandExecutor)
        "Left", "Right", "Up", "Down",
        // Special Keys
        "Space", "Return", "Tab", "Delete", "Escape", "Home", "End", "Page Up", "Page Down"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Modifier Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Modifiers")
                    .font(.system(size: 13, weight: .medium))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(KeyModifier.allCases, id: \.self) { modifier in
                        ModifierToggleButton(
                            modifier: modifier,
                            isSelected: selectedModifiers.contains(modifier),
                            onToggle: {
                                if selectedModifiers.contains(modifier) {
                                    selectedModifiers.remove(modifier)
                                } else {
                                    selectedModifiers.insert(modifier)
                                }
                                updateCapturedShortcut()
                            }
                        )
                    }
                }
            }
            
            // Key Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Key")
                    .font(.system(size: 13, weight: .medium))
                
                Menu {
                    ForEach(availableKeys, id: \.self) { key in
                        Button(key) {
                            selectedKey = key.lowercased()
                            updateCapturedShortcut()
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedKey.isEmpty ? "Choose a key..." : (availableKeys.first { $0.lowercased() == selectedKey } ?? selectedKey))
                            .foregroundColor(selectedKey.isEmpty ? .secondary : .primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
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
                .buttonStyle(.plain)
            }
            
            // Preview of manually built shortcut
            if !selectedKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .foregroundColor(.green)
                        
                        Text(buildShortcutString())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            
            // Clear button
            if !selectedKey.isEmpty || !selectedModifiers.isEmpty {
                Button(action: clearSelection) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Clear Selection")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func buildShortcutString() -> String {
        let modifierSymbols = selectedModifiers.sorted { $0.rawValue < $1.rawValue }.map { $0.symbol }
        let modifierString = modifierSymbols.joined()
        
        // Map key names to user-friendly symbols for display
        let displayKey: String
        switch selectedKey.lowercased() {
        case "left": displayKey = "←"
        case "right": displayKey = "→"
        case "up": displayKey = "↑"
        case "down": displayKey = "↓"
        case "space": displayKey = "Space"
        case "return": displayKey = "↩"
        case "tab": displayKey = "⇥"
        case "delete": displayKey = "⌫"
        case "escape": displayKey = "⎋"
        default: displayKey = selectedKey
        }
        
        return modifierString + displayKey
    }
    
    private func updateCapturedShortcut() {
        capturedShortcut = buildShortcutString()
    }
    
    private func clearSelection() {
        selectedModifiers.removeAll()
        selectedKey = ""
        capturedShortcut = ""
    }
}

struct ModifierToggleButton: View {
    let modifier: KeyModifier
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Text(modifier.symbol)
                    .font(.system(size: 12, weight: .bold))
                
                Text(modifier.displayName)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct KeyPressListener: NSViewRepresentable {
    @Binding var selectedKey: String
    @Binding var selectedModifiers: Set<KeyModifier>
    @Binding var isListening: Bool
    @Binding var capturedShortcut: String
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyPressed = { keyName, modifiers, displayString in
            DispatchQueue.main.async {
                self.selectedKey = keyName
                self.selectedModifiers = Set(modifiers)
                self.capturedShortcut = displayString
                self.isListening = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isListening = isListening
    }
}

class KeyCaptureView: NSView {
    var onKeyPressed: ((String, [KeyModifier], String) -> Void)?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    var isListening = false {
        didSet {
            needsDisplay = true
            if isListening {
                // Ensure we can receive key events
                window?.makeFirstResponder(self)
                // Make sure we can accept key events
                window?.makeKeyAndOrderFront(nil)
                
                // Set up both local and global event monitoring for maximum coverage
                setupEventMonitoring()
            } else {
                tearDownEventMonitoring()
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    deinit {
        tearDownEventMonitoring()
    }
    
    private func setupEventMonitoring() {
        tearDownEventMonitoring() // Clean up any existing monitors
        
        // Local monitor - highest priority, catches events before system processing
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isListening else { return event }
            
            // Only handle keyDown events for actual key combinations
            if event.type == .keyDown {
                print("Local monitor - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
                
                // Check if this is a modifier-key combination (not just modifier alone)
                let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift, .function]).isEmpty
                let isArrowKey = [123, 124, 125, 126].contains(event.keyCode)
                let isSpecialKey = self.isSpecialKey(event.keyCode)
                let isRegularKey = event.keyCode >= 18 // Regular letter/number keys
                
                if hasModifiers && (isArrowKey || isSpecialKey || isRegularKey) {
                    let (keyName, modifiers, displayString) = self.parseKeyEvent(event)
                    print("Local captured combination: \(displayString)")
                    
                    DispatchQueue.main.async {
                        self.onKeyPressed?(keyName, modifiers, displayString)
                    }
                    
                    // Consume the event to prevent system handling - this is crucial!
                    return nil
                }
            }
            
            return event
        }
        
        // Global monitor as backup - catches events that might escape local monitoring
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isListening else { return }
            
            print("Global monitor - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
            
            // Check if this is a modifier-key combination
            let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift, .function]).isEmpty
            let isArrowKey = [123, 124, 125, 126].contains(event.keyCode)
            let isSpecialKey = self.isSpecialKey(event.keyCode)
            let isRegularKey = event.keyCode >= 18
            
            if hasModifiers && (isArrowKey || isSpecialKey || isRegularKey) {
                let (keyName, modifiers, displayString) = self.parseKeyEvent(event)
                print("Global captured combination: \(displayString)")
                
                DispatchQueue.main.async {
                    self.onKeyPressed?(keyName, modifiers, displayString)
                }
            }
        }
    }
    
    private func tearDownEventMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    private func isSpecialKey(_ keyCode: UInt16) -> Bool {
        let specialKeyCodes: Set<UInt16> = [
            // Function keys
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
            // Arrow keys
            123, 124, 125, 126,
            // Navigation keys
            115, 119, 116, 121,
            // Special keys
            36, 53, 48, 49, 51, 117
        ]
        return specialKeyCodes.contains(keyCode)
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Add a tracking area to handle mouse events
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        let backgroundColor = isListening ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor
        backgroundColor.setFill()
        dirtyRect.fill()
        
        // Border
        let borderColor = isListening ? NSColor.controlAccentColor : NSColor.separatorColor
        layer?.borderColor = borderColor.cgColor
        
        // Text
        let text = isListening ? "🎧 Press any key combination..." : "Click to capture keyboard shortcut"
        let textColor = isListening ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
    
    override func mouseDown(with event: NSEvent) {
        if !isListening {
            isListening = true
            window?.makeFirstResponder(self)
        }
    }
    
    // Enhanced event handlers with priority handling
    override func keyDown(with event: NSEvent) {
        guard isListening else { 
            super.keyDown(with: event)
            return 
        }
        
        print("Direct keyDown - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
        
        // Handle the event directly if it has modifiers
        let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift, .function]).isEmpty
        if hasModifiers {
            let (keyName, modifiers, displayString) = parseKeyEvent(event)
            print("Direct captured: \(displayString)")
            onKeyPressed?(keyName, modifiers, displayString)
            return // Don't call super to prevent further processing
        }
        
        // For single keys without modifiers, still capture them
        let (keyName, modifiers, displayString) = parseKeyEvent(event)
        onKeyPressed?(keyName, modifiers, displayString)
    }
    
    override func keyUp(with event: NSEvent) {
        if isListening {
            return // Consume keyUp events when listening
        }
        super.keyUp(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard isListening else {
            super.flagsChanged(with: event)
            return
        }
        // Don't capture modifier-only presses
    }
    
    // This method has the highest priority for key equivalents
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isListening {
            print("performKeyEquivalent - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
            
            let (keyName, modifiers, displayString) = parseKeyEvent(event)
            print("performKeyEquivalent captured: \(displayString)")
            onKeyPressed?(keyName, modifiers, displayString)
            return true // Consume the event - this prevents system shortcuts!
        }
        return super.performKeyEquivalent(with: event)
    }
    
    // Override interpretKeyEvents to catch more key combinations
    override func interpretKeyEvents(_ eventArray: [NSEvent]) {
        if isListening {
            // Don't interpret key events when listening - we handle them directly
            for event in eventArray {
                if event.type == .keyDown {
                    let (keyName, modifiers, displayString) = parseKeyEvent(event)
                    print("interpretKeyEvents captured: \(displayString)")
                    onKeyPressed?(keyName, modifiers, displayString)
                }
            }
            return
        }
        super.interpretKeyEvents(eventArray)
    }
    
    // Enhanced modifier parsing for complex combinations
    private func parseModifierFlags(_ modifierFlags: NSEvent.ModifierFlags) -> (String, [KeyModifier], String) {
        var modifiers: [KeyModifier] = []
        var modifierSymbols: [String] = []
        
        // Use more specific flag checking to avoid conflicts
        if modifierFlags.contains(.command) {
            modifiers.append(.command)
            modifierSymbols.append("⌘")
        }
        if modifierFlags.contains(.option) {
            modifiers.append(.option)
            modifierSymbols.append("⌥")
        }
        if modifierFlags.contains(.control) {
            modifiers.append(.control)
            modifierSymbols.append("⌃")
        }
        if modifierFlags.contains(.shift) {
            modifiers.append(.shift)
            modifierSymbols.append("⇧")
        }
        if modifierFlags.contains(.function) {
            modifiers.append(.function)
            modifierSymbols.append("fn")
        }
        
        let displayString = modifierSymbols.joined()
        return (displayString, modifiers, displayString)
    }
    
    private func parseKeyEvent(_ event: NSEvent) -> (String, [KeyModifier], String) {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        
        print("Parsing event - keyCode: \(keyCode), raw modifiers: \(modifierFlags.rawValue)")
        
        // Enhanced modifier detection with cleaner logic
        var modifiers: [KeyModifier] = []
        var modifierSymbols: [String] = []
        
        // Check modifiers in a specific order for consistent display
        if modifierFlags.contains(.control) {
            modifiers.append(.control)
            modifierSymbols.append("⌃")
        }
        if modifierFlags.contains(.option) {
            modifiers.append(.option)
            modifierSymbols.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            modifiers.append(.shift)
            modifierSymbols.append("⇧")
        }
        if modifierFlags.contains(.command) {
            modifiers.append(.command)
            modifierSymbols.append("⌘")
        }
        if modifierFlags.contains(.function) {
            modifiers.append(.function)
            modifierSymbols.append("fn")
        }
        
        // Parse key name
        let keyName = keyNameFromKeyCode(keyCode, event: event)
        
        // Create display string
        let displayString = modifierSymbols.joined() + keyName
        
        print("Parsed result - key: \(keyName), modifiers: \(modifiers.map(\.rawValue)), display: \(displayString)")
        
        return (keyName, modifiers, displayString)
    }
    
    private func keyNameFromKeyCode(_ keyCode: UInt16, event: NSEvent) -> String {
        // Special keys mapping - these should be checked first
        let specialKeys: [UInt16: String] = [
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            
            // Arrow keys - these are the most important for your use case
            123: "Left", 124: "Right", 125: "Down", 126: "Up",
            
            // Navigation keys
            115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
            
            // Special keys
            36: "Return", 53: "Escape", 48: "Tab", 49: "Space",
            51: "Delete", 117: "⌦", // Forward Delete
            
            // Number row
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9",
            
            // Letters (QWERTY layout)
            12: "Q", 13: "W", 14: "E", 15: "R", 17: "T", 16: "Y",
            32: "U", 34: "I", 31: "O", 35: "P",
            0: "A", 1: "S", 2: "D", 3: "F", 5: "G", 4: "H",
            38: "J", 40: "K", 37: "L",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 45: "N",
            46: "M",
            
            // Punctuation and symbols
            27: "-", 24: "=", 33: "[", 30: "]", 42: "\\",
            39: ";", 41: "'", 43: ",", 47: ".", 44: "/", 50: "`"
        ]
        
        // Check special keys first
        if let specialKey = specialKeys[keyCode] {
            return specialKey
        }
        
        // Fallback to character-based detection for any missed keys
        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            let char = characters.first!
            
            // Handle printable characters
            if char.isPunctuation || char.isSymbol {
                return String(char)
            } else if char.isLetter {
                return String(char).uppercased()
            } else if char.isNumber {
                return String(char)
            } else if char.isWhitespace && char == " " {
                return "Space"
            }
        }
        
        // Last resort: return the key code for debugging
        return "Key\(keyCode)"
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 300, height: 44)
    }
    
    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        isListening = false
        needsDisplay = true
        return super.resignFirstResponder()
    }
}

struct ModifierButton: View {
    let modifier: KeyModifier
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Text(modifier.symbol)
                    .font(.system(size: 14, weight: .bold))
                
                Text(modifier.displayName)
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomCommandView: View {
    @Binding var command: String
    @State private var selectedExample: String = ""
    
    let examples = [
        "say 'Hello World'": "Text to speech",
        "open ~/Documents": "Open Documents folder",
        "pmset sleepnow": "Put Mac to sleep",
        "open -a 'Safari'": "Open Safari browser",
        "osascript -e 'tell application \"System Events\" to keystroke \"v\" using {command down}'": "Paste from clipboard"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter Shell Command")
                .font(.system(size: 14, weight: .medium))
            
            TextEditor(text: $command)
                .font(.system(size: 14, design: .monospaced))
                .padding(8)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Example Commands")
                    .font(.system(size: 14, weight: .medium))
                
                VStack(spacing: 8) {
                    ForEach(examples.sorted(by: { $0.key < $1.key }), id: \.key) { cmd, description in
                        ExampleCommandButton(
                            command: cmd,
                            description: description,
                            isSelected: selectedExample == cmd,
                            onSelect: {
                                selectedExample = cmd
                                command = cmd
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ExampleCommandButton: View {
    let command: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "terminal")
                    .foregroundColor(isSelected ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(command)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(isSelected ? .primary : .blue)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.green.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    // Completely standalone preview without any custom components
    VStack(spacing: 0) {
        // Header
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Voice Command")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Create a new voice-activated action")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") { }
                .buttonStyle(.bordered)
        }
        .padding()
        
        ScrollView {
            VStack(spacing: 24) {
                // Phrase input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Phrase")
                        .font(.headline)
                    
                    TextField("Say something like 'open spotify'", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    
                    Text("This is what you'll say to trigger the command")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Action Type")
                        .font(.headline)
                    
                    Picker("Action Type", selection: .constant(0)) {
                        Text("Shell Command").tag(0)
                        Text("Keyboard Shortcut").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Shell command input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shell Command")
                        .font(.headline)
                    
                    TextField("open -a 'Spotify'", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Command to execute in Terminal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Key capture section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                    
                    HStack {
                        Text("Click here and press your key combination")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear") { }
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
                
                Spacer(minLength: 40)
                
                // Save button
                Button("Save Command") { }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding()
        }
    }
    .frame(width: 500, height: 700)
} 
