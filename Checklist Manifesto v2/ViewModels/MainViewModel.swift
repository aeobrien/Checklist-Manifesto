import Foundation
import SwiftUI

@MainActor
class MainViewModel: ObservableObject {
    @Published var appData: AppData
    @Published var selectedTag: String?
    @Published var showingCreateChecklist = false
    @Published var showingImport = false
    
    init() {
        self.appData = AppData.load()
        
        if appData.checklists.isEmpty {
            createSampleData()
        }
    }
    
    func saveData() {
        appData.save()
    }
    
    func getAllUsedItemTitles() -> [String] {
        var titles = Set<String>()
        
        func collectTitles(from items: [ChecklistItem]) {
            for item in items {
                titles.insert(item.title)
                if !item.children.isEmpty {
                    collectTitles(from: item.children)
                }
            }
        }
        
        for checklist in appData.checklists {
            collectTitles(from: checklist.items)
        }
        
        return Array(titles).sorted()
    }
    
    func deleteChecklist(_ checklist: Checklist) {
        appData.checklists.removeAll { $0.id == checklist.id }
        saveData()
    }
    
    func duplicateChecklist(_ checklist: Checklist) {
        var newChecklist = Checklist(
            id: UUID(),
            title: "\(checklist.title) (Copy)",
            items: checklist.items,
            tags: checklist.tags,
            autoResetEnabled: checklist.autoResetEnabled,
            resetAfterDays: checklist.resetAfterDays
        )
        newChecklist.reset()
        
        appData.checklists.append(newChecklist)
        saveData()
    }
    
    func createChecklist(title: String, tags: [String], autoReset: Bool, resetDays: Int?) {
        let newChecklist = Checklist(
            title: title,
            tags: tags,
            autoResetEnabled: autoReset,
            resetAfterDays: resetDays
        )
        appData.checklists.append(newChecklist)
        saveData()
    }
    
    func importChecklist(from jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decodedChecklist = try? JSONDecoder().decode(Checklist.self, from: data) else {
            return
        }
        
        var checklist = Checklist(
            id: UUID(),
            title: decodedChecklist.title,
            items: decodedChecklist.items,
            tags: decodedChecklist.tags,
            autoResetEnabled: decodedChecklist.autoResetEnabled,
            resetAfterDays: decodedChecklist.resetAfterDays
        )
        checklist.reset()
        
        appData.checklists.append(checklist)
        saveData()
    }
    
    private func createSampleData() {
        let packingList = Checklist(
            title: "Weekend Trip Packing",
            items: [
                ChecklistItem(
                    title: "Clothing",
                    children: [
                        ChecklistItem(title: "2 T-shirts", nestingLevel: 1),
                        ChecklistItem(title: "1 Pair of jeans", nestingLevel: 1),
                        ChecklistItem(title: "Underwear", nestingLevel: 1),
                        ChecklistItem(title: "Socks", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                ),
                ChecklistItem(
                    title: "Toiletries",
                    children: [
                        ChecklistItem(title: "Toothbrush", nestingLevel: 1),
                        ChecklistItem(title: "Toothpaste", nestingLevel: 1),
                        ChecklistItem(title: "Shampoo", nestingLevel: 1),
                        ChecklistItem(title: "Deodorant", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                ),
                ChecklistItem(
                    title: "Electronics",
                    children: [
                        ChecklistItem(title: "Phone charger", nestingLevel: 1),
                        ChecklistItem(title: "Headphones", nestingLevel: 1),
                        ChecklistItem(title: "Laptop", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                ),
                ChecklistItem(title: "Passport/ID", nestingLevel: 0),
                ChecklistItem(title: "Wallet", nestingLevel: 0),
                ChecklistItem(title: "Keys", nestingLevel: 0)
            ],
            tags: ["Travel", "Packing"],
            autoResetEnabled: true,
            resetAfterDays: 7
        )
        
        let groceryList = Checklist(
            title: "Weekly Groceries",
            items: [
                ChecklistItem(
                    title: "Produce",
                    children: [
                        ChecklistItem(title: "Apples", nestingLevel: 1),
                        ChecklistItem(title: "Bananas", nestingLevel: 1),
                        ChecklistItem(title: "Lettuce", nestingLevel: 1),
                        ChecklistItem(title: "Tomatoes", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                ),
                ChecklistItem(
                    title: "Dairy",
                    children: [
                        ChecklistItem(title: "Milk", nestingLevel: 1),
                        ChecklistItem(title: "Cheese", nestingLevel: 1),
                        ChecklistItem(title: "Yogurt", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                ),
                ChecklistItem(
                    title: "Pantry",
                    children: [
                        ChecklistItem(title: "Bread", nestingLevel: 1),
                        ChecklistItem(title: "Rice", nestingLevel: 1),
                        ChecklistItem(title: "Pasta", nestingLevel: 1)
                    ],
                    nestingLevel: 0
                )
            ],
            tags: ["Shopping", "Weekly"],
            autoResetEnabled: true,
            resetAfterDays: 7
        )
        
        appData.checklists = [packingList, groceryList]
        saveData()
    }
}