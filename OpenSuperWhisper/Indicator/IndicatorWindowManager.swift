import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
class IndicatorWindowManager: IndicatorViewDelegate {
    static let shared = IndicatorWindowManager()
    
    var window: NSWindow?
    var viewModel: IndicatorViewModel?
    private var initialDragLocation: NSPoint?
    
    private init() {}
    
    func show(nearPoint point: NSPoint? = nil) -> IndicatorViewModel {
        
        print("IndicatorWindowManager: Showing indicator window")
        KeyboardShortcuts.enable(.escape)
        
        // Create new view model
        let newViewModel = IndicatorViewModel()
        newViewModel.delegate = self
        viewModel = newViewModel
        
        if window == nil {
            print("IndicatorWindowManager: Creating new window")
            // Create window if it doesn't exist
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 70), // Slightly taller to accommodate the drag handle
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            // Use the highest level to ensure visibility
            window.level = NSWindow.Level.floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.acceptsMouseMovedEvents = true
            window.ignoresMouseEvents = false
            
            // Ensure the window stays on screen when screen size changes
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // Create the SwiftUI view that provides the window contents
            let contentView = DraggableIndicatorWrapper(
                viewModel: newViewModel,
                onDragStarted: { [weak self] event in
                    self?.handleDragStarted(event)
                },
                onDragChanged: { [weak self] event in
                    self?.handleDragChanged(event)
                },
                onDragEnded: { [weak self] event in
                    self?.handleDragEnded(event)
                }
            )
            
            window.contentView = NSHostingView(rootView: contentView)
            
            // Store reference to window
            self.window = window
            
            // Make it key and order front
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        
        // Position window (this will use saved position if available)
        positionWindow(at: point)
        
        // Make the window visible and bring to front
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
        return viewModel!
    }
    
    // Extracted method to position the window
    private func positionWindow(at point: NSPoint? = nil) {
        guard let window = window, let screen = NSScreen.main else { 
            print("IndicatorWindowManager: No window or no main screen")
            return 
        }
        
        let windowFrame = window.frame
        
        // Important: Use visibleFrame to account for the menu bar
        let screenFrame = screen.visibleFrame
        
        var x: CGFloat
        var y: CGFloat
        
        // Check if we have a stored position
        let prefs = AppPreferences.shared
        let storedX = prefs.indicatorWindowPositionX
        let storedY = prefs.indicatorWindowPositionY
        let shouldPositionNearNotch = prefs.shouldPositionNearNotch
        
        print("IndicatorWindowManager: Stored position - X: \(storedX), Y: \(storedY), UseNotch: \(shouldPositionNearNotch)")
        
        if storedX >= 0 && storedY >= 0 && !shouldPositionNearNotch {
            // Use stored position
            x = storedX
            y = storedY
            print("IndicatorWindowManager: Using stored position")
        } else if let point = point {
            // Use provided point
            x = point.x - (windowFrame.width / 2)
            y = point.y - (windowFrame.height / 2)
            print("IndicatorWindowManager: Using provided point")
        } else {
            // Default position: center top 
            // Note: Screen coordinates in macOS have (0,0) at bottom left
            x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
            y = screenFrame.origin.y + screenFrame.height - windowFrame.height - 10
            
            // For debugging
            let screenOrigin = screenFrame.origin
            let screenSize = screenFrame.size
            print("IndicatorWindowManager: Screen frame - Origin: (\(screenOrigin.x), \(screenOrigin.y)), Size: \(screenSize.width) x \(screenSize.height)")
            print("IndicatorWindowManager: Window size - \(windowFrame.width) x \(windowFrame.height)")
            print("IndicatorWindowManager: Calculated position - X: \(x), Y: \(y)")
        }
        
        // Ensure window stays within screen bounds
        x = max(screenFrame.origin.x, min(x, screenFrame.origin.x + screenFrame.width - windowFrame.width))
        y = max(screenFrame.origin.y, min(y, screenFrame.origin.y + screenFrame.height - windowFrame.height))
        
        print("IndicatorWindowManager: Final position - X: \(x), Y: \(y)")
        
        // Set the window position
        window.setFrameOrigin(NSPoint(x: x, y: y))
        
        // Update visual aspects to ensure it's visible
        window.backgroundColor = .clear
        window.alphaValue = 1.0
    }
    
    // Public method to reset position to default (under notch)
    func resetPositionToDefault() {
        print("IndicatorWindowManager: Resetting position to default")
        AppPreferences.shared.shouldPositionNearNotch = true
        AppPreferences.shared.indicatorWindowPositionX = -1
        AppPreferences.shared.indicatorWindowPositionY = -1
        positionWindow()
    }
    
    // Add an initialization block to ensure the window is positioned correctly when the app first starts
    func initialize() {
        // Reset to default position if this is the first launch or if position hasn't been set
        let prefs = AppPreferences.shared
        
        // Force reset to default position (top center) on first launch or initialization
        prefs.shouldPositionNearNotch = true
        prefs.indicatorWindowPositionX = -1
        prefs.indicatorWindowPositionY = -1
        
        print("IndicatorWindowManager: Initialized with default position")
        
        // If window already exists, reposition it
        if let window = self.window {
            positionWindow()
        }
    }
    
    // Drag handling methods
    func handleDragStarted(_ event: NSEvent) {
        guard let window = self.window else { return }
        initialDragLocation = window.convertPoint(fromScreen: NSEvent.mouseLocation)
    }
    
    func handleDragChanged(_ event: NSEvent) {
        guard let window = self.window,
              let initialLocation = initialDragLocation else { return }
        
        let currentLocation = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let deltaX = currentLocation.x - initialLocation.x
        let deltaY = currentLocation.y - initialLocation.y
        
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        
        window.setFrameOrigin(newOrigin)
    }
    
    func handleDragEnded(_ event: NSEvent) {
        guard let window = self.window else { return }
        
        // Save the final position
        let prefs = AppPreferences.shared
        prefs.indicatorWindowPositionX = Double(window.frame.origin.x)
        prefs.indicatorWindowPositionY = Double(window.frame.origin.y)
        prefs.shouldPositionNearNotch = false
        
        initialDragLocation = nil
    }
    
    func stopRecording() {
        viewModel?.startDecoding()
    }
    
    func stopForce() {
        viewModel?.cancelRecording()
        hide()
    }

    func hide() {
        KeyboardShortcuts.disable(.escape)
        
        Task {
            guard let viewModel = self.viewModel else { return }
            
            await viewModel.hideWithAnimation()
            
            self.window?.orderOut(nil)
            self.viewModel = nil
        }
    }
    
    func didFinishDecoding() {
        hide()
    }

    // Add this method which is called by the initial contentView setup
    private func windowDragged(with event: NSEvent) {
        handleDragChanged(event)
    }
}

// Window delegate to help with dragging behavior
class IndicatorWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        IndicatorWindowManager.shared.hide()
        return false
    }
}

// SwiftUI wrapper to handle dragging
struct DraggableIndicatorWrapper: View {
    let viewModel: IndicatorViewModel
    let onDragStarted: (NSEvent) -> Void
    let onDragChanged: (NSEvent) -> Void
    let onDragEnded: (NSEvent) -> Void
    
    var body: some View {
        // Use a ZStack to make entire area draggable
        ZStack {
            // Debug background to ensure visibility
            Color.clear.contentShape(Rectangle())
            
            IndicatorWindow(viewModel: viewModel)
        }
        .frame(width: 200, height: 70)
        .contentShape(Rectangle()) // Make entire area interactive
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if let event = NSApplication.shared.currentEvent {
                        if value.translation == .zero {
                            onDragStarted(event)
                        } else {
                            onDragChanged(event)
                        }
                    }
                }
                .onEnded { _ in
                    if let event = NSApplication.shared.currentEvent {
                        onDragEnded(event)
                    }
                }
        )
    }
}
