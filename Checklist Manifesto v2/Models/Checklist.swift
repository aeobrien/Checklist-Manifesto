import Foundation

struct Checklist: Identifiable, Codable {
    let id: UUID
    var title: String
    var items: [ChecklistItem]
    var tags: [String]
    var lastCompletedDate: Date?
    var autoResetEnabled: Bool
    var resetAfterDays: Int?
    var createdDate: Date
    var modifiedDate: Date
    var notes: String
    
    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        lastCompletedDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
        autoResetEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoResetEnabled) ?? false
        resetAfterDays = try container.decodeIfPresent(Int.self, forKey: .resetAfterDays)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate) ?? Date()
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
    
    init(id: UUID = UUID(), title: String, items: [ChecklistItem] = [], tags: [String] = [], autoResetEnabled: Bool = false, resetAfterDays: Int? = nil, notes: String = "") {
        self.id = id
        self.title = title
        self.items = items
        self.tags = tags
        self.autoResetEnabled = autoResetEnabled
        self.resetAfterDays = resetAfterDays
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.notes = notes
    }
    
    var isCompleted: Bool {
        guard !items.isEmpty else { return false }
        return items.allSatisfy { item in
            if item.hasChildren {
                return item.isSecondTicked == true
            } else {
                return item.isFirstTicked
            }
        }
    }
    
    var completionPercentage: Double {
        let (completed, total) = countCompletedItems()
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
    
    private func countCompletedItems() -> (completed: Int, total: Int) {
        var completed = 0
        var total = 0
        
        func countRecursively(_ items: [ChecklistItem]) {
            for item in items {
                if item.isLeaf {
                    total += 1
                    if item.isFirstTicked {
                        completed += 1
                    }
                } else {
                    total += 2
                    if item.isFirstTicked {
                        completed += 1
                    }
                    if item.isSecondTicked == true {
                        completed += 1
                    }
                    countRecursively(item.children)
                }
            }
        }
        
        countRecursively(items)
        return (completed, total)
    }
    
    mutating func reset() {
        for i in items.indices {
            items[i].reset()
        }
        modifiedDate = Date()
    }
    
    mutating func markCompleted() {
        lastCompletedDate = Date()
        modifiedDate = Date()
    }
    
    var shouldAutoReset: Bool {
        guard autoResetEnabled,
              let resetDays = resetAfterDays,
              let lastCompleted = lastCompletedDate else {
            return false
        }
        
        let daysSinceCompletion = Calendar.current.dateComponents([.day], from: lastCompleted, to: Date()).day ?? 0
        return daysSinceCompletion >= resetDays
    }
}