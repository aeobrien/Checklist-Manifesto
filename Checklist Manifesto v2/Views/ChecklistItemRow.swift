import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let viewModel: ChecklistViewModel
    let isOrganizing: Bool
    let onMoveItem: ((ChecklistItem) -> Void)?
    @State private var isHovered = false
    @State private var showingAddSubItem = false
    @State private var newSubItemTitle = ""
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: Theme.smallSpacing) {
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
                
                Text(item.title)
                    .font(Typography.body)
                    .foregroundColor(Theme.textPrimary)
                    .strikethrough(item.isFirstTicked, color: Theme.textSecondary)
                    .opacity(item.isFirstTicked ? 0.6 : 1)
                
                Spacer()
                
                if isOrganizing {
                    Button(action: {
                        onMoveItem?(item)
                    }) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.accent)
                            .frame(width: 32, height: 32)
                    }
                } else if isHovered {
                    Menu {
                        Button(action: {
                            showingAddSubItem = true
                        }) {
                            Label("Add Sub-item", systemImage: "plus.circle")
                        }
                        
                        Button(action: {
                            viewModel.deleteItem(item)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
                
                if !isOrganizing {
                    if item.hasChildren {
                        CheckboxPair(
                            firstChecked: item.isFirstTicked,
                            secondChecked: item.isSecondTicked ?? false,
                            onFirstTap: { viewModel.toggleFirstTick(for: item, isManual: true) },
                            onSecondTap: { viewModel.toggleSecondTick(for: item) }
                        )
                    } else {
                        HStack(spacing: Theme.smallSpacing) {
                            CustomCheckbox(
                                isChecked: item.isFirstTicked,
                                action: { viewModel.toggleFirstTick(for: item, isManual: false) }
                            )
                            Spacer()
                                .frame(width: 24)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.smallSpacing)
            .padding(.leading, CGFloat(item.nestingLevel) * 32)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .fill(isHovered ? Theme.divider.opacity(0.5) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $showingAddSubItem) {
            AddItemSheet(title: $newSubItemTitle, appData: viewModel.appData) {
                if !newSubItemTitle.isEmpty {
                    viewModel.addItem(title: newSubItemTitle, parent: item)
                    newSubItemTitle = ""
                }
            }
        }
    }
}