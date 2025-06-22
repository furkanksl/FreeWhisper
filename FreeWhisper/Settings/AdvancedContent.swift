import SwiftUI

struct AdvancedContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // New App Behavior Card
            GlassCard(
                title: "App Behavior",
                subtitle: "Customize startup and window behavior",
                icon: "gearshape.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Start at Login",
                        subtitle: "Launch automatically when you log in",
                        icon: "arrow.right.circle"
                    ) {
                        Toggle("", isOn: $viewModel.startAtLogin)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    SettingRow(
                        title: "Hide Window on Reopen",
                        subtitle: "After setup, keep app in menu bar only",
                        icon: "eye.slash"
                    ) {
                        Toggle("", isOn: $viewModel.hideMainWindowOnReopen)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }
            }
            
            GlassCard(
                title: "Processing Strategy",
                subtitle: "Control transcription behavior",
                icon: "gearshape.2.fill"
            ) {
                VStack(spacing: 16) {
                    SettingRow(
                        title: "Beam Search",
                        subtitle: "More accurate, slower processing",
                        icon: "arrow.triangle.branch"
                    ) {
                        Toggle("", isOn: $viewModel.useBeamSearch)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    if viewModel.useBeamSearch {
                        SettingRow(
                            title: "Beam Size",
                            subtitle: "Number of search paths",
                            icon: "number.square"
                        ) {
                            HStack {
                                Stepper("", value: $viewModel.beamSize, in: 1...10)
                                    .frame(width: 60)
                                Text("\(viewModel.beamSize)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(width: 30)
                            }
                        }
                    }
                }
            }
            
            GlassCard(
                title: "Model Parameters",
                subtitle: "Fine-tune AI behavior",
                icon: "slider.horizontal.3"
            ) {
                VStack(spacing: 20) {
                    SliderSetting(
                        title: "Temperature",
                        subtitle: "Randomness in output",
                        icon: "thermometer",
                        value: $viewModel.temperature,
                        range: 0.0...1.0
                    )
                    
                    SliderSetting(
                        title: "Silence Threshold",
                        subtitle: "Sensitivity for detecting speech",
                        icon: "waveform.path",
                        value: $viewModel.noSpeechThreshold,
                        range: 0.0...1.0
                    )
                }
            }
            
            GlassCard(
                title: "Development",
                subtitle: "Debug and troubleshooting",
                icon: "ladybug.fill"
            ) {
                SettingRow(
                    title: "Debug Mode",
                    subtitle: "Enable detailed logging",
                    icon: "terminal"
                ) {
                    Toggle("", isOn: $viewModel.debugMode)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }
            }
        }
    }
}