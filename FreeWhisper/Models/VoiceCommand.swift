import Foundation
import GRDB
import AppKit

// MARK: - Voice Command Action Types

enum VoiceCommandAction: Codable, Equatable {
    case shellCommand(String)  // e.g., "open -a Spotify"
    case keyboardShortcut(KeyCombination)  // e.g., Ctrl+Option+Right
    
    var description: String {
        switch self {
        case .shellCommand(let command):
            return "Shell: \(command)"
        case .keyboardShortcut(let keys):
            return "Keys: \(keys.description)"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case shellCommand, keyboardShortcut
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.shellCommand) {
            let command = try container.decode(String.self, forKey: .shellCommand)
            self = .shellCommand(command)
        } else if container.contains(.keyboardShortcut) {
            let keyCombination = try container.decode(KeyCombination.self, forKey: .keyboardShortcut)
            self = .keyboardShortcut(keyCombination)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Neither shellCommand nor keyboardShortcut found"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .shellCommand(let command):
            try container.encode(command, forKey: .shellCommand)
        case .keyboardShortcut(let keyCombination):
            try container.encode(keyCombination, forKey: .keyboardShortcut)
        }
    }
}

struct KeyCombination: Codable, Equatable {
    let modifiers: [KeyModifier]
    let key: String
    
    init(modifiers: [KeyModifier], key: String) {
        self.modifiers = modifiers
        self.key = key
    }
    
    var description: String {
        let modifierStrings = modifiers.map { $0.symbol }.joined(separator: " + ")
        return modifierStrings.isEmpty ? key : "\(modifierStrings) + \(key)"
    }
    
    enum CodingKeys: String, CodingKey {
        case modifiers, key
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.modifiers) {
            do {
                self.modifiers = try container.decode([KeyModifier].self, forKey: .modifiers)
            } catch {
                print("Warning: Failed to decode modifiers in KeyCombination: \(error.localizedDescription)")
                self.modifiers = []
            }
        } else {
            print("Warning: Missing modifiers field in KeyCombination, using empty array")
            self.modifiers = []
        }
        
        do {
            self.key = try container.decode(String.self, forKey: .key)
        } catch {
            print("Error: Failed to decode key in KeyCombination: \(error.localizedDescription)")
            throw error
        }
    }
}

enum KeyModifier: String, CaseIterable, Codable {
    case command = "command"
    case option = "option"
    case control = "control"
    case shift = "shift"
    case function = "function"
    
    var displayName: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        case .function: return "Function"
        }
    }
    
    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        case .function: return "fn"
        }
    }
}

// MARK: - Voice Command Model

struct VoiceCommand: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    let id: UUID
    let phrase: String  // e.g., "open spotify"
    let action: VoiceCommandAction
    let isEnabled: Bool
    let createdAt: Date
    let lastUsed: Date?
    
    init(id: UUID = UUID(), phrase: String, action: VoiceCommandAction, isEnabled: Bool = true, createdAt: Date = Date(), lastUsed: Date? = nil) {
        self.id = id
        self.phrase = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.action = action
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
    
    // MARK: - Database Table Definition
    
    static let databaseTableName = "voice_commands"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let phrase = Column(CodingKeys.phrase)
        static let action = Column(CodingKeys.action)
        static let isEnabled = Column(CodingKeys.isEnabled)
        static let createdAt = Column(CodingKeys.createdAt)
        static let lastUsed = Column(CodingKeys.lastUsed)
    }
    
    // MARK: - GRDB Codable Support
    
    enum CodingKeys: String, CodingKey {
        case id, phrase, action, isEnabled, createdAt, lastUsed
    }
}

// MARK: - Voice Command Store

@MainActor
class VoiceCommandStore: ObservableObject {
    @Published var commands: [VoiceCommand] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    static let shared = VoiceCommandStore()
    
    private var dbPath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("FreeWhisper", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        
        return appSupportDir.appendingPathComponent("voice_commands.sqlite")
    }
    
    private var dbQueue: DatabaseQueue!
    
    private init() {
        do {
            dbQueue = try DatabaseQueue(path: dbPath.path)
            Task {
                await setupDatabase()
                await loadCommands()
            }
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }
    
    private nonisolated func setupDatabase() async {
        do {
            try await dbQueue.write { db in
                try self.setupDatabase(db)
            }
        } catch {
            print("Failed to setup database: \(error)")
        }
    }
    
    private nonisolated func setupDatabase(_ db: Database) throws {
        // Create table if it doesn't exist
        try db.create(table: VoiceCommand.databaseTableName, ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("phrase", .text).notNull()
            t.column("action", .blob).notNull()
            t.column("isEnabled", .boolean).notNull().defaults(to: true)
            t.column("createdAt", .datetime).notNull()
            t.column("lastUsed", .datetime)
        }
    }
    
    private func loadDefaultCommands() async {
        print("Loading default voice commands...")
        
        if commands.isEmpty {
            var defaultCommands: [VoiceCommand] = []
            
            // App opening commands - using the robust method
            let appCommands = [
                createAppOpenCommand(appName: "Google Chrome", customPhrase: "open chrome"),
                createAppOpenCommand(appName: "Finder"),
                createAppOpenCommand(appName: "WhatsApp"),
                createAppOpenCommand(appName: "WhatsApp", customPhrase: "open whats app"),
                createAppOpenCommand(appName: "Spotify")
            ]
            defaultCommands.append(contentsOf: appCommands)
            
            // Keyboard shortcut commands
            let keyboardCommands = [
                VoiceCommand(
                    phrase: "align right",
                    action: .keyboardShortcut(KeyCombination(
                        modifiers: [.control, .option],
                        key: "Right"
                    ))
                ),
                VoiceCommand(
                    phrase: "align left",
                    action: .keyboardShortcut(KeyCombination(
                        modifiers: [.control, .option],
                        key: "Left"
                    ))
                ),
                VoiceCommand(
                    phrase: "copy all",
                    action: .keyboardShortcut(KeyCombination(
                        modifiers: [.command],
                        key: "A"
                    ))
                )
            ]
            defaultCommands.append(contentsOf: keyboardCommands)
            
            // Add commands one by one with error handling
            for command in defaultCommands {
                do {
                    try await insertCommand(command)
                    print("Added default command: \(command.phrase)")
                } catch {
                    print("Failed to add default command \(command.phrase): \(error.localizedDescription)")
                }
            }
            
            // Reload commands after adding defaults
            let loadedCommands = (try? await fetchAllCommands()) ?? []
            await MainActor.run {
                self.commands = loadedCommands
            }
            print("Loaded \(loadedCommands.count) default commands")
        }
    }
    
    func loadCommands() async {
        // Check if we've tried loading commands too recently
        let lastLoadAttempt = UserDefaults.standard.double(forKey: "lastCommandLoadAttempt")
        let currentTime = Date().timeIntervalSince1970
        let backoffCount = UserDefaults.standard.integer(forKey: "commandLoadBackoffCount")
        
        // Calculate backoff time with exponential increase
        let backoffTime = pow(2.0, Double(min(backoffCount, 5))) * 0.5 // 0.5, 1, 2, 4, 8, 16 seconds
        
        // If we've tried loading too recently, back off to prevent infinite loops
        if currentTime - lastLoadAttempt < backoffTime {
            print("Backing off command loading to prevent infinite loop (attempt \(backoffCount), waiting \(backoffTime)s)")
            // Increase the backoff count
            UserDefaults.standard.set(backoffCount + 1, forKey: "commandLoadBackoffCount")
            
            // If we've backed off too many times in a row, reset the database
            if backoffCount > 5 {
                print("Too many rapid load attempts, resetting database")
                await resetDatabase()
                UserDefaults.standard.set(0, forKey: "commandLoadBackoffCount")
            }
            return
        }
        
        // Record this attempt
        UserDefaults.standard.set(currentTime, forKey: "lastCommandLoadAttempt")
        
        do {
            let loadedCommands = try await fetchAllCommands()
            await MainActor.run {
                self.commands = loadedCommands
            }
            
            // Successful load, reset backoff counter
            UserDefaults.standard.set(0, forKey: "commandLoadBackoffCount")
            print("Successfully loaded \(loadedCommands.count) commands")
            
            // If no commands were loaded, add default commands
            if loadedCommands.isEmpty {
                print("No commands found, loading defaults")
                await loadDefaultCommands()
            }
        } catch {
            print("Failed to load voice commands: \(error)")
            
            // Error recovery - try to recreate the database if there's a corruption
            if let dbError = error as? DatabaseError, 
               dbError.resultCode == .SQLITE_INTERRUPT || dbError.resultCode == .SQLITE_CORRUPT {
                print("Database appears to be corrupted, attempting recovery...")
                await recoverDatabase()
            } else if error is DecodingError {
                print("Decoding error detected, attempting to recover valid commands...")
                await recoverValidCommands()
            } else {
                // For other errors, try recovery after a few attempts
                let errorCount = UserDefaults.standard.integer(forKey: "commandLoadErrorCount") + 1
                UserDefaults.standard.set(errorCount, forKey: "commandLoadErrorCount")
                
                if errorCount > 3 {
                    print("Multiple load errors, attempting database recovery...")
                    await recoverValidCommands()
                    UserDefaults.standard.set(0, forKey: "commandLoadErrorCount")
                }
            }
        }
    }
    
    private func recoverDatabase() async {
        print("Attempting to recover database...")
        do {
            // Create a new database
            try await dbQueue.write { db in
                try db.drop(table: VoiceCommand.databaseTableName)
                try self.setupDatabase(db)
            }
            
            // Reload with default commands
            await loadDefaultCommands()
            print("Database recovery completed")
        } catch {
            print("Failed to recover database: \(error)")
        }
    }
    
    private func recoverValidCommands() async {
        print("Attempting to recover valid commands...")
        
        // Check if we've tried too many recovery attempts in a short period
        let lastRecoveryAttempt = UserDefaults.standard.double(forKey: "lastRecoveryAttempt")
        let currentTime = Date().timeIntervalSince1970
        
        // If we've tried recovery too recently, reset the database to break the loop
        if currentTime - lastRecoveryAttempt < 2.0 {
            print("Multiple recovery attempts in quick succession, resetting database to break loop")
            await resetDatabase()
            UserDefaults.standard.set(0, forKey: "recoveryAttempts")
            UserDefaults.standard.set(currentTime, forKey: "lastRecoveryAttempt")
            return
        }
        
        UserDefaults.standard.set(currentTime, forKey: "lastRecoveryAttempt")
        
        do {
            // Try to fetch commands one by one to identify corrupted ones
            var localCorruptedIDs: [UUID] = []
            var localValidCommands: [VoiceCommand] = []
            
            try await dbQueue.read { [self] db in
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(VoiceCommand.databaseTableName)")
                
                for row in rows {
                    // Try to get ID first
                    guard let idString = row["id"] as? String,
                          let id = UUID(uuidString: idString) else {
                        print("Failed to get valid ID from row")
                        continue
                    }
                    
                    print("Found command with ID: \(id)")
                    
                    // Try to reconstruct a valid command
                    if let phrase = row["phrase"] as? String,
                       let jsonData = row["action"] as? Data,
                       let action = try? JSONDecoder().decode(VoiceCommandAction.self, from: jsonData),
                       let isEnabled = row["isEnabled"] as? Bool,
                       let createdAt = row["createdAt"] as? Date {
                        
                        let lastUsed = row["lastUsed"] as? Date
                        
                        // Successfully reconstructed a valid command
                        let validCommand = VoiceCommand(
                            id: id,
                            phrase: phrase,
                            action: action,
                            isEnabled: isEnabled,
                            createdAt: createdAt,
                            lastUsed: lastUsed
                        )
                        localValidCommands.append(validCommand)
                        print("Successfully recovered command: \(phrase)")
                    } else {
                        print("Command with ID \(id) is corrupted, marking for deletion")
                        localCorruptedIDs.append(id)
                    }
                }
            }
            
            // Now update the commands with the valid ones we found
            await MainActor.run {
                self.commands = localValidCommands
            }
            
            // Delete corrupted commands
            if !localCorruptedIDs.isEmpty {
                print("Found \(localCorruptedIDs.count) corrupted commands, deleting them")
                try await dbQueue.write { db in
                    for id in localCorruptedIDs {
                        try db.execute(sql: "DELETE FROM \(VoiceCommand.databaseTableName) WHERE id = ?", arguments: [id.uuidString])
                    }
                }
            }
            
            // If we still have no commands, load defaults
            if localValidCommands.isEmpty {
                print("No valid commands recovered, loading defaults")
                await loadDefaultCommands()
            }
            
        } catch {
            print("Error during command recovery: \(error)")
            await resetDatabase()
        }
    }
    
    private nonisolated func deleteCommandByID(_ id: UUID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM \(VoiceCommand.databaseTableName) WHERE id = ?", arguments: [id.uuidString])
        }
    }
    
    private nonisolated func fetchAllCommands() async throws -> [VoiceCommand] {
        try await dbQueue.read { db in
            try VoiceCommand
                .order(VoiceCommand.Columns.phrase.asc)
                .fetchAll(db)
        }
    }
    
    func addCommand(_ command: VoiceCommand) async {
        do {
            try await insertCommand(command)
            await loadCommands()
        } catch {
            print("Failed to add voice command: \(error)")
        }
    }
    
    private nonisolated func insertCommand(_ command: VoiceCommand) async throws {
        try await dbQueue.write { db in
            try command.insert(db)
        }
    }
    
    func updateCommand(_ command: VoiceCommand) async {
        do {
            try await updateCommandInDB(command)
            await loadCommands()
        } catch {
            print("Failed to update voice command: \(error)")
        }
    }
    
    private nonisolated func updateCommandInDB(_ command: VoiceCommand) async throws {
        try await dbQueue.write { db in
            try command.update(db)
        }
    }
    
    func deleteCommand(_ command: VoiceCommand) async {
        do {
            try await deleteCommandFromDB(command)
            await loadCommands()
        } catch {
            print("Failed to delete voice command: \(error)")
        }
    }
    
    private nonisolated func deleteCommandFromDB(_ command: VoiceCommand) async throws {
        try await dbQueue.write { db in
            _ = try command.delete(db)
        }
    }
    
    func markCommandAsUsed(_ command: VoiceCommand) async {
        let updatedCommand = VoiceCommand(
            id: command.id,
            phrase: command.phrase,
            action: command.action,
            isEnabled: command.isEnabled,
            createdAt: command.createdAt,
            lastUsed: Date()
        )
        await updateCommand(updatedCommand)
    }
    
    // MARK: - Voice Command Matching
    
    func findMatchingCommand(for transcription: String) -> VoiceCommand? {
        let normalizedText = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for exact matches first
        return commands.first { command in
            command.isEnabled && normalizedText == command.phrase
        }
    }
    
    func resetDatabase() async {
        print("WARNING: Resetting voice commands database")
        
        // Clear all related UserDefaults to ensure a clean slate
        UserDefaults.standard.removeObject(forKey: "lastCommandLoadAttempt")
        UserDefaults.standard.removeObject(forKey: "commandLoadBackoffCount")
        UserDefaults.standard.removeObject(forKey: "recoveryAttempts")
        UserDefaults.standard.removeObject(forKey: "lastRecoveryAttempt")
        UserDefaults.standard.removeObject(forKey: "commandLoadErrorCount")
        
        do {
            try await dbQueue.write { db in
                try db.drop(table: VoiceCommand.databaseTableName)
                try self.setupDatabase(db)
            }
            
            // Clear in-memory commands
            await MainActor.run {
                self.commands = []
            }
            
            // Create a new database if needed
            if !FileManager.default.fileExists(atPath: self.dbPath.path) {
                self.dbQueue = try DatabaseQueue(path: self.dbPath.path)
                try await self.dbQueue.write { db in
                    try self.setupDatabase(db)
                }
            }
            
            // Load default commands
            await self.loadDefaultCommands()
            
        } catch {
            print("Error resetting database: \(error)")
        }
    }
    
    // MARK: - App Discovery and Command Creation
    
    /// Creates a voice command to open an application
    /// - Parameters:
    ///   - appName: The name of the application to open
    ///   - customPhrase: Optional custom phrase to use (defaults to "open {appName}")
    /// - Returns: A new VoiceCommand instance
    func createAppOpenCommand(appName: String, customPhrase: String? = nil) -> VoiceCommand {
        let normalizedAppName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = customPhrase ?? "open \(normalizedAppName)"
        
        // Create shell command that's more resilient:
        // 1. Try exact name match first
        // 2. Try case-insensitive match if exact fails
        // 3. Try partial match if others fail
        let shellCommand = """
        app_name="\(appName)"
        if open -a "$app_name" 2>/dev/null; then
            exit 0
        elif find /Applications -maxdepth 3 -name "$app_name.app" -o -name "$app_name *.app" 2>/dev/null | head -1 | xargs open 2>/dev/null; then
            exit 0
        elif find /Applications -maxdepth 3 -name "*.app" | grep -i "$app_name" 2>/dev/null | head -1 | xargs open 2>/dev/null; then
            exit 0
        else
            echo "Could not find application: $app_name"
            exit 1
        fi
        """
        
        return VoiceCommand(
            phrase: phrase,
            action: .shellCommand(shellCommand)
        )
    }
    
    /// Finds an application by partial name and returns the full app name if found
    /// - Parameter partialName: Partial name of the application to search for
    /// - Returns: Full application name if found, nil otherwise
    func findApplicationByPartialName(_ partialName: String) -> String? {
        let normalizedPartialName = partialName.lowercased()
        let allApps = getInstalledApplications()
        
        // First try exact match (case insensitive)
        if let exactMatch = allApps.first(where: { $0.lowercased() == normalizedPartialName }) {
            return exactMatch
        }
        
        // Then try starts with match
        if let startsWithMatch = allApps.first(where: { $0.lowercased().starts(with: normalizedPartialName) }) {
            return startsWithMatch
        }
        
        // Finally try contains match
        if let containsMatch = allApps.first(where: { $0.lowercased().contains(normalizedPartialName) }) {
            return containsMatch
        }
        
        return nil
    }
    
    /// Finds an application by partial name and creates a voice command to open it
    /// - Parameters:
    ///   - partialName: Partial name of the application to search for
    ///   - customPhrase: Optional custom phrase to use
    /// - Returns: A tuple containing the created command (if successful) and a success flag
    func createAppCommandByPartialName(_ partialName: String, customPhrase: String? = nil) -> (command: VoiceCommand?, success: Bool, foundAppName: String?) {
        if let appName = findApplicationByPartialName(partialName) {
            let command = createAppOpenCommand(appName: appName, customPhrase: customPhrase)
            return (command, true, appName)
        }
        return (nil, false, nil)
    }
    
    /// Adds a command to open an application by partial name
    /// - Parameters:
    ///   - partialName: Partial name of the application to search for
    ///   - customPhrase: Optional custom phrase to use
    /// - Returns: A tuple containing success flag and the found app name (if successful)
    @discardableResult
    func addAppCommandByPartialName(_ partialName: String, customPhrase: String? = nil) async -> (success: Bool, foundAppName: String?) {
        let result = createAppCommandByPartialName(partialName, customPhrase: customPhrase)
        if result.success, let command = result.command {
            await addCommand(command)
            return (true, result.foundAppName)
        }
        return (false, nil)
    }
    
    /// Gets a list of installed applications on the system
    /// - Returns: Array of application names
    func getInstalledApplications() -> [String] {
        let fileManager = FileManager.default
        var appNames: [String] = []
        
        // Look in main Applications folder
        if let appURLs = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Applications"),
            includingPropertiesForKeys: nil
        ) {
            for url in appURLs where url.pathExtension == "app" {
                if let appName = url.lastPathComponent.components(separatedBy: ".app").first {
                    appNames.append(appName)
                }
            }
        }
        
        // Look in user Applications folder
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            let userAppsPath = "\(homeDir)/Applications"
            if let userAppURLs = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: userAppsPath),
                includingPropertiesForKeys: nil
            ) {
                for url in userAppURLs where url.pathExtension == "app" {
                    if let appName = url.lastPathComponent.components(separatedBy: ".app").first {
                        appNames.append(appName)
                    }
                }
            }
        }
        
        return appNames.sorted()
    }
    
    /// Adds a command to open an application
    /// - Parameters:
    ///   - appName: The name of the application to open
    ///   - customPhrase: Optional custom phrase to use
    func addAppOpenCommand(appName: String, customPhrase: String? = nil) async {
        let command = createAppOpenCommand(appName: appName, customPhrase: customPhrase)
        await addCommand(command)
    }
} 