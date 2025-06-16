//
//  FreeWhisperApp.swift
//  FreeWhisper
//
//  Created by user on 05.02.2025.
//

import AVFoundation
import SwiftUI
import AppKit

@main
struct FreeWhisperApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Group {
                if !appState.hasCompletedOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                }
            }
            .frame(width: 800, height: 700)
            .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 450, height: 650)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "openMainWindow"))
    }

    init() {
        _ = ShortcutManager.shared
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            AppPreferences.shared.hasCompletedOnboarding = hasCompletedOnboarding
        }
    }

    init() {
        self.hasCompletedOnboarding = AppPreferences.shared.hasCompletedOnboarding
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var isExplicitlyOpened = false // Track if window was explicitly opened by user
    private var muteSystemAudioMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize IndicatorWindowManager to ensure proper positioning
        IndicatorWindowManager.shared.initialize()
        
        // Sync login item status with preferences
        LoginItemManager.shared.syncLoginItemWithPreference()
        
        setupStatusBarItem()
        
        // Check if we should hide the window on startup
        let prefs = AppPreferences.shared
        let shouldHideWindow = prefs.hasCompletedOnboarding && 
                              prefs.selectedModelPath != nil && 
                              prefs.hideMainWindowOnReopen
        
        // Set app to accessory mode immediately if needed
        if shouldHideWindow {
            NSApplication.shared.setActivationPolicy(.accessory)
            print("Window hidden on launch based on user preference")
        }
        
        // Store window reference after setting activation policy
        if let window = NSApplication.shared.windows.first {
            self.mainWindow = window
            window.delegate = self
            
            // If we need to hide the window, make sure it's not visible
            if shouldHideWindow {
                window.orderOut(nil)
            }
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Only check window visibility if it wasn't explicitly opened by the user
        if !isExplicitlyOpened {
            let prefs = AppPreferences.shared
            let shouldHideWindow = prefs.hasCompletedOnboarding && 
                                  prefs.selectedModelPath != nil && 
                                  prefs.hideMainWindowOnReopen
            
            if shouldHideWindow {
                // Make sure we're in accessory mode and window is hidden
                NSApplication.shared.setActivationPolicy(.accessory)
                mainWindow?.orderOut(nil)
            }
        }
        
        // Reset the flag after handling the activation
        isExplicitlyOpened = false
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if let iconImage = NSImage(named: "tray_icon") {
                iconImage.size = NSSize(width: 22, height: 22)
                iconImage.isTemplate = false
                button.image = iconImage
            } else {
                button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "FreeWhisper")
            }
            
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "FreeWhisper", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        
        // Add mute system audio toggle
        muteSystemAudioMenuItem = NSMenuItem(
            title: "Mute System Audio During Recording",
            action: #selector(toggleMuteSystemAudio),
            keyEquivalent: ""
        )
        updateMuteSystemAudioMenuItemState()
        menu.addItem(muteSystemAudioMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func updateMuteSystemAudioMenuItemState() {
        muteSystemAudioMenuItem?.state = AppPreferences.shared.muteSystemAudioDuringRecording ? .on : .off
    }
    
    @objc private func toggleMuteSystemAudio() {
        let prefs = AppPreferences.shared
        prefs.muteSystemAudioDuringRecording.toggle()
        updateMuteSystemAudioMenuItemState()
    }
    
    @objc private func statusBarButtonClicked(_ sender: Any) {
        statusItem?.button?.performClick(nil)
    }
    
    @objc private func openApp() {
        // Set flag before showing window
        isExplicitlyOpened = true
        showMainWindow()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func showMainWindow() {
        // Set flag to indicate explicit user action
        isExplicitlyOpened = true
        
        // Always show the window when explicitly requested
        NSApplication.shared.setActivationPolicy(.regular)
        
        if let window = mainWindow {
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        } else {
            let url = URL(string: "freeWhisper://openMainWindow")!
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
