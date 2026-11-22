import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let viewModel: ChecklistViewModel
    var isMultiSelect: Bool = false
    var isSelected: Bool = false
    var onStagePrompt: ((ChecklistItem) -> Void)? = nil
    
    @State private var isHovered = false
    @State private var showingAddSubItem = false
    @State private var newSubItemTitle = ""
    @State private var showingEditItem = false
    @State private var editedTitle = ""
    @State private var newItemCategory = ""
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: Theme.smallSpacing) {
                // Multi-select checkbox
                if isMultiSelect {
                    Button(action: {
                        viewModel.toggleItemSelection(item.id)
                    }) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, Theme.smallSpacing)
                }
                
                // Expand/collapse for parent items
                if item.hasChildren {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleExpanded(for: item)
                        }
                    }) {
                        Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Item type indicator
                if item.itemType == .todo {
                    Image(systemName: "checklist")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                        .padding(.trailing, 4)
                }
                
                // Final pass indicator
                if item.finalPass {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.warning)
                        .padding(.trailing, 4)
                }
                
                Text(item.title)
                    .font(Typography.body)
                    .foregroundColor(Theme.textPrimary)
                    .strikethrough(item.isComplete, color: Theme.textSecondary)
                    .opacity(item.isComplete ? 0.6 : 1)
                
                Spacer()
                
                if !isMultiSelect {
                    if item.itemType == .packing {
                        PackingCheckboxes(
                            item: item,
                            viewModel: viewModel,
                            onStagePrompt: onStagePrompt
                        )
                    } else {
                        TodoCheckbox(
                            item: item,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.smallSpacing)
            .padding(.leading, CGFloat(item.nestingLevel) * 32)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .fill(isHovered || isSelected ? Theme.divider.opacity(0.5) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if !isMultiSelect {
                contextMenuContent
            }
        }
        .onLongPressGesture {
            if !isMultiSelect {
                viewModel.toggleMultiSelect()
                viewModel.toggleItemSelection(item.id)
            }
        }
        .sheet(isPresented: $showingAddSubItem) {
            AddItemView(
                title: $newSubItemTitle,
                selectedCategory: $newItemCategory,
                itemType: .constant(.packing),
                isFinalPass: .constant(false),
                shouldPropagate: .constant(false),
                checklist: viewModel.checklist,
                appData: viewModel.mainViewModel.appData
            ) {
                if !newSubItemTitle.isEmpty {
                    viewModel.addItem(
                        title: newSubItemTitle,
                        category: newItemCategory.isEmpty ? item.category : newItemCategory,
                        parent: item
                    )
                    newSubItemTitle = ""
                }
            }
            .onAppear {
                newItemCategory = item.category
            }
        }
        .sheet(isPresented: $showingEditItem) {
            EditItemSheet(
                title: $editedTitle,
                itemTitle: item.title,
                onSave: {
                    if !editedTitle.isEmpty && editedTitle != item.title {
                        viewModel.updateItemTitle(item, newTitle: editedTitle)
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            viewModel.toggleMultiSelect()
            viewModel.toggleItemSelection(item.id)
        } label: {
            Label("Select Items", systemImage: "checkmark.circle")
        }
        
        Button {
            showingAddSubItem = true
        } label: {
            Label("Add Sub-item", systemImage: "plus.circle")
        }
        
        Button {
            editedTitle = item.title
            showingEditItem = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        if item.itemType == .packing {
            Button {
                var updatedItem = item
                updatedItem.itemType = .todo
                updatedItem.setStage(item.isComplete ? 2 : 0)
                viewModel.updateItem(updatedItem)
            } label: {
                Label("Convert to To-Do", systemImage: "checklist")
            }
        }
        
        Button {
            var updatedItem = item
            updatedItem.finalPass.toggle()
            viewModel.updateItem(updatedItem)
        } label: {
            Label(item.finalPass ? "Remove from Final Pass" : "Add to Final Pass", 
                  systemImage: item.finalPass ? "flag.slash" : "flag")
        }
        
        Divider()
        
        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteItem(item)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct PackingCheckboxes: View {
    let item: ChecklistItem
    let viewModel: ChecklistViewModel
    let onStagePrompt: ((ChecklistItem) -> Void)?
    
    var body: some View {
        HStack(spacing: Theme.smallSpacing) {
            // Packed checkbox
            CustomCheckbox(
                isChecked: item.stage >= 1,
                action: {
                    viewModel.toggleStage(for: item, targetStage: 1)
                }
            )
            
            // Loaded checkbox (second tick)
            CustomCheckbox(
                isChecked: item.stage == 2,
                action: {
                    if item.stage < 1 {
                        // Not packed yet, show prompt
                        onStagePrompt?(item)
                    } else {
                        viewModel.toggleStage(for: item, targetStage: 2)
                    }
                }
            )
        }
    }
}

struct TodoCheckbox: View {
    let item: ChecklistItem
    let viewModel: ChecklistViewModel
    
    var body: some View {
        CustomCheckbox(
            isChecked: item.isComplete,
            action: {
                viewModel.toggleStage(for: item, targetStage: 2)
            }
        )
    }
}

struct EditItemSheet: View {
    @Binding var title: String
    let itemTitle: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(title: Binding<String>, itemTitle: String, onSave: @escaping () -> Void) {
        self._title = title
        self.itemTitle = itemTitle
        self.onSave = onSave
        if title.wrappedValue.isEmpty {
            title.wrappedValue = itemTitle
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.spacing) {
                TextField("Item title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Typography.body)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}