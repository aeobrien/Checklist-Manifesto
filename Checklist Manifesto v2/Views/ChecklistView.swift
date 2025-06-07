import SwiftUI
import UIKit

struct ChecklistView: View {
    @StateObject private var viewModel: ChecklistViewModel
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var showingResetConfirmation = false
    @State private var showingOrganizeMode = false
    @State private var itemToMove: ChecklistItem?
    @State private var showingNotesEditor = false
    @State private var itemToEdit: ChecklistItem?
    @State private var editedItemTitle = ""
    @Environment(\.dismiss) private var dismiss
    
    init(checklist: Checklist, appData: AppData) {
        _viewModel = StateObject(wrappedValue: ChecklistViewModel(checklist: checklist, appData: appData))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                VStack(spacing: 2) {
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
                    } else {
                        ForEach(viewModel.flattenedItems(), id: \.item.id) { flatItem in
                            if flatItem.isVisible {
                                ChecklistItemRow(
                                    item: flatItem.item,
                                    viewModel: viewModel,
                                    isOrganizing: showingOrganizeMode,
                                    onMoveItem: showingOrganizeMode ? { item in
                                        itemToMove = item
                                    } : nil
                                )
                                .contextMenu {
                                    Button {
                                        editedItemTitle = flatItem.item.title
                                        itemToEdit = flatItem.item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            viewModel.deleteItem(flatItem.item)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale)
                                ))
                            }
                        }
                        
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: Menu {
                Button(action: { showingOrganizeMode.toggle() }) {
                    Label(showingOrganizeMode ? "Done Organizing" : "Organize Items", systemImage: "arrow.up.arrow.down")
                }
                
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
                viewModel.resetChecklist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will uncheck all items in the checklist.")
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
                            .onChange(of: viewModel.checklist.notes) { _ in
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
            AddItemSheet(title: $newItemTitle, appData: viewModel.appData) {
                if !newItemTitle.isEmpty {
                    viewModel.addItem(title: newItemTitle)
                    newItemTitle = ""
                }
            }
        }
        .sheet(item: $itemToMove) { item in
            MoveItemSheet(item: item, viewModel: viewModel)
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
                        .onChange(of: searchText) { newValue in
                            title = newValue
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