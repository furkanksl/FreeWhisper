import Foundation
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()
    
    private init() {}
    
    func setStartAtLogin(_ enable: Bool) {
        let appPreferences = AppPreferences.shared
        
        if #available(macOS 13.0, *) {
            // Use the new SMAppService API for macOS 13+
            do {
                let service = SMAppService.mainApp
                if enable {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
                appPreferences.startAtLogin = enable
                print("Login item set to \(enable)")
            } catch {
                print("Failed to \(enable ? "register" : "unregister") login item: \(error)")
            }
        } else {
            // Use the older SMLoginItemSetEnabled API for macOS 12 and earlier
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.furkanksl.FreeWhisper"
            SMLoginItemSetEnabled(bundleIdentifier as CFString, enable)
            appPreferences.startAtLogin = enable
            print("Login item set to \(enable) using legacy API")
        }
    }
    
    func syncLoginItemWithPreference() {
        let shouldStartAtLogin = AppPreferences.shared.startAtLogin
        setStartAtLogin(shouldStartAtLogin)
    }
} 