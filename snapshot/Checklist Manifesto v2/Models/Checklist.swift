import Foundation

enum ListType: String, Codable, CaseIterable {
    case weekendTrip = "Weekend Trip"
    case weekAway = "Week Away" 
    case international = "International"
    case dayTrip = "Day Trip"
    case business = "Business Trip"
    case camping = "Camping"
    case other = "Other"
}

enum CategoryStatus {
    case incomplete
    case amber // Complete except final pass
    case complete
}

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
    var listType: ListType
    var lastUsedCategory: String
    
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
        listType = ListType(rawValue: try container.decodeIfPresent(String.self, forKey: .listType) ?? "Other") ?? .other
        lastUsedCategory = try container.decodeIfPresent(String.self, forKey: .lastUsedCategory) ?? "General"
    }
    
    init(id: UUID = UUID(), title: String, items: [ChecklistItem] = [], tags: [String] = [], autoResetEnabled: Bool = false, resetAfterDays: Int? = nil, notes: String = "", listType: ListType = .other, lastUsedCategory: String = "General") {
        self.id = id
        self.title = title
        self.items = items
        self.tags = tags
        self.autoResetEnabled = autoResetEnabled
        self.resetAfterDays = resetAfterDays
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.notes = notes
        self.listType = listType
        self.lastUsedCategory = lastUsedCategory
    }
    
    var isCompleted: Bool {
        guard !items.isEmpty else { return false }
        return allCategoriesComplete().allComplete
    }
    
    func allCategoriesComplete() -> (allComplete: Bool, categories: [String: CategoryStatus]) {
        var categoryStatuses: [String: CategoryStatus] = [:]
        
        // Group items by category
        let groupedItems = Dictionary(grouping: items, by: { $0.category })
        
        for (category, categoryItems) in groupedItems {
            let status = categoryCompletionStatus(for: categoryItems)
            categoryStatuses[category] = status
        }
        
        let allComplete = categoryStatuses.values.allSatisfy { $0 == .complete }
        return (allComplete, categoryStatuses)
    }
    
    func categoryCompletionStatus(for items: [ChecklistItem]) -> CategoryStatus {
        guard !items.isEmpty else { return .complete }
        
        let packingItems = items.filter { $0.itemType == .packing }
        let todoItems = items.filter { $0.itemType == .todo }
        let finalPassItems = items.filter { $0.finalPass }
        let nonFinalPassItems = items.filter { !$0.finalPass }
        
        // Check if all packing items are stage 2 (Loaded)
        let allPackingComplete = packingItems.isEmpty || packingItems.allSatisfy { $0.stage == 2 }
        
        // Check if all TODO items are complete
        let allTodosComplete = todoItems.isEmpty || todoItems.allSatisfy { $0.isComplete }
        
        // If all non-final pass items are complete and only final pass items remain
        let nonFinalPassComplete = nonFinalPassItems.isEmpty || nonFinalPassItems.allSatisfy { item in
            if item.itemType == .packing {
                return item.stage == 2
            } else {
                return item.isComplete
            }
        }
        
        if allPackingComplete && allTodosComplete {
            return .complete
        } else if nonFinalPassComplete && !finalPassItems.isEmpty {
            return .amber // Complete except for final pass items
        } else {
            return .incomplete
        }
    }
    
    var categories: [String] {
        Array(Set(items.map { $0.category })).sorted()
    }
    
    var totalItemCount: Int {
        func countItems(_ items: [ChecklistItem]) -> Int {
            var count = 0
            for item in items {
                count += 1
                count += countItems(item.children)
            }
            return count
        }
        return countItems(items)
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
        print("\n🔄 Checklist.reset() - \(title)")
        print("  📊 Before reset: \(items.count) items, completion: \(completionPercentage)%")
        
        for i in items.indices {
            items[i].reset()
        }
        lastCompletedDate = nil  // Clear the completion date when resetting
        modifiedDate = Date()
        
        print("  📊 After reset: completion: \(completionPercentage)%")
    }
    
    mutating func convertCategoryToTodoType(_ category: String) {
        for i in items.indices where items[i].category == category {
            items[i].itemType = .todo
            items[i].stage = items[i].isFirstTicked ? 2 : 0
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