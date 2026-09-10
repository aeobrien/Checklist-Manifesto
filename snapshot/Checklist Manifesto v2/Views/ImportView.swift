import SwiftUI
import UIKit

struct ImportView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var jsonInput = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    let exampleJSON = """
{
  "title": "Sample Checklist",
  "tags": ["Example", "Demo"],
  "autoResetEnabled": true,
  "resetAfterDays": 7,
  "notes": "This is a sample checklist",
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Main Category",
      "nestingLevel": 0,
      "isFirstTicked": false,
      "isSecondTicked": false,
      "children": [
        {
          "id": "550e8400-e29b-41d4-a716-446655440001",
          "title": "Sub-item 1",
          "nestingLevel": 1,
          "isFirstTicked": false,
          "children": []
        }
      ]
    }
  ]
}
"""
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.spacing) {
                Text("Paste JSON data below to import a checklist")
                    .font(Typography.body)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $jsonInput)
                    .font(Typography.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
                
                Button(action: pasteFromClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(Typography.body)
                    .foregroundColor(Theme.accent)
                }
                
                Divider()
                    .padding(.vertical, Theme.spacing)
                
                VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                    HStack {
                        Text("Example JSON format:")
                            .font(Typography.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Spacer()
                        
                        Button(action: copyExampleToClipboard) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                Text("Copy")
                                    .font(Typography.caption)
                            }
                            .foregroundColor(Theme.accent)
                        }
                    }
                    
                    ScrollView {
                        Text(exampleJSON)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.smallSpacing)
                            .textSelection(.enabled)
                    }
                    .frame(height: 200)
                    .background(Theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
                }
            }
            .padding()
            .navigationTitle("Import Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importChecklist()
                    }
                    .disabled(jsonInput.isEmpty)
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            jsonInput = string
        }
    }
    
    private func copyExampleToClipboard() {
        UIPasteboard.general.string = exampleJSON
    }
    
    private func importChecklist() {
        guard let data = jsonInput.data(using: .utf8) else {
            showError("Invalid text data")
            return
        }

        do {
            print("\n📥 IMPORT JSON - Starting import process")
            print("  📏 JSON size: \(data.count) bytes")

            let decodedChecklist = try JSONDecoder().decode(Checklist.self, from: data)
            print("  ✅ Successfully decoded checklist: \(decodedChecklist.title)")
            print("  📊 Top-level items: \(decodedChecklist.items.count)")

            // Debug: Print decoded structure
            func debugPrintItems(_ items: [ChecklistItem], indent: String = "") {
                for item in items {
                    print("\(indent)- \(item.title) [category: \(item.category), level: \(item.nestingLevel), children: \(item.children.count)]")
                    if !item.children.isEmpty {
                        debugPrintItems(item.children, indent: indent + "  ")
                    }
                }
            }
            print("  📋 Decoded structure:")
            debugPrintItems(decodedChecklist.items, indent: "    ")

            // Fix missing children arrays recursively and ensure categories are set
            func fixItems(_ items: [ChecklistItem], parentCategory: String? = nil) -> [ChecklistItem] {
                return items.map { item in
                    var fixedItem = item

                    // If item is a top-level category (nestingLevel 0), use its title as the category
                    if item.nestingLevel == 0 {
                        fixedItem.category = item.title
                    } else if let parentCat = parentCategory {
                        // For nested items, inherit the parent's category
                        fixedItem.category = parentCat
                    }

                    if !item.hasChildren && item.children.isEmpty {
                        // Leaf nodes should have empty children array
                        fixedItem.children = []
                    } else if item.hasChildren {
                        // Recursively fix children with the current category
                        fixedItem.children = fixItems(item.children, parentCategory: fixedItem.category)
                    }
                    return fixedItem
                }
            }

            let fixedItems = fixItems(decodedChecklist.items)
            print("  🔧 Fixed items structure:")
            debugPrintItems(fixedItems, indent: "    ")

            // Convert hierarchical structure to flat structure
            // The app expects items at the root level with category field, not as children
            var flatItems: [ChecklistItem] = []

            for categoryItem in fixedItems {
                if categoryItem.nestingLevel == 0 && !categoryItem.children.isEmpty {
                    // This is a category with children - extract the children
                    // The children already have the correct category set from fixItems
                    for child in categoryItem.children {
                        var flatChild = child
                        flatChild.parentID = nil  // No parent in flat structure
                        flatChild.nestingLevel = 0  // Root level in flat structure
                        flatItems.append(flatChild)
                    }
                } else {
                    // This is a regular item or an empty category, add it as is
                    flatItems.append(categoryItem)
                }
            }

            print("  📋 Converted to flat structure: \(flatItems.count) items")
            for item in flatItems {
                print("    - \(item.title) [category: \(item.category)]")
            }

            var checklist = Checklist(
                id: UUID(),
                title: decodedChecklist.title,
                items: flatItems,
                tags: decodedChecklist.tags,
                autoResetEnabled: decodedChecklist.autoResetEnabled,
                resetAfterDays: decodedChecklist.resetAfterDays,
                notes: decodedChecklist.notes,
                listType: decodedChecklist.listType,
                lastUsedCategory: decodedChecklist.lastUsedCategory
            )

            print("  🆕 Created checklist with ID: \(checklist.id)")
            print("  📊 Final item count: \(checklist.items.count)")
            print("  📊 Total items (including nested): \(checklist.totalItemCount)")

            checklist.reset()
            print("  🔄 Reset checklist - completion: \(checklist.completionPercentage)%")

            viewModel.appData.checklists.append(checklist)
            print("  ➕ Added to appData - now have \(viewModel.appData.checklists.count) checklists")

            viewModel.saveData()
            print("  💾 Saved to disk")

            dismiss()
        } catch DecodingError.keyNotFound(let key, let context) {
            showError("Missing required field: \(key.stringValue)\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
        } catch DecodingError.typeMismatch(let type, let context) {
            showError("Type mismatch for \(type)\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
        } catch {
            showError("Invalid JSON format: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}