import AppKit
import ApplicationServices
import Carbon
import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", default: .init(.backtick, modifiers: .option))
    static let escape = Self("escape", default: .init(.escape))
}

class ShortcutManager {
    static let shared = ShortcutManager()

    // Current recording indicator view and state
    private var activeVm: IndicatorViewModel?
    private var holdWorkItem: DispatchWorkItem?
    private let holdThreshold: TimeInterval = 0.3
    private var holdMode = false

    private init() {
        print("ShortcutManager init")

        // Handle key down for recording shortcut: start or toggle and detect hold
        KeyboardShortcuts.onKeyDown(for: .toggleRecord) {
            // Cancel any pending hold detection
            self.holdWorkItem?.cancel()
            self.holdMode = false
            // Perform UI actions on the main actor
            Task { @MainActor in
                if self.activeVm == nil {
                    // First press: show indicator and start recording immediately
                    let cursorPosition = FocusUtils.getCurrentCursorPosition()
                    print("DEBUG: Current cursor position: \(cursorPosition)")
                    
                    var indicatorPoint: NSPoint? = nil
                    
                    // Try to get text caret position first (for text fields)
                    if let caret = FocusUtils.getCaretRect() {
                        if let screen = FocusUtils.getFocusedWindowScreen() {
                            // Convert from screen coordinates to window coordinates
                            // macOS screen coordinates have (0,0) at bottom left, but we need to flip y-coordinate
                            let screenHeight = screen.frame.height
                            indicatorPoint = NSPoint(x: caret.origin.x, y: screenHeight - caret.origin.y)
                            print("DEBUG: Found caret position: \(caret.origin), converted to: \(String(describing: indicatorPoint))")
                        } else {
                            print("DEBUG: Found caret but couldn't determine screen")
                        }
                    }
                    
                    // Fallback to mouse cursor position if no caret found
                    if indicatorPoint == nil {
                        indicatorPoint = cursorPosition
                        print("DEBUG: Using mouse cursor position as fallback: \(String(describing: indicatorPoint))")
                    }
                    
                    // Get the current active screen
                    let activeScreen = NSScreen.screens.first { screen in
                        screen.frame.contains(indicatorPoint!)
                    } ?? NSScreen.main
                    
                    // Ensure the point is within screen bounds
                    if let screen = activeScreen {
                        let screenFrame = screen.visibleFrame
                        let x = max(screenFrame.minX, min(indicatorPoint!.x, screenFrame.maxX))
                        let y = max(screenFrame.minY, min(indicatorPoint!.y, screenFrame.maxY))
                        indicatorPoint = NSPoint(x: x, y: y)
                        print("DEBUG: Adjusted point to screen bounds: \(String(describing: indicatorPoint))")
                    }
                    
                    // Show the indicator at the determined position
                    let vm = IndicatorWindowManager.shared.show(nearPoint: indicatorPoint)
                    vm.startRecording()
                    self.activeVm = vm
                } else if !self.holdMode {
                    // Second quick press: toggle off recording
                    IndicatorWindowManager.shared.stopRecording()
                    self.activeVm = nil
                }
            }
            // Schedule hold-mode flag after threshold
            let workItem = DispatchWorkItem {
                self.holdMode = true
            }
            self.holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + self.holdThreshold, execute: workItem)
        }

        // Handle key up for recording shortcut: end hold if in hold mode
        KeyboardShortcuts.onKeyUp(for: .toggleRecord) {
            // Cancel hold detection
            self.holdWorkItem?.cancel()
            self.holdWorkItem = nil
            // Perform UI actions on the main actor
            Task { @MainActor in
                if self.holdMode {
                    // End hold-to-record
                    IndicatorWindowManager.shared.stopRecording()
                    self.activeVm = nil
                    self.holdMode = false
                }
                // Tap-mode toggle off handled on keyDown
            }
        }

        KeyboardShortcuts.onKeyUp(for: .escape) {
            // Run on the main actor to safely interact with actor-isolated methods
            Task { @MainActor in
                if self.activeVm != nil {
                    print("ShortcutManager: Escape key pressed, stopping recording")
                    IndicatorWindowManager.shared.stopForce()
                    self.activeVm = nil
                    
                    // Make sure to cancel any pending hold detection
                    self.holdWorkItem?.cancel()
                    self.holdWorkItem = nil
                    self.holdMode = false
                }
            }
        }
        KeyboardShortcuts.disable(.escape)
    }

}