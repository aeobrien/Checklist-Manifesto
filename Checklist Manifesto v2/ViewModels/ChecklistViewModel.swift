import Foundation
import SwiftUI
import Combine

@MainActor
class ChecklistViewModel: ObservableObject {
    @Published var checklist: Checklist
    @Published var appData: AppData
    
    private var cancellables = Set<AnyCancellable>()
    private let resetTimer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    init(checklist: Checklist, appData: AppData) {
        self.checklist = checklist
        self.appData = appData
        
        setupAutoReset()
    }
    
    private func setupAutoReset() {
        resetTimer
            .sink { _ in
                self.checkForAutoReset()
            }
            .store(in: &cancellables)
    }
    
    private func checkForAutoReset() {
        if checklist.shouldAutoReset {
            resetChecklist()
        }
    }
    
    func toggleFirstTick(for item: ChecklistItem, isManual: Bool) {
        updateItem(item) { updatedItem in
            updatedItem.isFirstTicked.toggle()
            
            // If manual toggle on parent item, propagate to children
            if isManual && updatedItem.hasChildren {
                self.propagateManualToggle(to: &updatedItem.children, checked: updatedItem.isFirstTicked)
            }
        }
        
        // Only propagate upwards for automatic ticking
        if !isManual {
            propagateTickStates()
        }
        
        checkCompletion()
        saveChanges()
    }
    
    private func propagateManualToggle(to items: inout [ChecklistItem], checked: Bool) {
        for i in items.indices {
            items[i].isFirstTicked = checked
            if items[i].hasChildren {
                propagateManualToggle(to: &items[i].children, checked: checked)
            }
        }
    }
    
    func toggleSecondTick(for item: ChecklistItem) {
        guard item.hasChildren else { return }
        updateItem(item) { updatedItem in
            if let secondTicked = updatedItem.isSecondTicked {
                updatedItem.isSecondTicked = !secondTicked
            }
        }
        propagateTickStates()
        checkCompletion()
        saveChanges()
    }
    
    func toggleExpanded(for item: ChecklistItem) {
        updateItem(item) { updatedItem in
            updatedItem.toggleExpanded()
        }
    }
    
    private func updateItem(_ item: ChecklistItem, update: (inout ChecklistItem) -> Void) {
        func updateRecursively(_ items: inout [ChecklistItem]) -> Bool {
            for i in items.indices {
                if items[i].id == item.id {
                    update(&items[i])
                    return true
                }
                if updateRecursively(&items[i].children) {
                    return true
                }
            }
            return false
        }
        _ = updateRecursively(&checklist.items)
    }
    
    private func propagateTickStates() {
        func propagateRecursively(_ items: inout [ChecklistItem]) {
            for i in items.indices {
                if !items[i].children.isEmpty {
                    propagateRecursively(&items[i].children)
                    // Only auto-update the first checkbox based on children
                    let allChildrenFirstTicked = items[i].allChildrenFirstTicked
                    items[i].isFirstTicked = allChildrenFirstTicked
                    // Second checkbox must be manually ticked
                }
            }
        }
        propagateRecursively(&checklist.items)
    }
    
    private func checkCompletion() {
        if checklist.isCompleted && checklist.lastCompletedDate == nil {
            checklist.markCompleted()
        }
    }
    
    func resetChecklist() {
        checklist.reset()
        saveChanges()
    }
    
    func saveChanges() {
        checklist.modifiedDate = Date()
        if let index = appData.checklists.firstIndex(where: { $0.id == checklist.id }) {
            appData.checklists[index] = checklist
            appData.save()
        }
    }
    
    func addItem(title: String, parent: ChecklistItem? = nil) {
        let nestingLevel = (parent?.nestingLevel ?? -1) + 1
        let newItem = ChecklistItem(title: title, parentID: parent?.id, nestingLevel: nestingLevel)
        
        if let parent = parent {
            updateItem(parent) { updatedParent in
                updatedParent.children.append(newItem)
                if updatedParent.isSecondTicked == nil {
                    updatedParent.isSecondTicked = false
                }
            }
        } else {
            checklist.items.append(newItem)
        }
        
        propagateTickStates()
        saveChanges()
    }
    
    func deleteItem(_ item: ChecklistItem) {
        func deleteRecursively(_ items: inout [ChecklistItem]) -> Bool {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
                return true
            }
            for i in items.indices {
                if deleteRecursively(&items[i].children) {
                    if items[i].children.isEmpty {
                        items[i].isSecondTicked = nil
                    }
                    return true
                }
            }
            return false
        }
        _ = deleteRecursively(&checklist.items)
        propagateTickStates()
        saveChanges()
    }
    
    func moveItem(_ item: ChecklistItem, to newParent: ChecklistItem?) {
        var itemCopy: ChecklistItem?
        
        func removeItem(_ items: inout [ChecklistItem]) -> Bool {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                itemCopy = items[index]
                items.remove(at: index)
                return true
            }
            for i in items.indices {
                if removeItem(&items[i].children) {
                    if items[i].children.isEmpty {
                        items[i].isSecondTicked = nil
                    }
                    return true
                }
            }
            return false
        }
        
        guard removeItem(&checklist.items), var movedItem = itemCopy else { return }
        
        movedItem.parentID = newParent?.id
        movedItem.nestingLevel = (newParent?.nestingLevel ?? -1) + 1
        updateNestingLevels(&movedItem.children, baseLevel: movedItem.nestingLevel)
        
        if let newParent = newParent {
            updateItem(newParent) { updatedParent in
                updatedParent.children.append(movedItem)
                if updatedParent.isSecondTicked == nil {
                    updatedParent.isSecondTicked = false
                }
            }
        } else {
            checklist.items.append(movedItem)
        }
        
        propagateTickStates()
        saveChanges()
    }
    
    private func updateNestingLevels(_ items: inout [ChecklistItem], baseLevel: Int) {
        for i in items.indices {
            items[i].nestingLevel = baseLevel + 1
            updateNestingLevels(&items[i].children, baseLevel: items[i].nestingLevel)
        }
    }
    
    func flattenedItems() -> [(item: ChecklistItem, isVisible: Bool)] {
        var result: [(item: ChecklistItem, isVisible: Bool)] = []
        
        func flatten(_ items: [ChecklistItem], isParentExpanded: Bool = true) {
            for item in items {
                result.append((item: item, isVisible: isParentExpanded))
                if item.hasChildren {
                    flatten(item.children, isParentExpanded: isParentExpanded && item.isExpanded)
                }
            }
        }
        
        flatten(checklist.items)
        return result
    }
}