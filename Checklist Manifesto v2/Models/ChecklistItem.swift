import Foundation
import SwiftUI

struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var children: [ChecklistItem]
    var isFirstTicked: Bool
    var isSecondTicked: Bool?
    var parentID: UUID?
    var nestingLevel: Int
    var isExpanded: Bool
    
    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        children = try container.decodeIfPresent([ChecklistItem].self, forKey: .children) ?? []
        isFirstTicked = try container.decodeIfPresent(Bool.self, forKey: .isFirstTicked) ?? false
        isSecondTicked = try container.decodeIfPresent(Bool.self, forKey: .isSecondTicked)
        parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        nestingLevel = try container.decodeIfPresent(Int.self, forKey: .nestingLevel) ?? 0
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        
        // Set isSecondTicked based on whether item has children
        if !children.isEmpty && isSecondTicked == nil {
            isSecondTicked = false
        }
    }
    
    init(id: UUID = UUID(), title: String, children: [ChecklistItem] = [], parentID: UUID? = nil, nestingLevel: Int = 0) {
        self.id = id
        self.title = title
        self.children = children
        self.parentID = parentID
        self.nestingLevel = nestingLevel
        self.isFirstTicked = false
        self.isSecondTicked = children.isEmpty ? nil : false
        self.isExpanded = true
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
    
    
    mutating func reset() {
        isFirstTicked = false
        if hasChildren {
            isSecondTicked = false
            for i in children.indices {
                children[i].reset()
            }
        }
    }
    
    mutating func toggleExpanded() {
        isExpanded.toggle()
    }
}