import Foundation
import AppKit

@MainActor
class VoiceCommandManager: ObservableObject {
    static let shared = VoiceCommandManager()
    
    @Published var isSearching = false
    @Published var searchResults: [AppSearchResult] = []
    @Published var recentlyAddedCommand: VoiceCommand?
    @Published var lastError: String?
    
    private let commandStore = VoiceCommandStore.shared
    
    private init() {}
    
    struct AppSearchResult: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let bundleId: String?
        let icon: NSImage?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: AppSearchResult, rhs: AppSearchResult) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - App Search and Command Creation
    
    /// Searches for applications matching the given query
    /// - Parameter query: Search query
    /// - Returns: Array of matching app names
    func searchApplications(_ query: String) async -> [AppSearchResult] {
        guard !query.isEmpty else { return [] }
        
        await MainActor.run {
            self.isSearching = true
            self.searchResults = []
            self.lastError = nil
        }
        
        let workspace = NSWorkspace.shared
        let allApps = commandStore.getInstalledApplications()
        var results: [AppSearchResult] = []
        
        let normalizedQuery = query.lowercased()
        
        // Filter apps by query
        let matchingApps = allApps.filter { appName in
            appName.lowercased().contains(normalizedQuery)
        }
        
        // Create search results with icons
        for appName in matchingApps {
            var icon: NSImage? = nil
            var bundleId: String? = nil
            
            // Try to get the app's icon
            if let appURL = workspace.urlForApplication(withBundleIdentifier: appName) ?? 
                            workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(appName).app")) {
                icon = workspace.icon(forFile: appURL.path)
                if let bundle = Bundle(url: appURL) {
                    bundleId = bundle.bundleIdentifier
                }
            }
            
            results.append(AppSearchResult(name: appName, bundleId: bundleId, icon: icon))
        }
        
        // Sort results: exact matches first, then starts with, then contains
        results.sort { a, b in
            if a.name.lowercased() == normalizedQuery && b.name.lowercased() != normalizedQuery {
                return true
            } else if a.name.lowercased() != normalizedQuery && b.name.lowercased() == normalizedQuery {
                return false
            } else if a.name.lowercased().starts(with: normalizedQuery) && !b.name.lowercased().starts(with: normalizedQuery) {
                return true
            } else if !a.name.lowercased().starts(with: normalizedQuery) && b.name.lowercased().starts(with: normalizedQuery) {
                return false
            } else {
                return a.name < b.name
            }
        }
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
        
        return results
    }
    
    /// Adds a voice command to open an application
    /// - Parameters:
    ///   - appName: Name of the application
    ///   - customPhrase: Optional custom phrase to use
    /// - Returns: Success flag and error message if failed
    @discardableResult
    func addAppCommand(appName: String, customPhrase: String? = nil) async -> (success: Bool, error: String?) {
        await MainActor.run {
            self.lastError = nil
        }
        
        // Create and add the command
        let command = commandStore.createAppOpenCommand(appName: appName, customPhrase: customPhrase)
        await commandStore.addCommand(command)
        
        // Store as recently added
        await MainActor.run {
            self.recentlyAddedCommand = command
        }
        
        return (true, nil)
    }
    
    /// Adds a voice command by searching for an application by partial name
    /// - Parameters:
    ///   - partialName: Partial name to search for
    ///   - customPhrase: Optional custom phrase to use
    /// - Returns: Success flag, found app name if successful, and error message if failed
    @discardableResult
    func addAppCommandBySearch(partialName: String, customPhrase: String? = nil) async -> (success: Bool, foundApp: String?, error: String?) {
        await MainActor.run {
            self.lastError = nil
        }
        
        let result = await commandStore.addAppCommandByPartialName(partialName, customPhrase: customPhrase)
        
        if result.success, let appName = result.foundAppName {
            // Get the command that was just added
            let commands = commandStore.commands
            if let addedCommand = commands.first(where: { 
                if case .shellCommand(let cmd) = $0.action {
                    return cmd.contains(appName)
                }
                return false
            }) {
                await MainActor.run {
                    self.recentlyAddedCommand = addedCommand
                }
            }
            
            return (true, appName, nil)
        } else {
            let errorMessage = "Could not find an application matching '\(partialName)'"
            await MainActor.run {
                self.lastError = errorMessage
            }
            return (false, nil, errorMessage)
        }
    }
    
    // MARK: - Command Management
    
    /// Gets all voice commands
    /// - Returns: Array of voice commands
    func getAllCommands() -> [VoiceCommand] {
        return commandStore.commands
    }
    
    /// Gets voice commands for opening applications
    /// - Returns: Array of app opening voice commands
    func getAppCommands() -> [VoiceCommand] {
        return commandStore.commands.filter { command in
            if case .shellCommand = command.action {
                return true
            }
            return false
        }
    }
    
    /// Deletes a voice command
    /// - Parameter command: Command to delete
    func deleteCommand(_ command: VoiceCommand) async {
        await commandStore.deleteCommand(command)
    }
    
    /// Updates a voice command
    /// - Parameter command: Command to update
    func updateCommand(_ command: VoiceCommand) async {
        await commandStore.updateCommand(command)
    }
    
    /// Resets the voice command database
    func resetCommands() async {
        await commandStore.resetDatabase()
    }
} 