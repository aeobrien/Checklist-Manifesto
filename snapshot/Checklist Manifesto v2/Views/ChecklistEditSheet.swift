import SwiftUI

struct ChecklistEditSheet: View {
    @ObservedObject var viewModel: MainViewModel
    let checklist: Checklist
    @State private var title: String
    @State private var selectedTags: Set<String>
    @State private var newTag = ""
    @State private var autoResetEnabled: Bool
    @State private var resetDays: Int
    @State private var showingNewTag = false
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: MainViewModel, checklist: Checklist) {
        self.viewModel = viewModel
        self.checklist = checklist
        _title = State(initialValue: checklist.title)
        _selectedTags = State(initialValue: Set(checklist.tags))
        _autoResetEnabled = State(initialValue: checklist.autoResetEnabled)
        _resetDays = State(initialValue: checklist.resetAfterDays ?? 7)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Checklist Title", text: $title)
                        .font(Typography.body)
                }
                
                Section("Tags") {
                    if !viewModel.appData.allTags.isEmpty {
                        ForEach(viewModel.appData.allTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .font(Typography.body)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                        }
                    }
                    
                    Button(action: { showingNewTag = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Tag")
                        }
                        .foregroundColor(Theme.accent)
                    }
                }
                
                Section("Auto-Reset") {
                    Toggle("Enable Auto-Reset", isOn: $autoResetEnabled)
                        .font(Typography.body)
                    
                    if autoResetEnabled {
                        Stepper("Reset after \(resetDays) days", value: $resetDays, in: 1...30)
                            .font(Typography.body)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        viewModel.deleteChecklist(checklist)
                        dismiss()
                    }) {
                        Text("Delete Checklist")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingNewTag) {
            NewTagSheet(tag: $newTag) {
                if !newTag.isEmpty {
                    selectedTags.insert(newTag)
                    newTag = ""
                }
            }
        }
    }
    
    private func saveChanges() {
        if let index = viewModel.appData.checklists.firstIndex(where: { $0.id == checklist.id }) {
            viewModel.appData.checklists[index].title = title
            viewModel.appData.checklists[index].tags = Array(selectedTags)
            viewModel.appData.checklists[index].autoResetEnabled = autoResetEnabled
            viewModel.appData.checklists[index].resetAfterDays = autoResetEnabled ? resetDays : nil
            viewModel.appData.checklists[index].modifiedDate = Date()
            viewModel.saveData()
        }
    }
}