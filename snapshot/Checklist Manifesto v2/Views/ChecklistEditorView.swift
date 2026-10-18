import SwiftUI

struct ChecklistEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var title = ""
    @State private var selectedTags: Set<String> = []
    @State private var newTag = ""
    @State private var autoResetEnabled = false
    @State private var resetDays = 7
    @State private var showingNewTag = false
    @Environment(\.dismiss) private var dismiss
    
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
            }
            .navigationTitle("New Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        viewModel.createChecklist(
                            title: title,
                            tags: Array(selectedTags),
                            autoReset: autoResetEnabled,
                            resetDays: autoResetEnabled ? resetDays : nil
                        )
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
}

struct NewTagSheet: View {
    @Binding var tag: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.spacing) {
                TextField("Tag name", text: $tag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Typography.body)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Tag")
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
                    .disabled(tag.isEmpty)
                }
            }
        }
    }
}