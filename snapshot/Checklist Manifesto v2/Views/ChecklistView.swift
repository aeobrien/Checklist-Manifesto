import SwiftUI
import UIKit

struct ChecklistView: View {
    @StateObject private var viewModel: ChecklistViewModel
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemCategory = ""
    @State private var newItemType: ItemType = .packing
    @State private var newItemFinalPass = false
    @State private var shouldPropagate = false
    @State private var showingResetConfirmation = false
    @State private var showingNotesEditor = false
    @State private var itemToEdit: ChecklistItem?
    @State private var editedItemTitle = ""
    @State private var showingMoveSheet = false
    @State private var showingStagePrompt = false
    @State private var stagePromptItem: ChecklistItem?
    @State private var hideCheckedItems = false
    @Environment(\.dismiss) private var dismiss
    
    init(checklistID: UUID, mainViewModel: MainViewModel) {
        print("\n🔵 ChecklistView INIT - ID: \(checklistID)")
        print("  📊 MainViewModel has \(mainViewModel.appData.checklists.count) checklists")
        
        // Find the checklist by ID from mainViewModel
        if let checklist = mainViewModel.appData.checklists.first(where: { $0.id == checklistID }) {
            print("  ✅ Found checklist: \(checklist.title) with \(checklist.items.count) items")
            _viewModel = StateObject(wrappedValue: ChecklistViewModel(checklist: checklist, mainViewModel: mainViewModel))
        } else {
            print("  ❌ Checklist not found! Creating fallback")
            // Fallback in case checklist isn't found (shouldn't happen)
            _viewModel = StateObject(wrappedValue: ChecklistViewModel(checklist: Checklist(title: "Unknown"), mainViewModel: mainViewModel))
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 2) {
                        // Final Pass Section (if any items marked)
                        if hasFinalPassItems {
                            finalPassSection
                                .padding(.top, Theme.spacing)
                        }
                        
                        // Categories Section
                        ForEach(categoriesWithStatus, id: \.category) { categoryData in
                            categorySection(for: categoryData)
                        }
                        
                        if viewModel.checklist.items.isEmpty {
                            VStack(spacing: Theme.spacing) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.divider)
                                    .padding(.top, 60)

                                Text("No items yet")
                                    .font(Typography.title3)
                                    .foregroundColor(Theme.textSecondary)

                                Text("Add your first item to get started")
                                    .font(Typography.body)
                                    .foregroundColor(Theme.textSecondary)

                                addItemButton
                                    .padding(.top, Theme.spacing)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacing)
                        } else if hideCheckedItems && categoriesWithStatus.isEmpty && !hasFinalPassItems {
                            VStack(spacing: Theme.spacing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.success)
                                    .padding(.top, 60)

                                Text("All items are checked!")
                                    .font(Typography.title3)
                                    .foregroundColor(Theme.textSecondary)

                                Text("Toggle the visibility switch to see completed items")
                                    .font(Typography.body)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacing)
                        } else {
                            addItemButton
                                .padding(.top, Theme.spacing)
                        }
                    }
                    .padding(.vertical, Theme.spacing)
                }
                .background(Theme.background)
                
                if viewModel.checklist.isCompleted {
                    completionBanner
                }
            }
            
            // Multi-select toolbar
            if viewModel.isMultiSelectMode {
                multiSelectToolbar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            leading: viewModel.isMultiSelectMode ? Button("Cancel") {
                viewModel.toggleMultiSelect()
            } : nil,
            trailing: Menu {
                if !viewModel.isMultiSelectMode {
                    Button(action: { viewModel.toggleMultiSelect() }) {
                        Label("Select Items", systemImage: "checkmark.circle")
                    }
                }
                
                Button(action: { viewModel.undo() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.undoStack.isEmpty)
                
                Button(action: { viewModel.redo() }) {
                    Label("Redo", systemImage: "arrow.uturn.forward") 
                }
                .disabled(viewModel.redoStack.isEmpty)
                
                Divider()
                
                Button(action: { showingResetConfirmation = true }) {
                    Label("Reset Checklist", systemImage: "arrow.counterclockwise")
                }
                
                Button(action: exportChecklist) {
                    Label("Export as JSON", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.accent)
            }
        )
        .confirmationDialog("Reset Checklist?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                print("\n🔄 User requested reset for: \(viewModel.checklist.title)")
                viewModel.resetChecklist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will uncheck all items in the checklist.")
        }
        .onAppear {
            print("\n👀 ChecklistView appeared - \(viewModel.checklist.title)")
            print("  📊 Current items: \(viewModel.checklist.items.count)")
            // Don't refresh on appear - it overwrites local changes
            // viewModel.refreshChecklistFromAppData()
        }
        .onDisappear {
            print("\n👋 ChecklistView disappearing - \(viewModel.checklist.title)")
            print("  📊 Final items: \(viewModel.checklist.items.count)")
            // Don't save on disappear - we save after each change
            // viewModel.saveChanges()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text(viewModel.checklist.title)
                .font(Typography.largeTitle)
                .foregroundColor(Theme.textPrimary)
            
            HStack {
                if !viewModel.checklist.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(viewModel.checklist.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(viewModel.checklist.completionPercentage))% Complete")
                        .font(Typography.footnote)
                        .foregroundColor(Theme.textSecondary)
                    
                    ProgressView(value: viewModel.checklist.completionPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.success))
                        .frame(width: 120)
                }
            }
            
            if let lastCompleted = viewModel.checklist.lastCompletedDate {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Theme.success)
                        .font(.system(size: 14))
                    Text("Last completed \(lastCompleted.formatted(.relative(presentation: .named)))")
                        .font(Typography.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            if viewModel.checklist.autoResetEnabled,
               let days = viewModel.checklist.resetAfterDays {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Theme.secondary)
                        .font(.system(size: 14))
                    Text("Auto-resets \(days) days after completion")
                        .font(Typography.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Toggle for hiding checked items
            HStack {
                Toggle(isOn: $hideCheckedItems) {
                    HStack(spacing: 6) {
                        Image(systemName: hideCheckedItems ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                        Text(hideCheckedItems ? "Hiding checked items" : "Showing all items")
                            .font(Typography.body)
                    }
                    .foregroundColor(Theme.textPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
            }
            .padding(.top, 4)
            
            if !viewModel.checklist.notes.isEmpty || showingNotesEditor {
                VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                    HStack {
                        Text("Notes")
                            .font(Typography.footnote)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Button(action: { showingNotesEditor.toggle() }) {
                            Text(showingNotesEditor ? "Done" : "Edit")
                                .font(Typography.footnote)
                                .foregroundColor(Theme.accent)
                        }
                    }
                    
                    if showingNotesEditor {
                        TextEditor(text: $viewModel.checklist.notes)
                            .font(Typography.body)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Theme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                    .stroke(Theme.divider, lineWidth: 1)
                            )
                            .onChange(of: viewModel.checklist.notes) {
                                viewModel.saveChanges()
                            }
                    } else {
                        Text(viewModel.checklist.notes)
                            .font(Typography.body)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .padding(Theme.spacing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .fill(Theme.background)
                )
            } else {
                Button(action: { showingNotesEditor = true }) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                        Text("Add notes")
                            .font(Typography.footnote)
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .padding(Theme.spacing)
        .background(Theme.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.divider),
            alignment: .bottom
        )
    }
    
    private var addItemButton: some View {
        Button(action: { showingAddItem = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Add Item")
                    .font(Typography.body)
            }
            .foregroundColor(Theme.accent)
            .padding(.vertical, Theme.smallSpacing)
            .padding(.horizontal, Theme.spacing)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(Theme.accent.opacity(0.1))
            )
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(
                title: $newItemTitle,
                selectedCategory: $newItemCategory,
                itemType: $newItemType,
                isFinalPass: $newItemFinalPass,
                shouldPropagate: $shouldPropagate,
                checklist: viewModel.checklist,
                appData: viewModel.mainViewModel.appData
            ) {
                if !newItemTitle.isEmpty {
                    viewModel.addItem(
                        title: newItemTitle,
                        category: newItemCategory,
                        itemType: newItemType,
                        finalPass: newItemFinalPass
                    )
                    
                    // Handle propagation if needed
                    if shouldPropagate {
                        propagateItem()
                    }
                    
                    newItemTitle = ""
                }
            }
            .onAppear {
                newItemCategory = viewModel.checklist.lastUsedCategory
            }
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveSelectedItemsSheet(viewModel: viewModel)
        }
        .alert("Mark as Packed and Loaded?", isPresented: $showingStagePrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                if let item = stagePromptItem {
                    viewModel.forceLoadedStage(for: item)
                }
            }
        } message: {
            Text("This item hasn't been marked as packed yet. Do you want to mark it as both packed and loaded?")
        }
        .sheet(item: $itemToEdit) { item in
            EditItemSheet(
                title: $editedItemTitle,
                itemTitle: item.title,
                onSave: {
                    if !editedItemTitle.isEmpty && editedItemTitle != item.title {
                        viewModel.updateItemTitle(item, newTitle: editedItemTitle)
                    }
                }
            )
        }
    }
    
    private var completionBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Checklist Complete!")
                    .font(Typography.headline)
                    .foregroundColor(.white)
                Text("All items have been checked")
                    .font(Typography.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(Theme.spacing)
        .background(Theme.success)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func exportChecklist() {
        guard let data = try? JSONEncoder().encode(viewModel.checklist),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        UIPasteboard.general.string = jsonString
    }
    
    private var hasFinalPassItems: Bool {
        if hideCheckedItems {
            return viewModel.checklist.items.contains { $0.finalPass && !$0.isFirstTicked }
        } else {
            return viewModel.checklist.items.contains { $0.finalPass }
        }
    }
    
    @ViewBuilder
    private var finalPassSection: some View {
        let finalPassItems = viewModel.checklist.items
            .filter { $0.finalPass }
            .filter { !hideCheckedItems || !$0.isFirstTicked }
        let groupedItems = Dictionary(grouping: finalPassItems, by: { $0.category })
        
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.warning)
                Text("Final Pass")
                    .font(Typography.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.smallSpacing)
            .background(Theme.warning.opacity(0.1))
            
            // Items grouped by category
            ForEach(groupedItems.keys.sorted(), id: \.self) { category in
                finalPassCategorySection(category: category, items: groupedItems[category] ?? [])
            }
        }
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.warning.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func finalPassCategorySection(category: String, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(category)
                .font(Typography.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.spacing)
                .padding(.top, Theme.smallSpacing)
            
            ForEach(items, id: \.id) { item in
                ChecklistItemRow(
                    item: item,
                    viewModel: viewModel,
                    isMultiSelect: viewModel.isMultiSelectMode,
                    isSelected: viewModel.selectedItems.contains(item.id),
                    onStagePrompt: { promptItem in
                        stagePromptItem = promptItem
                        showingStagePrompt = true
                    }
                )
            }
        }
    }
    
    private var categoriesWithStatus: [(category: String, status: CategoryStatus)] {
        let statuses = viewModel.checklist.allCategoriesComplete().categories
        let allCategories = viewModel.checklist.categories.map { category in
            (category: category, status: statuses[category] ?? .incomplete)
        }

        if hideCheckedItems {
            // Filter to only show categories that have unchecked items
            return allCategories.filter { categoryData in
                let categoryItems = viewModel.checklist.items
                    .filter { $0.category == categoryData.category && !$0.finalPass }
                // Show category if it has at least one unchecked item
                return categoryItems.contains { !$0.isFirstTicked }
            }
        } else {
            return allCategories
        }
    }
    
    private func categorySection(for categoryData: (category: String, status: CategoryStatus)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(categoryData.category)
                    .font(Typography.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                // Category status indicator
                Circle()
                    .fill(statusColor(for: categoryData.status))
                    .frame(width: 12, height: 12)
                
                // Convert to TODO button for legacy categories
                if categoryData.category.lowercased().contains("to-do") || categoryData.category.lowercased().contains("todo") {
                    Button(action: {
                        viewModel.checklist.convertCategoryToTodoType(categoryData.category)
                        viewModel.saveChanges()
                    }) {
                        Text("Convert to TODO")
                            .font(Typography.caption)
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.leading, Theme.smallSpacing)
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.smallSpacing)
            .background(Theme.surface.opacity(0.5))
            
            let categoryItems = viewModel.checklist.items
                .filter { $0.category == categoryData.category && !$0.finalPass }
                .filter { !hideCheckedItems || !$0.isFirstTicked }

            ForEach(categoryItems, id: \.id) { item in
                ChecklistItemRow(
                    item: item,
                    viewModel: viewModel,
                    isMultiSelect: viewModel.isMultiSelectMode,
                    isSelected: viewModel.selectedItems.contains(item.id),
                    onStagePrompt: { promptItem in
                        stagePromptItem = promptItem
                        showingStagePrompt = true
                    }
                )
            }
        }
        .padding(.vertical, Theme.smallSpacing)
    }
    
    private func statusColor(for status: CategoryStatus) -> Color {
        switch status {
        case .incomplete:
            return Theme.divider
        case .amber:
            return Theme.warning
        case .complete:
            return Theme.success
        }
    }
    
    private var multiSelectToolbar: some View {
        VStack {
            Spacer()
            HStack {
                Text("\(viewModel.selectedItems.count) selected")
                    .font(Typography.body)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button("Move") {
                    showingMoveSheet = true
                }
                .disabled(viewModel.selectedItems.isEmpty)
                
                Button("Delete") {
                    for itemId in viewModel.selectedItems {
                        if let item = findItem(withId: itemId) {
                            viewModel.deleteItem(item)
                        }
                    }
                    viewModel.toggleMultiSelect()
                }
                .foregroundColor(Theme.error)
                .disabled(viewModel.selectedItems.isEmpty)
            }
            .padding()
            .background(Theme.surface)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Theme.divider),
                alignment: .top
            )
        }
    }
    
    private func findItem(withId id: UUID) -> ChecklistItem? {
        func search(in items: [ChecklistItem]) -> ChecklistItem? {
            for item in items {
                if item.id == id {
                    return item
                }
                if let found = search(in: item.children) {
                    return found
                }
            }
            return nil
        }
        return search(in: viewModel.checklist.items)
    }
    
    private func propagateItem() {
        guard !newItemTitle.isEmpty else { return }
        
        // Get the AddItemView instance to retrieve propagation settings
        let targetListIds = getListsForPropagation()
        
        for listId in targetListIds {
            guard let index = viewModel.mainViewModel.appData.checklists.firstIndex(where: { $0.id == listId }) else { continue }
            
            var targetList = viewModel.mainViewModel.appData.checklists[index]
            
            // Check if category exists in target list
            let categoryExists = targetList.items.contains { $0.category == newItemCategory }
            
            // Check for duplicates
            let isDuplicate = targetList.items.contains { item in
                item.title.lowercased() == newItemTitle.lowercased() && item.category == newItemCategory
            }
            
            if !isDuplicate {
                let newItem = ChecklistItem(
                    title: newItemTitle,
                    category: newItemCategory,
                    itemType: newItemType,
                    stage: 0,
                    finalPass: newItemFinalPass
                )
                targetList.items.append(newItem)
                targetList.modifiedDate = Date()
                viewModel.mainViewModel.appData.checklists[index] = targetList
            }
        }
        
        viewModel.mainViewModel.saveData()
    }
    
    private func getListsForPropagation() -> [UUID] {
        // This would be populated from the AddItemView's propagation settings
        // For now, return empty array as we need to refactor how this is passed
        return []
    }
}

struct TagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(Typography.caption)
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.accent.opacity(0.15))
            )
    }
}

struct AddItemSheet: View {
    @Binding var title: String
    let appData: AppData
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingSuggestions = true
    @State private var isSubheading = false
    
    var filteredSuggestions: [String] {
        let allItems = getAllUsedItemTitles()
        if searchText.isEmpty {
            return allItems
        }
        return allItems.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func getAllUsedItemTitles() -> [String] {
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: Theme.spacing) {
                    TextField("Search or create new item", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.body)
                        .onChange(of: searchText) {
                            title = searchText
                            showingSuggestions = true
                        }
                    
                    Toggle("Create as subheading", isOn: $isSubheading)
                        .font(Typography.body)
                        .tint(Theme.accent)
                    
                    if showingSuggestions && !filteredSuggestions.isEmpty && !isSubheading {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Previously used items")
                                .font(Typography.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, Theme.spacing)
                                .padding(.vertical, Theme.smallSpacing)
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(filteredSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            title = suggestion
                                            searchText = suggestion
                                            showingSuggestions = false
                                        }) {
                                            HStack {
                                                Text(suggestion)
                                                    .font(Typography.body)
                                                    .foregroundColor(Theme.textPrimary)
                                                Spacer()
                                                Image(systemName: "plus.circle")
                                                    .foregroundColor(Theme.accent)
                                            }
                                            .padding(.horizontal, Theme.spacing)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Divider()
                                            .padding(.leading, Theme.spacing)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        .background(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                .stroke(Theme.divider, lineWidth: 1)
                        )
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct MoveItemSheet: View {
    let item: ChecklistItem
    @ObservedObject var viewModel: ChecklistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedParent: ChecklistItem?
    
    var availableParents: [ChecklistItem?] {
        var parents: [ChecklistItem?] = [nil] // Root level
        
        func collectParents(from items: [ChecklistItem]) {
            for checkItem in items {
                if checkItem.id != item.id && checkItem.hasChildren {
                    parents.append(checkItem)
                    collectParents(from: checkItem.children)
                }
            }
        }
        
        collectParents(from: viewModel.checklist.items)
        return parents
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Move '\(item.title)' to:") {
                    ForEach(availableParents, id: \.self?.id) { parent in
                        Button(action: {
                            selectedParent = parent
                        }) {
                            HStack {
                                if let parent = parent {
                                    Text(parent.title)
                                        .padding(.leading, CGFloat(parent.nestingLevel) * 20)
                                } else {
                                    Text("Root level")
                                        .italic()
                                }
                                Spacer()
                                if selectedParent?.id == parent?.id || (selectedParent == nil && parent == nil) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Move Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        viewModel.moveItem(item, to: selectedParent)
                        dismiss()
                    }
                }
            }
        }
    }
}