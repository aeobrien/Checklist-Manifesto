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
            let decodedChecklist = try JSONDecoder().decode(Checklist.self, from: data)
            
            // Fix missing children arrays recursively
            func fixItems(_ items: [ChecklistItem]) -> [ChecklistItem] {
                return items.map { item in
                    var fixedItem = item
                    if !item.hasChildren && item.children.isEmpty {
                        // Leaf nodes should have empty children array
                        fixedItem.children = []
                    } else if item.hasChildren {
                        // Recursively fix children
                        fixedItem.children = fixItems(item.children)
                    }
                    return fixedItem
                }
            }
            
            var checklist = Checklist(
                id: UUID(),
                title: decodedChecklist.title,
                items: fixItems(decodedChecklist.items),
                tags: decodedChecklist.tags,
                autoResetEnabled: decodedChecklist.autoResetEnabled,
                resetAfterDays: decodedChecklist.resetAfterDays,
                notes: decodedChecklist.notes
            )
            checklist.reset()
            
            viewModel.appData.checklists.append(checklist)
            viewModel.saveData()
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