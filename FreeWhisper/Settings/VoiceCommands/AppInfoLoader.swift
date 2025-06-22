import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

class AppInfoLoader {
    static func loadInstalledApps() async -> [AppInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let workspace = NSWorkspace.shared
                let fileManager = FileManager.default
                
                // Common application directories
                let applicationDirectories = [
                    "/Applications",
                    "/System/Applications",
                    "/System/Applications/Utilities",
                    fileManager.homeDirectoryForCurrentUser.path + "/Applications"
                ]
                
                var appInfos: [AppInfo] = []
                
                for directory in applicationDirectories {
                    guard let enumerator = fileManager.enumerator(
                        at: URL(fileURLWithPath: directory),
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }
                    
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension == "app" {
                            if let bundle = Bundle(url: fileURL) {
                                if let bundleID = bundle.bundleIdentifier,
                                   let appName = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String {
                                    
                                    let appInfo = AppInfo(
                                        name: appName,
                                        bundleIdentifier: bundleID,
                                        path: fileURL.path
                                    )
                                    
                                    appInfos.append(appInfo)
                                }
                            }
                        }
                    }
                }
                
                // Sort apps alphabetically by name
                let sortedApps = appInfos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                
                // Remove duplicates based on bundle identifier
                var seenBundleIds = Set<String>()
                let uniqueApps = sortedApps.filter { app in
                    if seenBundleIds.contains(app.bundleIdentifier) {
                        return false
                    } else {
                        seenBundleIds.insert(app.bundleIdentifier)
                        return true
                    }
                }
                
                continuation.resume(returning: uniqueApps)
            }
        }
    }
} 