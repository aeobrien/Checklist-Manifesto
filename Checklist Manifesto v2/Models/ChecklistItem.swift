import Foundation
import SwiftUI

enum ItemType: String, Codable {
    case packing = "PACKING"
    case todo = "TODO"
}

struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var category: String
    var children: [ChecklistItem]
    var isFirstTicked: Bool
    var isSecondTicked: Bool?
    var parentID: UUID?
    var nestingLevel: Int
    var isExpanded: Bool
    var itemType: ItemType
    var stage: Int
    var finalPass: Bool
    
    // Custom decoder to handle missing fields and migration
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
        children = try container.decodeIfPresent([ChecklistItem].self, forKey: .children) ?? []
        isFirstTicked = try container.decodeIfPresent(Bool.self, forKey: .isFirstTicked) ?? false
        isSecondTicked = try container.decodeIfPresent(Bool.self, forKey: .isSecondTicked)
        parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        nestingLevel = try container.decodeIfPresent(Int.self, forKey: .nestingLevel) ?? 0
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        
        // New fields with migration logic
        itemType = ItemType(rawValue: try container.decodeIfPresent(String.self, forKey: .itemType) ?? "PACKING") ?? .packing
        
        // Migrate existing two-tick state to stage
        if let explicitStage = try? container.decode(Int.self, forKey: .stage) {
            stage = explicitStage
        } else {
            // Migration: map old tick state to new stage system
            if isSecondTicked == true {
                stage = 2 // Both ticks checked -> Loaded
            } else if isFirstTicked {
                stage = 1 // First tick checked -> Packed
            } else {
                stage = 0 // Nothing checked
            }
        }
        
        finalPass = try container.decodeIfPresent(Bool.self, forKey: .finalPass) ?? false
        
        // Set isSecondTicked based on whether item has children (backward compatibility)
        if !children.isEmpty && isSecondTicked == nil {
            isSecondTicked = false
        }
    }
    
    init(id: UUID = UUID(), title: String, category: String = "General", children: [ChecklistItem] = [], parentID: UUID? = nil, nestingLevel: Int = 0, itemType: ItemType = .packing, stage: Int = 0, finalPass: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.children = children
        self.parentID = parentID
        self.nestingLevel = nestingLevel
        self.isFirstTicked = false
        self.isSecondTicked = children.isEmpty ? nil : false
        self.isExpanded = true
        self.itemType = itemType
        self.stage = stage
        self.finalPass = finalPass
    }
    
    var hasChildren: Bool {
        !children.isEmpty
    }
    
    var isLeaf: Bool {
        children.isEmpty
    }
    
    var allChildrenFirstTicked: Bool {
        guard hasChildren else { return false }
        return children.allSatisfy { child in
            if child.hasChildren {
                return child.isFirstTicked && child.allChildrenFirstTicked
            } else {
                return child.isFirstTicked
            }
        }
    }
    
    var allChildrenSecondTicked: Bool {
        guard hasChildren else { return false }
        return children.allSatisfy { child in
            if child.hasChildren {
                return child.isSecondTicked == true && child.allChildrenSecondTicked
            } else {
                return child.isFirstTicked
            }
        }
    }
    
    
    var isComplete: Bool {
        if itemType == .todo {
            return stage == 2
        } else {
            return hasChildren ? stage == 2 : isFirstTicked
        }
    }
    
    var isPacked: Bool {
        return stage >= 1
    }
    
    var isLoaded: Bool {
        return stage == 2
    }
    
    mutating func reset() {
        isFirstTicked = false
        stage = 0
        isExpanded = true  // Reset expanded state to true
        if hasChildren {
            isSecondTicked = false
            for i in children.indices {
                children[i].reset()
            }
        }
    }
    
    mutating func setStage(_ newStage: Int) {
        stage = newStage
        // Sync old tick state for backward compatibility
        if itemType == .packing {
            isFirstTicked = stage >= 1
            if hasChildren {
                isSecondTicked = stage == 2
            }
        } else if itemType == .todo {
            isFirstTicked = stage == 2
        }
    }
    
    mutating func toggleExpanded() {
        isExpanded.toggle()
    }
}