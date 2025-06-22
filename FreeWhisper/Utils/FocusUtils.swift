//
//  FocusUtils.swift
//  FreeWhisper
//
//  Created by user on 07.02.2025.
//

import AppKit
import ApplicationServices
import Carbon
import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

class FocusUtils {
    
    /// Gets the current mouse cursor position in screen coordinates
    /// - Returns: The current mouse cursor position
    static func getCurrentCursorPosition() -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        print("FocusUtils: Mouse location: \(mouseLocation)")
        return mouseLocation
    }
    
    /// Gets the text caret rectangle in screen coordinates
    /// - Returns: The text caret rectangle, or nil if no caret is found
    static func getCaretRect() -> CGRect? {
        // Get system-wide accessibility element
        let systemElement = AXUIElementCreateSystemWide()
        
        // Get focused element
        var focusedElement: CFTypeRef?
        let errorFocused = AXUIElementCopyAttributeValue(systemElement,
                                                         kAXFocusedUIElementAttribute as CFString,
                                                         &focusedElement)
        
        if errorFocused != .success {
            print("FocusUtils: Failed to get focused element, error: \(errorFocused)")
            return nil
        }
        
        guard let focusedElementCF = focusedElement else {
            print("FocusUtils: Focused element is nil")
            return nil
        }
        
        let element = focusedElementCF as! AXUIElement
        
        // Try multiple approaches to get the caret position
        
        // Approach 1: Try to get selected text range
        if let caretRect = getCaretRectFromSelectedTextRange(element) {
            print("FocusUtils: Found caret rect from selected text range: \(caretRect)")
            return caretRect
        }
        
        // Approach 2: Try to get insertion point
        if let caretRect = getCaretRectFromInsertionPoint(element) {
            print("FocusUtils: Found caret rect from insertion point: \(caretRect)")
            return caretRect
        }
        
        // Approach 3: Try to get position from selected text attribute
        if let caretRect = getCaretRectFromSelectedText(element) {
            print("FocusUtils: Found caret rect from selected text: \(caretRect)")
            return caretRect
        }
        
        print("FocusUtils: Failed to get caret rect using any method")
        return nil
    }
    
    /// Gets the caret rectangle from the selected text range
    /// - Parameter element: The accessibility element
    /// - Returns: The caret rectangle, or nil if not found
    private static func getCaretRectFromSelectedTextRange(_ element: AXUIElement) -> CGRect? {
        var selectedTextRange: AnyObject?
        let errorRange = AXUIElementCopyAttributeValue(element,
                                                       kAXSelectedTextRangeAttribute as CFString,
                                                       &selectedTextRange)
        
        guard errorRange == .success, let textRange = selectedTextRange else {
            print("FocusUtils: Failed to get selected text range, error: \(errorRange)")
            return nil
        }
        
        var caretBounds: CFTypeRef?
        let errorBounds = AXUIElementCopyParameterizedAttributeValue(element,
                                                                     kAXBoundsForRangeParameterizedAttribute as CFString,
                                                                     textRange,
                                                                     &caretBounds)
        
        guard errorBounds == .success, let bounds = caretBounds else {
            print("FocusUtils: Failed to get bounds for range, error: \(errorBounds)")
            return nil
        }
        
        let rect = bounds as! AXValue
        return rect.toCGRect()
    }
    
    /// Gets the caret rectangle from the insertion point
    /// - Parameter element: The accessibility element
    /// - Returns: The caret rectangle, or nil if not found
    private static func getCaretRectFromInsertionPoint(_ element: AXUIElement) -> CGRect? {
        var insertionPoint: AnyObject?
        let errorPoint = AXUIElementCopyAttributeValue(element,
                                                       "AXInsertionPointLocation" as CFString,
                                                       &insertionPoint)
        
        guard errorPoint == .success, let point = insertionPoint else {
            return nil
        }
        
        // Check if point is an AXValue by comparing its CFTypeID
        if CFGetTypeID(point as CFTypeRef) == AXValueGetTypeID(),
           let position = (point as! AXValue).toCGPoint() {
            // Create a small rectangle around the insertion point
            return CGRect(x: position.x - 1, y: position.y - 8, width: 2, height: 16)
        }
        
        return nil
    }
    
    /// Gets the caret rectangle from the selected text
    /// - Parameter element: The accessibility element
    /// - Returns: The caret rectangle, or nil if not found
    private static func getCaretRectFromSelectedText(_ element: AXUIElement) -> CGRect? {
        var selectedText: AnyObject?
        let errorText = AXUIElementCopyAttributeValue(element,
                                                      kAXSelectedTextAttribute as CFString,
                                                      &selectedText)
        
        guard errorText == .success, let _ = selectedText as? String else {
            return nil
        }
        
        var position: AnyObject?
        let errorPosition = AXUIElementCopyAttributeValue(element,
                                                          "AXPosition" as CFString,
                                                          &position)
        
        guard errorPosition == .success, 
              let pos = position,
              CFGetTypeID(pos as CFTypeRef) == AXValueGetTypeID() else {
            return nil
        }
        
        if let point = (pos as! AXValue).toCGPoint() {
            return CGRect(x: point.x, y: point.y - 8, width: 2, height: 16)
        }
        
        return nil
    }
    
    /// Gets the screen containing the focused window
    /// - Returns: The screen containing the focused window, or the main screen if not found
    static func getFocusedWindowScreen() -> NSScreen? {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement,
                                                   kAXFocusedWindowAttribute as CFString,
                                                   &focusedWindow)
        
        guard result == .success else {
            print("FocusUtils: Failed to get focused window, error: \(result)")
            return NSScreen.main
        }
        
        let windowElement = focusedWindow as! AXUIElement
        
        var windowFrameValue: CFTypeRef?
        let frameResult = AXUIElementCopyAttributeValue(windowElement,
                                                        "AXFrame" as CFString,
                                                        &windowFrameValue)
        
        guard frameResult == .success else {
            print("FocusUtils: Failed to get window frame, error: \(frameResult)")
            return NSScreen.main
        }
        
        let frameValue = windowFrameValue as! AXValue
        
        var windowFrame = CGRect.zero
        guard AXValueGetValue(frameValue, AXValueType.cgRect, &windowFrame) else {
            print("FocusUtils: Failed to extract CGRect from AXValue")
            return NSScreen.main
        }
        
        print("FocusUtils: Window frame: \(windowFrame)")
        
        for screen in NSScreen.screens {
            if screen.frame.intersects(windowFrame) {
                print("FocusUtils: Found screen for window: \(screen)")
                return screen
            }
        }
        
        print("FocusUtils: Using main screen as fallback")
        return NSScreen.main
    }
}

private extension AXValue {
    func toCGRect() -> CGRect? {
        var rect = CGRect.zero
        let type: AXValueType = AXValueGetType(self)
        
        guard type == .cgRect else {
            print("AXValue is not of type CGRect, but \(type)")
            return nil
        }
        
        let success = AXValueGetValue(self, .cgRect, &rect)
        
        guard success else {
            print("Failed to get CGRect value from AXValue")
            return nil
        }
        return rect
    }
    
    func toCGPoint() -> CGPoint? {
        var point = CGPoint.zero
        let type: AXValueType = AXValueGetType(self)
        
        guard type == .cgPoint else {
            print("AXValue is not of type CGPoint, but \(type)")
            return nil
        }
        
        let success = AXValueGetValue(self, .cgPoint, &point)
        
        guard success else {
            print("Failed to get CGPoint value from AXValue")
            return nil
        }
        return point
    }
}
