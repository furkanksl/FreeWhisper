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