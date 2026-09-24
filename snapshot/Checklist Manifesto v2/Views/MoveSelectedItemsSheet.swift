import SwiftUI

struct MoveSelectedItemsSheet: View {
    @ObservedObject var viewModel: ChecklistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = ""
    @State private var isCreatingNewCategory = false
    @State private var newCategoryName = ""
    
    var existingCategories: [String] {
        viewModel.checklist.categories
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.spacing) {
                Text("Move \(viewModel.selectedItems.count) item(s) to:")
                    .font(Typography.body)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top)
                
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
                    .padding(.horizontal)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(existingCategories, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Text(category)
                                            .font(Typography.body)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Theme.accent)
                                        }
                                    }
                                    .padding(.horizontal, Theme.spacing)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, Theme.spacing)
                            }
                            
                            Button(action: {
                                isCreatingNewCategory = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(Theme.accent)
                                    Text("New Category…")
                                        .font(Typography.body)
                                        .foregroundColor(Theme.accent)
                                    Spacer()
                                }
                                .padding(.horizontal, Theme.spacing)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxHeight: 400)
                }
                
                Spacer()
            }
            .navigationTitle("Move Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        let categoryToUse = isCreatingNewCategory ? newCategoryName : selectedCategory
                        if !categoryToUse.isEmpty {
                            viewModel.moveSelectedItems(to: categoryToUse)
                            dismiss()
                        }
                    }
                    .disabled(selectedCategory.isEmpty && (!isCreatingNewCategory || newCategoryName.isEmpty))
                }
            }
        }
        .onAppear {
            if !existingCategories.isEmpty {
                selectedCategory = existingCategories[0]
            }
        }
    }
}