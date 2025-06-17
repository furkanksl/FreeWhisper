import Foundation
import CoreAudio
import SwiftUI

class SystemAudioController: ObservableObject {
    static let shared = SystemAudioController()
    
    @Published var isSystemMuted = false
    private var originalVolume: Float = 0.0
    private var wasAlreadyMuted = false
    private let queue = DispatchQueue(label: "com.freewhisper.SystemAudioController", qos: .userInitiated)
    
    private init() {}
    
    /// Mutes system audio output and stores the original volume
    func muteSystemAudio() {
        queue.sync {
            guard !self.isSystemMuted else { return }
            
            // Get the default output device
            guard let deviceID = self.getDefaultOutputDevice() else {
                print("SystemAudioController: Failed to get default output device")
                return
            }
            
            // Get current volume
            if let currentVolume = self.getSystemVolume(for: deviceID) {
                self.originalVolume = currentVolume
                self.wasAlreadyMuted = (currentVolume == 0.0)
                
                // Only mute if not already muted
                if !self.wasAlreadyMuted {
                    self.setSystemVolume(0.0, for: deviceID)
                    DispatchQueue.main.async {
                        self.isSystemMuted = true
                    }
                    print("SystemAudioController: System audio muted (original volume: \(self.originalVolume))")
                }
            } else {
                print("SystemAudioController: Failed to get current system volume")
            }
        }
    }
    
    /// Restores the original system audio volume
    func unmuteSystemAudio() {
        queue.sync {
            guard self.isSystemMuted else { return }
            
            // Get the default output device
            guard let deviceID = self.getDefaultOutputDevice() else {
                print("SystemAudioController: Failed to get default output device")
                return
            }
            
            // Restore original volume only if we muted it
            if !self.wasAlreadyMuted {
                self.setSystemVolume(self.originalVolume, for: deviceID)
                print("SystemAudioController: System audio restored to volume: \(self.originalVolume)")
            }
            
            DispatchQueue.main.async {
                self.isSystemMuted = false
            }
            self.originalVolume = 0.0
            self.wasAlreadyMuted = false
        }
    }
    
    // MARK: - Private Methods
    
    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        return status == noErr ? deviceID : nil
    }
    
    private func getSystemVolume(for deviceID: AudioDeviceID) -> Float? {
        var volume: Float = 0.0
        var size = UInt32(MemoryLayout<Float>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )
        
        return status == noErr ? volume : nil
    }
    
    private func setSystemVolume(_ volume: Float, for deviceID: AudioDeviceID) {
        var newVolume = volume
        let size = UInt32(MemoryLayout<Float>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )
        
        if status != noErr {
            print("SystemAudioController: Failed to set system volume (error: \(status))")
        }
    }
} 