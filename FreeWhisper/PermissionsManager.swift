import AVFoundation
import AppKit
import Foundation

enum Permission {
    case microphone
    case accessibility
}

class PermissionsManager: ObservableObject {
    @Published var isMicrophonePermissionGranted = false
    @Published var isAccessibilityPermissionGranted = false

    private var permissionCheckTimer: Timer?
    private var lastAccessibilityStatus = false

    init() {
        checkMicrophonePermission()
        checkAccessibilityPermission()

        // Monitor accessibility permission changes using NSWorkspace's notification center
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityPermissionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        
        // Also observe when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Start continuous permission checking
        startPermissionChecking()
    }

    deinit {
        stopPermissionChecking()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func startPermissionChecking() {
        // Timer is scheduled on the main run loop
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkMicrophonePermission()
            self?.checkAccessibilityPermission()
        }
    }

    private func stopPermissionChecking() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        DispatchQueue.main.async { [weak self] in
            switch status {
            case .authorized:
                self?.isMicrophonePermissionGranted = true
            default:
                self?.isMicrophonePermissionGranted = false
            }
        }
    }

    func checkAccessibilityPermission() {
        // First check with standard API
        let granted = AXIsProcessTrusted()
        
        // Try to perform a simple accessibility operation as a secondary check
        var canPerformAccessibilityOperations = false
        if granted {
            // Try to get the focused element as a test
            if let systemWideElement = AXUIElementCreateSystemWide() as AXUIElement? {
                var focusedElement: AnyObject?
                let result = AXUIElementCopyAttributeValue(
                    systemWideElement,
                    kAXFocusedUIElementAttribute as CFString,
                    &focusedElement
                )
                
                // If we can get the focused element, we have proper accessibility permissions
                canPerformAccessibilityOperations = (result == .success)
            }
        }
        
        // Only update if there's a change to avoid unnecessary UI updates
        let newStatus = granted && canPerformAccessibilityOperations
        if newStatus != lastAccessibilityStatus {
            lastAccessibilityStatus = newStatus
            DispatchQueue.main.async { [weak self] in
                self?.isAccessibilityPermissionGranted = newStatus
            }
        }
    }

    func requestMicrophonePermissionOrOpenSystemPreferences() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isMicrophonePermissionGranted = granted
                }
            }
        case .authorized:
            self.isMicrophonePermissionGranted = true
        default:
            openSystemPreferences(for: .microphone)
        }
    }

    @objc private func accessibilityPermissionChanged() {
        checkAccessibilityPermission()
    }
    
    @objc private func applicationDidBecomeActive() {
        // Force a fresh check of permissions when app becomes active
        checkMicrophonePermission()
        
        // Reset last status to force update
        lastAccessibilityStatus = false
        checkAccessibilityPermission()
    }

    func openSystemPreferences(for permission: Permission) {
        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString =
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // Call this to force the app to restart and refresh permissions
    func restartAppToRefreshPermissions() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        
        // Give the new instance time to start before quitting this one
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    }
}
