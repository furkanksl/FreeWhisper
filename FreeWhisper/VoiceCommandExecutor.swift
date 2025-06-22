import Foundation
import AppKit
import Carbon

// MARK: - Voice Command Executor

@MainActor
class VoiceCommandExecutor: ObservableObject {
    static let shared = VoiceCommandExecutor()
    
    @Published var lastExecutedCommand: VoiceCommand?
    @Published var executionHistory: [VoiceCommandExecution] = []
    
    private init() {}
    
    // MARK: - Command Execution
    
    func executeCommand(_ command: VoiceCommand) async {
        print("Executing voice command: \(command.phrase) -> \(command.action.description)")
        
        let execution = VoiceCommandExecution(
            command: command,
            timestamp: Date(),
            success: false
        )
        
        do {
            switch command.action {
            case .shellCommand(let shellCommand):
                try await executeShellCommand(shellCommand)
                
            case .keyboardShortcut(let keyCombo):
                try executeKeyboardShortcut(keyCombo)
            }
            
            // Mark as successful
            let successfulExecution = VoiceCommandExecution(
                command: command,
                timestamp: execution.timestamp,
                success: true
            )
            
            await MainActor.run {
                self.lastExecutedCommand = command
                self.executionHistory.insert(successfulExecution, at: 0)
                
                // Keep only last 50 executions
                if self.executionHistory.count > 50 {
                    self.executionHistory = Array(self.executionHistory.prefix(50))
                }
            }
            
            // Mark command as used in the store
            await VoiceCommandStore.shared.markCommandAsUsed(command)
            
            print("✅ Successfully executed: \(command.phrase)")
            
        } catch {
            print("❌ Failed to execute command '\(command.phrase)': \(error)")
            
            // Add failed execution to history
            await MainActor.run {
                self.executionHistory.insert(execution, at: 0)
            }
        }
    }
    
    // MARK: - Shell Command Execution
    
    private func executeShellCommand(_ command: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", command]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            task.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: VoiceCommandError.shellExecutionFailed(errorString))
                }
            }
            
            do {
                task.launch()
            } catch {
                continuation.resume(throwing: VoiceCommandError.shellExecutionFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Keyboard Shortcut Execution
    
    private func executeKeyboardShortcut(_ keyCombo: KeyCombination) throws {
        // Check if this is a system shortcut that might be intercepted
        if isLikelySystemShortcut(keyCombo) {
            // Use AppleScript for system shortcuts to bypass interception
            try executeViaAppleScript(keyCombo)
        } else {
            // Use the standard CGEvent approach for other shortcuts
            try executeViaCGEvent(keyCombo)
        }
    }
    
    private func isLikelySystemShortcut(_ keyCombo: KeyCombination) -> Bool {
        // Special case for Control+Arrow keys which are commonly used for switching desktops
        let isControlArrow = keyCombo.modifiers.count == 1 && 
                            keyCombo.modifiers.contains(.control) && 
                            ["left", "right"].contains(keyCombo.key.lowercased())
        
        if isControlArrow {
            return true
        }
        
        // Check for common system shortcuts that get intercepted
        let systemModifierCombos: [[KeyModifier]] = [
            [.command, .shift], // Command + Shift combinations
            [.command, .option], // Command + Option combinations
            [.control, .option], // Control + Option combinations
            [.function] // Function key combinations
        ]
        
        // Check for navigation keys that are often intercepted
        let navigationKeys = ["left", "right", "up", "down", "home", "end", "pageup", "pagedown"]
        
        // Check if this is a likely system shortcut
        let hasSystemModifiers = systemModifierCombos.contains { combo in
            Set(combo).isSubset(of: Set(keyCombo.modifiers))
        }
        
        let isNavigationKey = navigationKeys.contains(keyCombo.key.lowercased())
        
        return hasSystemModifiers || isNavigationKey
    }
    
    private func executeViaAppleScript(_ keyCombo: KeyCombination) throws {
        // Special case for Control+Arrow keys (desktop switching)
        let isControlArrow = keyCombo.modifiers.count == 1 && 
                            keyCombo.modifiers.contains(.control) && 
                            ["left", "right"].contains(keyCombo.key.lowercased())
        
        if isControlArrow {
            let direction = keyCombo.key.lowercased()
            let scriptCommand = """
            tell application "System Events"
                key down control
                key code \(direction == "left" ? "123" : "124")
                delay 0.1
                key up control
            end tell
            """
            
            print("Executing desktop switch via AppleScript: \(scriptCommand)")
            
            let script = NSAppleScript(source: scriptCommand)
            var errorInfo: NSDictionary?
            script?.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                throw VoiceCommandError.shellExecutionFailed("AppleScript error: \(error)")
            }
            
            return
        }
        
        // Special case for fullscreen command (Control+Option+Return)
        let isFullscreenCommand = keyCombo.modifiers.contains(.control) && 
                                 keyCombo.modifiers.contains(.option) && 
                                 keyCombo.key.lowercased() == "return"
        
        if isFullscreenCommand {
            let scriptCommand = """
            tell application "System Events"
                key down control
                key down option
                keystroke return
                delay 0.5
                key up option
                key up control
            end tell
            """
            
            print("Executing fullscreen command via AppleScript: \(scriptCommand)")
            
            let script = NSAppleScript(source: scriptCommand)
            var errorInfo: NSDictionary?
            script?.executeAndReturnError(&errorInfo)
            
            if let error = errorInfo {
                throw VoiceCommandError.shellExecutionFailed("AppleScript error: \(error)")
            }
            
            // Add a delay to prevent conflicts with other commands
            Thread.sleep(forTimeInterval: 0.5)
            
            return
        }
        
        // Convert modifiers to AppleScript format
        var modifierStrings: [String] = []
        
        for modifier in keyCombo.modifiers {
            switch modifier {
            case .command:
                modifierStrings.append("command down")
            case .option:
                modifierStrings.append("option down")
            case .control:
                modifierStrings.append("control down")
            case .shift:
                modifierStrings.append("shift down")
            case .function:
                // Function key is handled differently
                continue
            }
        }
        
        // Convert key to AppleScript format
        let keyString: String
        switch keyCombo.key.lowercased() {
        case "left":
            keyString = "left arrow"
        case "right":
            keyString = "right arrow"
        case "up":
            keyString = "up arrow"
        case "down":
            keyString = "down arrow"
        case "return":
            keyString = "return"
        case "space":
            keyString = "space"
        case "tab":
            keyString = "tab"
        case "delete", "backspace":
            keyString = "delete"
        case "escape", "esc":
            keyString = "escape"
        case "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12":
            keyString = keyCombo.key.lowercased()
        default:
            keyString = keyCombo.key.lowercased()
        }
        
        // Build the AppleScript command
        let modifiersString = modifierStrings.isEmpty ? "" : "using {" + modifierStrings.joined(separator: ", ") + "} "
        
        // Use key stroke for regular keys and key code for special keys
        let scriptCommand: String
        if ["left arrow", "right arrow", "up arrow", "down arrow"].contains(keyString) {
            // For arrow keys, use key code
            let arrowKeyCode: String
            switch keyString {
            case "left arrow": arrowKeyCode = "123"
            case "right arrow": arrowKeyCode = "124"
            case "up arrow": arrowKeyCode = "126"
            case "down arrow": arrowKeyCode = "125"
            default: arrowKeyCode = "0"
            }
            
            scriptCommand = """
            tell application "System Events"
                key code \(arrowKeyCode) \(modifiersString)
            end tell
            """
        } else if keyString.hasPrefix("f") && Int(keyString.dropFirst()) != nil {
            // For function keys, use key code
            let functionKeyCode: String
            switch keyString {
            case "f1": functionKeyCode = "122"
            case "f2": functionKeyCode = "120"
            case "f3": functionKeyCode = "99"
            case "f4": functionKeyCode = "118"
            case "f5": functionKeyCode = "96"
            case "f6": functionKeyCode = "97"
            case "f7": functionKeyCode = "98"
            case "f8": functionKeyCode = "100"
            case "f9": functionKeyCode = "101"
            case "f10": functionKeyCode = "109"
            case "f11": functionKeyCode = "103"
            case "f12": functionKeyCode = "111"
            default: functionKeyCode = "0"
            }
            
            scriptCommand = """
            tell application "System Events"
                key code \(functionKeyCode) \(modifiersString)
            end tell
            """
        } else {
            // For regular keys, use keystroke
            scriptCommand = """
            tell application "System Events"
                keystroke "\(keyString)" \(modifiersString)
            end tell
            """
        }
        
        print("Executing via AppleScript: \(scriptCommand)")
        
        // Execute the AppleScript
        let script = NSAppleScript(source: scriptCommand)
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)
        
        if let error = errorInfo {
            throw VoiceCommandError.shellExecutionFailed("AppleScript error: \(error)")
        }
    }
    
    private func executeViaCGEvent(_ keyCombo: KeyCombination) throws {
        guard let keyCode = keyCodeForString(keyCombo.key) else {
            throw VoiceCommandError.invalidKeyCode(keyCombo.key)
        }
        
        let modifierFlags = carbonModifierFlags(for: keyCombo.modifiers)
        
        // Create and post the key down event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            throw VoiceCommandError.keyEventCreationFailed
        }
        
        keyDownEvent.flags = modifierFlags
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay to ensure the key down is registered
        usleep(10000) // 10ms
        
        // Create and post the key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw VoiceCommandError.keyEventCreationFailed
        }
        
        keyUpEvent.flags = modifierFlags
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    // MARK: - Helper Methods
    
    private func carbonModifierFlags(for modifiers: [KeyModifier]) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        for modifier in modifiers {
            switch modifier {
            case .command:
                flags.insert(.maskCommand)
            case .option:
                flags.insert(.maskAlternate)
            case .control:
                flags.insert(.maskControl)
            case .shift:
                flags.insert(.maskShift)
            case .function:
                flags.insert(.maskSecondaryFn)
            }
        }
        
        return flags
    }
    
    private func keyCodeForString(_ key: String) -> CGKeyCode? {
        let lowercaseKey = key.lowercased()
        
        // Map common keys to their virtual key codes
        let keyCodeMap: [String: CGKeyCode] = [
            // Letters
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06,
            
            // Numbers
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
            
            // Function keys
            "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60,
            "f6": 0x61, "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D,
            "f11": 0x67, "f12": 0x6F,
            
            // Arrow keys
            "up": 0x7E, "down": 0x7D, "left": 0x7B, "right": 0x7C,
            
            // Special keys
            "space": 0x31, "return": 0x24, "enter": 0x24, "tab": 0x30,
            "delete": 0x33, "backspace": 0x33, "escape": 0x35, "esc": 0x35,
            
            // Punctuation
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C,
            "`": 0x32
        ]
        
        return keyCodeMap[lowercaseKey]
    }
}

// MARK: - Voice Command Execution History

struct VoiceCommandExecution: Identifiable {
    let id = UUID()
    let command: VoiceCommand
    let timestamp: Date
    let success: Bool
}

// MARK: - Voice Command Errors

enum VoiceCommandError: Error, LocalizedError {
    case shellExecutionFailed(String)
    case invalidKeyCode(String)
    case keyEventCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .shellExecutionFailed(let message):
            return "Shell command failed: \(message)"
        case .invalidKeyCode(let key):
            return "Invalid key code: \(key)"
        case .keyEventCreationFailed:
            return "Failed to create keyboard event"
        }
    }
}

// MARK: - Voice Command Processing Service

@MainActor
class VoiceCommandProcessor: ObservableObject {
    static let shared = VoiceCommandProcessor()
    
    @Published var isVoiceCommandsEnabled: Bool {
        didSet {
            AppPreferences.shared.voiceCommandsEnabled = isVoiceCommandsEnabled
        }
    }
    
    @Published var showVoiceCommandFeedback: Bool {
        didSet {
            AppPreferences.shared.showVoiceCommandFeedback = showVoiceCommandFeedback
        }
    }
    
    private let commandStore = VoiceCommandStore.shared
    private let executor = VoiceCommandExecutor.shared
    
    private init() {
        self.isVoiceCommandsEnabled = AppPreferences.shared.voiceCommandsEnabled
        self.showVoiceCommandFeedback = AppPreferences.shared.showVoiceCommandFeedback
    }
    
    // MARK: - Main Processing Method
    
    func processTranscription(_ transcription: String) async -> Bool {
        guard isVoiceCommandsEnabled else { return false }
        
        // Check if the transcription matches any voice command
        if let matchingCommand = commandStore.findMatchingCommand(for: transcription) {
            print("🎤 Voice command detected: '\(transcription)' -> '\(matchingCommand.phrase)'")
            
            // Execute the command
            await executor.executeCommand(matchingCommand)
            
            if showVoiceCommandFeedback {
                await showCommandExecutedFeedback(matchingCommand)
            }
            
            return true // Indicates this was a voice command, not regular transcription
        }
        
        return false // Not a voice command, proceed with regular transcription
    }
    
    // MARK: - User Feedback
    
    private func showCommandExecutedFeedback(_ command: VoiceCommand) async {
        // Show a brief notification that the command was executed
        let notification = NSUserNotification()
        notification.title = "Voice Command Executed"
        notification.informativeText = "'\(command.phrase)' -> \(command.action.description)"
        notification.soundName = nil // Silent notification
        
        NSUserNotificationCenter.default.deliver(notification)
        
        // Auto-remove after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NSUserNotificationCenter.default.removeDeliveredNotification(notification)
        }
    }
} 