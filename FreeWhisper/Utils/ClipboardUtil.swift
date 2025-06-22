import Cocoa

class ClipboardUtil {
    // Store the latest transcription text
    private static var latestTranscription: String?
    // Keep track of the last known pasteboard change count
    private static var lastChangeCount: Int = 0
    private static var monitoringTimer: Timer?
    
    // Get the latest transcription
    static func getLatestTranscription() -> String? {
        return latestTranscription
    }
    
    // Set the latest transcription
    static func setLatestTranscription(_ text: String) {
        latestTranscription = text
        
        // Also update the pasteboard immediately
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        
        // Set up a timer to periodically check if our transcription is still on the clipboard
        startClipboardMonitoring()
    }
    
    // Start monitoring the clipboard for changes
    private static func startClipboardMonitoring() {
        // Cancel any existing timer
        monitoringTimer?.invalidate()
        
        // Create a timer to check for clipboard changes
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            checkClipboardChanges()
        }
        
        // Make sure the timer runs even when UI is busy
        RunLoop.current.add(monitoringTimer!, forMode: .common)
        
        // Stop monitoring after 30 seconds to avoid resource waste
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
    
    // Check if the clipboard has changed and restore our transcription if needed
    private static func checkClipboardChanges() {
        let pasteboard = NSPasteboard.general
        
        // If the change count has increased, the clipboard has been modified
        if pasteboard.changeCount > lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            // If we have a transcription, restore it after a short delay
            if let transcription = latestTranscription {
                // Wait a moment to avoid interfering with the user's immediate paste operation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Put our transcription at the top of the clipboard
                    pasteboard.clearContents()
                    pasteboard.setString(transcription, forType: .string)
                    
                    // Update the change count to avoid an infinite loop
                    lastChangeCount = pasteboard.changeCount
                    print("DEBUG: Restored transcription to top of clipboard")
                }
            }
        }
    }
    
    private static func saveCurrentPasteboardContents() -> ([NSPasteboard.PasteboardType: Any], [NSPasteboard.PasteboardType])? {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        // If pasteboard is empty, return nil
        guard !types.isEmpty else { return nil }
        
        var savedContents: [NSPasteboard.PasteboardType: Any] = [:]
        
        // Save data for each type
        for type in types {
            if let data = pasteboard.data(forType: type) {
                savedContents[type] = data
            } else if let string = pasteboard.string(forType: type) {
                savedContents[type] = string
            } else if let urls = pasteboard.propertyList(forType: type) as? [String] {
                savedContents[type] = urls
            }
        }
        
        return (!savedContents.isEmpty) ? (savedContents, types) : nil
    }
    
    private static func restorePasteboardContents(_ contents: ([NSPasteboard.PasteboardType: Any], [NSPasteboard.PasteboardType])) {
        let pasteboard = NSPasteboard.general
        let (savedContents, types) = contents
        
        pasteboard.declareTypes(types, owner: nil)
        
        // Restore data for each type
        for (type, content) in savedContents {
            if let data = content as? Data {
                pasteboard.setData(data, forType: type)
            } else if let string = content as? String {
                pasteboard.setString(string, forType: type)
            } else if let urls = content as? [String] {
                pasteboard.setPropertyList(urls, forType: type)
            }
        }
    }
    
    static func insertTextUsingPasteboard(_ text: String) {
        print("DEBUG: Starting insertTextUsingPasteboard with text: \(text.prefix(20))...")
        let pasteboard = NSPasteboard.general
        
        // Save the transcription as the latest one
        latestTranscription = text
        
        // Save current pasteboard contents
        let savedContents = saveCurrentPasteboardContents()
        print("DEBUG: Saved current pasteboard contents: \(savedContents != nil ? "yes" : "no")")
        
        // Set new text to pasteboard
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        print("DEBUG: Set text to pasteboard")
        
        // Create event source
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("ERROR: Failed to create event source")
            // Restore original contents if event source creation failed
            if let contents = savedContents {
                restorePasteboardContents(contents)
            }
            return
        }
        print("DEBUG: Created event source")
        
        // Key codes (in dec):
        // - Command (left) — 55
        // - V — 9
        let keyCodeCmd: CGKeyCode = 55
        let keyCodeV: CGKeyCode = 9
        
        // Create events: press Command, press V, release V, release Command
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeCmd, keyDown: true)
        
        // Set Command flag when pressing V
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        vDown?.flags = .maskCommand
        
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        vUp?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeCmd, keyDown: false)
        
        // Define event tap location
        let eventTapLocation = CGEventTapLocation.cghidEventTap
        
        print("DEBUG: Posting keyboard events for Command+V")
        // Post events to system
        cmdDown?.post(tap: eventTapLocation)
        vDown?.post(tap: eventTapLocation)
        vUp?.post(tap: eventTapLocation)
        cmdUp?.post(tap: eventTapLocation)
        
        // Add a small delay to ensure paste operation completes
        print("DEBUG: Sleeping for 0.1 seconds")
        Thread.sleep(forTimeInterval: 0.1)
        
        // Restore original contents but make sure our transcription is still accessible
        if let contents = savedContents {
            print("DEBUG: Restoring original pasteboard contents")
            restorePasteboardContents(contents)
            
            // After a short delay, put our transcription back on top of the clipboard
            // This ensures it's the first item when using Cmd+V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let transcription = latestTranscription {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(transcription, forType: .string)
                    print("DEBUG: Restored latest transcription to clipboard")
                }
            }
        }
        
        // Start monitoring the clipboard to keep our transcription at the top
        startClipboardMonitoring()
        
        print("DEBUG: Completed insertTextUsingPasteboard")
    }
    
    // Method to copy the latest transcription to clipboard
    static func copyLatestTranscriptionToClipboard() {
        if let transcription = latestTranscription {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(transcription, forType: .string)
            lastChangeCount = pasteboard.changeCount
            print("DEBUG: Copied latest transcription to clipboard")
            
            // Start monitoring to keep our transcription at the top
            startClipboardMonitoring()
        }
    }
} 