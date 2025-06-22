import SwiftUI
import KeyboardShortcuts

struct ShortcutsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Recording Controls",
                subtitle: "Global shortcuts for voice recording",
                icon: "command.square.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Toggle Recording",
                        subtitle: "Start or stop recording from anywhere",
                        icon: "record.circle"
                    ) {
                        KeyboardShortcuts.Recorder("", name: .toggleRecord)
                            .frame(width: 120)
                    }
                    
                    SettingRow(
                        title: "Sound Feedback",
                        subtitle: "Play sound when recording starts",
                        icon: "speaker.wave.2"
                    ) {
                        Toggle("", isOn: $viewModel.playSoundOnRecordStart)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    SettingRow(
                        title: "Mute System Audio",
                        subtitle: "Silence computer audio during recording",
                        icon: "speaker.slash.fill"
                    ) {
                        Toggle("", isOn: $viewModel.muteSystemAudioDuringRecording)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Quick Guide",
                subtitle: "How to use keyboard shortcuts",
                icon: "lightbulb.fill"
            ) {
                VStack(spacing: 12) {
                    GuideStep(number: 1, text: "Click the shortcut field above")
                    GuideStep(number: 2, text: "Press your desired key combination")
                    GuideStep(number: 3, text: "Use it globally across all apps")
                }
            }
        }
    }
} 