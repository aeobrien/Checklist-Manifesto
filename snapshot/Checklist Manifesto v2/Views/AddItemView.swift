import SwiftUI

struct AddItemView: View {
    @Binding var title: String
    @Binding var selectedCategory: String
    @Binding var itemType: ItemType
    @Binding var isFinalPass: Bool
    @Binding var shouldPropagate: Bool
    
    let checklist: Checklist
    let appData: AppData
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingSuggestions = true
    @State private var isCreatingNewCategory = false
    @State private var newCategoryName = ""
    @State private var propagationMode: PropagationMode = .none
    @State private var selectedListType: ListType = .other
    @State private var selectedLists: Set<UUID> = []
    @FocusState private var isTextFieldFocused: Bool
    
    enum PropagationMode {
        case none
        case byListType
        case manual
    }
    
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
    
    var existingCategories: [String] {
        checklist.categories
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    // Item Title
                    VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                        Text("Item Name")
                            .font(Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        TextField("Enter item name", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(Typography.body)
                            .focused($isTextFieldFocused)
                            .onChange(of: searchText) {
                                title = searchText
                                showingSuggestions = true
                            }
                            .onSubmit {
                                if !isCreatingNewCategory {
                                    isTextFieldFocused = false
                                }
                            }
                    }
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                        Text("Category")
                            .font(Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        if isCreatingNewCategory {
                            HStack {
                                TextField("New category name", text: $newCategoryName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(Typography.body)
                                    .onSubmit {
                                        if !newCategoryName.isEmpty {
                                            selectedCategory = newCategoryName
                                            isCreatingNewCategory = false
                                        }
                                    }
                                
                                Button("Cancel") {
                                    isCreatingNewCategory = false
                                    newCategoryName = ""
                                }
                                .font(Typography.footnote)
                                .foregroundColor(Theme.accent)
                            }
                        } else {
                            Menu {
                                ForEach(existingCategories, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack {
                                            Text(category)
                                            if selectedCategory == category {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    isCreatingNewCategory = true
                                }) {
                                    Label("New Category…", systemImage: "plus.circle")
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory)
                                        .font(Typography.body)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                        .stroke(Theme.divider, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Item Type Selection
                    VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                        Text("Item Type")
                            .font(Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("Item Type", selection: $itemType) {
                            Text("Packing Item").tag(ItemType.packing)
                            Text("To-Do").tag(ItemType.todo)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Final Pass Toggle
                    Toggle(isOn: $isFinalPass) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Final Pass Item")
                                .font(Typography.body)
                                .foregroundColor(Theme.textPrimary)
                            Text("Check this item during final review")
                                .font(Typography.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.accent)
                    
                    Divider()
                    
                    // Propagation Options
                    VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                        Text("Add to Other Lists")
                            .font(Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("Propagation Mode", selection: $propagationMode) {
                            Text("This List Only").tag(PropagationMode.none)
                            Text("By List Type").tag(PropagationMode.byListType)
                            Text("Select Lists").tag(PropagationMode.manual)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        if propagationMode == .byListType {
                            Picker("List Type", selection: $selectedListType) {
                                ForEach(ListType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            let matchingLists = appData.checklists.filter { $0.listType == selectedListType && $0.id != checklist.id }
                            if !matchingLists.isEmpty {
                                Text("\(matchingLists.count) list(s) will receive this item")
                                    .font(Typography.caption)
                                    .foregroundColor(Theme.textSecondary)
                            } else {
                                Text("No other lists of this type")
                                    .font(Typography.caption)
                                    .foregroundColor(Theme.warning)
                            }
                        } else if propagationMode == .manual {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(appData.checklists.filter { $0.id != checklist.id }, id: \.id) { list in
                                        Button(action: {
                                            if selectedLists.contains(list.id) {
                                                selectedLists.remove(list.id)
                                            } else {
                                                selectedLists.insert(list.id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: selectedLists.contains(list.id) ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(Theme.accent)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(list.title)
                                                        .font(Typography.body)
                                                        .foregroundColor(Theme.textPrimary)
                                                    Text(list.listType.rawValue)
                                                        .font(Typography.caption)
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, Theme.spacing)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Divider()
                                            .padding(.leading, Theme.spacing + 24)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                    .stroke(Theme.divider, lineWidth: 1)
                            )
                            
                            if !selectedLists.isEmpty {
                                Text("\(selectedLists.count) list(s) selected")
                                    .font(Typography.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    // Previously Used Items Suggestions
                    if showingSuggestions && !filteredSuggestions.isEmpty && searchText.count > 1 {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Previously used items")
                                .font(Typography.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, Theme.spacing)
                                .padding(.vertical, Theme.smallSpacing)
                            
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(filteredSuggestions.prefix(5), id: \.self) { suggestion in
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
                                                Image(systemName: "arrow.right.circle")
                                                    .foregroundColor(Theme.accent)
                                            }
                                            .padding(.horizontal, Theme.spacing)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if suggestion != filteredSuggestions.prefix(5).last {
                                            Divider()
                                                .padding(.leading, Theme.spacing)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                .stroke(Theme.divider, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding()
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
                        shouldPropagate = propagationMode != .none
                        onAdd()
                        dismiss()
                    }
                    .disabled(title.isEmpty || (isCreatingNewCategory && newCategoryName.isEmpty))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }
}

extension AddItemView {
    func getListsForPropagation() -> [UUID] {
        switch propagationMode {
        case .none:
            return []
        case .byListType:
            return appData.checklists
                .filter { $0.listType == selectedListType && $0.id != checklist.id }
                .map { $0.id }
        case .manual:
            return Array(selectedLists)
        }
    }
}