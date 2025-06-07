import SwiftUI

struct TagsView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingCreateChecklist = false
    @State private var showingImport = false
    @State private var checklistToEdit: Checklist?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if !viewModel.appData.allTags.isEmpty {
                        ForEach(viewModel.appData.allTags, id: \.self) { tag in
                            TagSection(
                                tag: tag,
                                checklists: viewModel.appData.checklists(forTag: tag),
                                viewModel: viewModel,
                                checklistToEdit: $checklistToEdit
                            )
                        }
                    }
                    
                    let untaggedChecklists = viewModel.appData.checklistsWithoutTags()
                    if !untaggedChecklists.isEmpty {
                        TagSection(
                            tag: "Untagged",
                            checklists: untaggedChecklists,
                            viewModel: viewModel,
                            checklistToEdit: $checklistToEdit
                        )
                    }
                    
                    if viewModel.appData.checklists.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Checklists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateChecklist = true }) {
                            Label("New Checklist", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingImport = true }) {
                            Label("Import from JSON", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateChecklist) {
            ChecklistEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingImport) {
            ImportView(viewModel: viewModel)
        }
        .sheet(item: $checklistToEdit) { checklist in
            ChecklistEditSheet(viewModel: viewModel, checklist: checklist)
        }
    }
}

struct TagSection: View {
    let tag: String
    let checklists: [Checklist]
    let viewModel: MainViewModel
    @Binding var checklistToEdit: Checklist?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text(tag)
                .font(Typography.title2)
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 4)
            
            ForEach(checklists) { checklist in
                NavigationLink(destination: ChecklistView(checklist: checklist, appData: viewModel.appData)) {
                    ChecklistCard(
                        checklist: checklist,
                        viewModel: viewModel,
                        onEdit: { checklistToEdit = checklist }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.bottom, Theme.spacing)
    }
}

struct ChecklistCard: View {
    let checklist: Checklist
    let viewModel: MainViewModel
    let onEdit: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checklist.title)
                            .font(Typography.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        HStack(spacing: 12) {
                            Label("\(checklist.totalItemCount) items", systemImage: "checklist")
                                .font(Typography.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            if checklist.autoResetEnabled {
                                Label("Auto-reset", systemImage: "arrow.clockwise")
                                    .font(Typography.caption)
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(checklist.completionPercentage))%")
                            .font(Typography.headline)
                            .foregroundColor(checklist.isCompleted ? Theme.success : Theme.textPrimary)
                        
                        if checklist.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.success)
                                .font(.system(size: 16))
                        }
                    }
                }
                
                ProgressView(value: checklist.completionPercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.success))
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }
            .padding(Theme.spacing)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.surface)
                    .shadow(
                        color: isHovered ? Theme.shadowColor.opacity(0.15) : Theme.shadowColor,
                        radius: isHovered ? 12 : Theme.shadowRadius,
                        y: isHovered ? 4 : Theme.shadowY
                    )
            )
            .overlay(
                HStack {
                    Spacer()
                    
                    if isHovered {
                        Menu {
                            Button(action: onEdit) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                viewModel.duplicateChecklist(checklist)
                            }) {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                viewModel.deleteChecklist(checklist)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Theme.surface))
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .padding(8)
                    }
                }
                , alignment: .topTrailing
            )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: {
                viewModel.duplicateChecklist(checklist)
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.deleteChecklist(checklist)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(Theme.divider)
            
            Text("No Checklists Yet")
                .font(Typography.title2)
                .foregroundColor(Theme.textPrimary)
            
            Text("Create your first checklist to get started")
                .font(Typography.body)
                .foregroundColor(Theme.textSecondary)
        }
    }
}