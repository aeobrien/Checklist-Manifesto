import Foundation

struct AppData: Codable {
    var checklists: [Checklist] = []
    
    var allTags: [String] {
        Array(Set(checklists.flatMap { $0.tags })).sorted()
    }
    
    func checklists(forTag tag: String) -> [Checklist] {
        checklists.filter { $0.tags.contains(tag) }
    }
    
    func checklistsWithoutTags() -> [Checklist] {
        checklists.filter { $0.tags.isEmpty }
    }
}

extension AppData {
    static let fileURL: URL = {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("checklistData.json")
    }()
    
    static func load() -> AppData {
        print("\n📂 LOADING AppData from: \(fileURL.path)")
        
        guard let data = try? Data(contentsOf: fileURL) else {
            print("  ⚠️ No data file found, returning empty AppData")
            return AppData()
        }
        
        print("  📏 File size: \(data.count) bytes")
        
        guard let appData = try? JSONDecoder().decode(AppData.self, from: data) else {
            print("  ❌ Failed to decode data, returning empty AppData")
            return AppData()
        }
        
        print("  ✅ Loaded \(appData.checklists.count) checklists")
        for checklist in appData.checklists {
            print("    - \(checklist.title): \(checklist.items.count) items")
        }
        
        return appData
    }
    
    func save() {
        print("\n💾 SAVING AppData to: \(Self.fileURL.path)")
        print("  📊 Saving \(checklists.count) checklists")
        
        for checklist in checklists {
            print("    - \(checklist.title): \(checklist.items.count) items, completed: \(checklist.completionPercentage)%")
            
            // Print first few items for debugging
            for (i, item) in checklist.items.prefix(3).enumerated() {
                print("      [\(i)] \(item.title) - ticked: \(item.isFirstTicked)")
            }
            if checklist.items.count > 3 {
                print("      ... and \(checklist.items.count - 3) more items")
            }
        }
        
        guard let data = try? JSONEncoder().encode(self) else {
            print("  ❌ Failed to encode data!")
            return
        }
        
        print("  📏 Encoded size: \(data.count) bytes")
        
        do {
            try data.write(to: Self.fileURL)
            print("  ✅ Successfully saved to disk")
            
            // Verify the save by reading back
            if let verifyData = try? Data(contentsOf: Self.fileURL) {
                print("  🔍 Verification: File exists with \(verifyData.count) bytes")
            }
        } catch {
            print("  ❌ Failed to write to disk: \(error)")
        }
    }
}