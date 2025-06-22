import SwiftUI

enum SettingsCategory: String, CaseIterable {
    case shortcuts = "Shortcuts"
    case voiceCommands = "Voice Cmds"
    case model = "Model"
    case transcription = "Transcription"
    case advanced = "Advanced"
    
    var icon: String {
        switch self {
        case .shortcuts: return "command.circle.fill"
        case .voiceCommands: return "mic.badge.plus"
        case .model: return "cpu.fill"
        case .transcription: return "text.bubble.fill"
        case .advanced: return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .shortcuts: return .purple
        case .voiceCommands: return .green
        case .model: return .blue
        case .transcription: return .orange
        case .advanced: return .red
        }
    }
    
    var fullName: String {
        switch self {
        case .shortcuts: return "Shortcuts"
        case .voiceCommands: return "Voice Commands"
        case .model: return "Model"
        case .transcription: return "Transcription"
        case .advanced: return "Advanced"
        }
    }
} 