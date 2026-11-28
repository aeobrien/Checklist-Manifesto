import Foundation
import SwiftUI
import Combine

@MainActor
class ChecklistViewModel: ObservableObject {
    @Published var checklist: Checklist
    @Published var selectedItems: Set<UUID> = []
    @Published var isMultiSelectMode: Bool = false
    let mainViewModel: MainViewModel
    let checklistID: UUID
    
    private var cancellables = Set<AnyCancellable>()
    private let resetTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()  // Check every minute
    var undoStack: [ChecklistState] = []
    var redoStack: [ChecklistState] = []
    
    init(checklist: Checklist, mainViewModel: MainViewModel) {
        self.checklist = checklist
        self.checklistID = checklist.id
        self.mainViewModel = mainViewModel
        
        print("\n🔵 ChecklistViewModel INIT - Checklist: \(checklist.title), ID: \(checklist.id)")
        print("  📊 Initial item count: \(checklist.items.count)")
        print("  📊 MainViewModel has \(mainViewModel.appData.checklists.count) checklists")
        
        setupAutoReset()
        // Don't refresh on init - we already have the correct checklist passed in
        // refreshChecklistFromAppData()
    }
    
    private func setupAutoReset() {
        resetTimer
            .sink { _ in
                self.checkForAutoReset()
            }
            .store(in: &cancellables)
    }
    
    private func checkForAutoReset() {
        // Refresh checklist from mainViewModel to get latest state
        refreshChecklistFromAppData()
        
        if checklist.shouldAutoReset {
            resetChecklist()
        }
    }
    
    func refreshChecklistFromAppData() {
        print("🔄 REFRESH from AppData - Looking for ID: \(checklistID)")
        if let index = mainViewModel.appData.checklists.firstIndex(where: { $0.id == checklistID }) {
            let oldCount = checklist.items.count
            checklist = mainViewModel.appData.checklists[index]
            print("  ✅ Found checklist at index \(index)")
            print("  📊 Item count: \(oldCount) -> \(checklist.items.count)")
            
            // Print all items for debugging
            func printItems(_ items: [ChecklistItem], indent: String = "") {
                for item in items {
                    print("    \(indent)- \(item.title) [1st: \(item.isFirstTicked), 2nd: \(item.isSecondTicked?.description ?? "nil")]")
                    if !item.children.isEmpty {
                        printItems(item.children, indent: indent + "  ")
                    }
                }
            }
            printItems(checklist.items)
        } else {
            print("  ❌ Checklist NOT FOUND in AppData!")
        }
    }
    
    struct ChecklistState {
        let items: [ChecklistItem]
        let description: String
    }
    
    func saveUndoState(description: String) {
        undoStack.append(ChecklistState(items: checklist.items, description: description))
        redoStack.removeAll()
        // Limit undo stack size
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    func undo() {
        guard let state = undoStack.popLast() else { return }
        redoStack.append(ChecklistState(items: checklist.items, description: "Redo"))
        checklist.items = state.items
        saveChanges()
    }
    
    func redo() {
        guard let state = redoStack.popLast() else { return }
        undoStack.append(ChecklistState(items: checklist.items, description: "Undo"))
        checklist.items = state.items
        saveChanges()
    }
    
    func toggleStage(for item: ChecklistItem, targetStage: Int) {
        print("\n🔄 TOGGLE STAGE - Item: \(item.title), Target: \(targetStage)")
        print("  Current stage: \(item.stage)")
        
        updateItem(item) { updatedItem in
            if updatedItem.itemType == .todo {
                // TODO items only have stage 0 (not done) or 2 (done)
                updatedItem.setStage(updatedItem.stage == 2 ? 0 : 2)
            } else {
                // PACKING items
                if targetStage == 1 {
                    // Toggle packed state
                    updatedItem.setStage(updatedItem.stage >= 1 ? 0 : 1)
                } else if targetStage == 2 {
                    // Attempt to set loaded - enforce stage progression
                    if updatedItem.stage < 1 {
                        // Will be handled by the UI to show prompt
                        return
                    }
                    updatedItem.setStage(updatedItem.stage == 2 ? 1 : 2)
                }
            }
            print("  New stage: \(updatedItem.stage)")
        }
        
        propagateTickStates()
        checkCompletion()
        saveChanges()
    }
    
    func forceLoadedStage(for item: ChecklistItem) {
        updateItem(item) { updatedItem in
            updatedItem.setStage(2)
        }
        propagateTickStates()
        checkCompletion()
        saveChanges()
    }
    
    func toggleFirstTick(for item: ChecklistItem, isManual: Bool) {
        print("\n🔲 TOGGLE FIRST TICK - Item: \(item.title), Manual: \(isManual)")
        print("  Current state: \(item.isFirstTicked)")
        
        updateItem(item) { updatedItem in
            updatedItem.isFirstTicked.toggle()
            print("  New state: \(updatedItem.isFirstTicked)")
            
            // If manual toggle on parent item, propagate to children
            if isManual && updatedItem.hasChildren {
                print("  📢 Propagating to \(updatedItem.children.count) children")
                self.propagateManualToggle(to: &updatedItem.children, checked: updatedItem.isFirstTicked)
                // Auto-collapse when manually checking a parent
                if updatedItem.isFirstTicked {
                    updatedItem.isExpanded = false
                }
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
    
    func updateItem(_ item: ChecklistItem) {
        func updateRecursively(_ items: inout [ChecklistItem]) -> Bool {
            for i in items.indices {
                if items[i].id == item.id {
                    items[i] = item
                    return true
                }
                if updateRecursively(&items[i].children) {
                    return true
                }
            }
            return false
        }
        _ = updateRecursively(&checklist.items)
        propagateTickStates()
        saveChanges()
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
                    let wasUnchecked = !items[i].isFirstTicked
                    items[i].isFirstTicked = allChildrenFirstTicked
                    
                    // Auto-collapse when item becomes checked
                    if wasUnchecked && items[i].isFirstTicked {
                        items[i].isExpanded = false
                    }
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
        print("\n🔄 RESET CHECKLIST - \(checklist.title)")
        print("  📊 Items before reset: \(checklist.items.count)")
        print("  ✅ Completion before: \(checklist.completionPercentage)%")
        
        checklist.reset()
        
        print("  📊 Items after reset: \(checklist.items.count)")
        print("  ✅ Completion after: \(checklist.completionPercentage)%")
        
        saveChanges()
    }
    
    func saveChanges(skipUndoState: Bool = false) {
        print("\n💾 SAVE CHANGES - Checklist: \(checklist.title)")
        checklist.modifiedDate = Date()
        
        if let index = mainViewModel.appData.checklists.firstIndex(where: { $0.id == checklistID }) {
            print("  📍 Found at index \(index) in mainViewModel.appData")
            print("  📊 Saving \(checklist.items.count) items")
            
            // Show what we're saving
            for (i, item) in checklist.items.enumerated() {
                print("    [\(i)] \(item.title) - ticked: \(item.isFirstTicked)")
            }
            
            mainViewModel.appData.checklists[index] = checklist
            mainViewModel.saveData()
            
            // Verify save
            print("  ✅ Saved to mainViewModel.appData")
            print("  📊 MainViewModel now has \(mainViewModel.appData.checklists[index].items.count) items for this checklist")
        } else {
            print("  ❌ ERROR: Checklist not found in mainViewModel.appData!")
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    func toggleMultiSelect() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedItems.removeAll()
        }
    }
    
    func toggleItemSelection(_ itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
    }
    
    func moveSelectedItems(to category: String) {
        saveUndoState(description: "Move items")
        
        var itemsToMove: [ChecklistItem] = []
        
        // Collect items to move
        func collectItems(_ items: [ChecklistItem]) {
            for item in items {
                if selectedItems.contains(item.id) {
                    itemsToMove.append(item)
                }
                collectItems(item.children)
            }
        }
        collectItems(checklist.items)
        
        // Remove items from their current locations
        for itemToMove in itemsToMove {
            deleteItem(itemToMove, skipUndo: true)
        }
        
        // Add items to new category
        for var item in itemsToMove {
            item.category = category
            item.parentID = nil
            item.nestingLevel = 0
            checklist.items.append(item)
        }
        
        selectedItems.removeAll()
        isMultiSelectMode = false
        propagateTickStates()
        saveChanges()
    }
    
    func addItem(title: String, category: String? = nil, parent: ChecklistItem? = nil, itemType: ItemType = .packing, finalPass: Bool = false) {
        print("\n➕ ADD ITEM - Title: \(title), Parent: \(parent?.title ?? "root")")
        print("  📊 Items before: \(checklist.items.count)")
        
        let nestingLevel = (parent?.nestingLevel ?? -1) + 1
        let categoryToUse = category ?? checklist.lastUsedCategory
        let newItem = ChecklistItem(
            title: title,
            category: categoryToUse,
            parentID: parent?.id,
            nestingLevel: nestingLevel,
            itemType: itemType,
            finalPass: finalPass
        )
        
        // Update last used category
        checklist.lastUsedCategory = categoryToUse
        print("  🆕 Creating item with ID: \(newItem.id)")
        
        if let parent = parent {
            updateItem(parent) { updatedParent in
                updatedParent.children.append(newItem)
                if updatedParent.isSecondTicked == nil {
                    updatedParent.isSecondTicked = false
                }
            }
        } else {
            checklist.items.append(newItem)
            print("  🌳 Added to root level")
        }
        
        print("  📊 Items after: \(checklist.items.count)")
        propagateTickStates()
        saveChanges()
    }
    
    func deleteItem(_ item: ChecklistItem, skipUndo: Bool = false) {
        if !skipUndo {
            saveUndoState(description: "Delete item")
        }
        
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
    
    func updateItemTitle(_ item: ChecklistItem, newTitle: String) {
        
        updateItem(item) { updatedItem in
            updatedItem.title = newTitle
        }
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
    
    deinit {
        // Can't access main actor properties in deinit
        print("\n🔴 ChecklistViewModel DEINIT")
        cancellables.removeAll()
    }
}