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
        guard let data = try? Data(contentsOf: fileURL),
              let appData = try? JSONDecoder().decode(AppData.self, from: data) else {
            return AppData()
        }
        return appData
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL)
    }
}