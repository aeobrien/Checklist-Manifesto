#!/usr/bin/env swift

import Foundation

// Minimal ChecklistItem struct for testing
struct ChecklistItem: Codable {
    let id: UUID
    var title: String
    var children: [ChecklistItem]
    var nestingLevel: Int
    var isFirstTicked: Bool
    var isSecondTicked: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        children = try container.decodeIfPresent([ChecklistItem].self, forKey: .children) ?? []
        nestingLevel = try container.decodeIfPresent(Int.self, forKey: .nestingLevel) ?? 0
        isFirstTicked = try container.decodeIfPresent(Bool.self, forKey: .isFirstTicked) ?? false
        isSecondTicked = try container.decodeIfPresent(Bool.self, forKey: .isSecondTicked)
    }
}

// Minimal Checklist struct for testing
struct Checklist: Codable {
    let title: String
    var items: [ChecklistItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
    }
}

// Test JSON - simplified version
let testJSON = """
{
    "title": "Test Checklist",
    "items": [
        {
            "id": "f3c4f5a1-6f1a-4a7a-9b7a-3a6d3c2b0001",
            "title": "Living Room",
            "nestingLevel": 0,
            "isFirstTicked": false,
            "isSecondTicked": false,
            "children": [
                {
                    "id": "c2b5f6a1-2f4d-4a0a-9e11-100000000101",
                    "title": "Sellotape",
                    "nestingLevel": 1,
                    "isFirstTicked": false,
                    "children": []
                },
                {
                    "id": "c2b5f6a1-2f4d-4a0a-9e11-100000000102",
                    "title": "Gaffer Tape",
                    "nestingLevel": 1,
                    "isFirstTicked": false,
                    "children": []
                }
            ]
        },
        {
            "id": "f3c4f5a1-6f1a-4a7a-9b7a-3a6d3c2b0002",
            "title": "Bathroom",
            "nestingLevel": 0,
            "isFirstTicked": false,
            "isSecondTicked": false,
            "children": [
                {
                    "id": "b1000000-0000-0000-0000-000000000201",
                    "title": "Shampoo",
                    "nestingLevel": 1,
                    "isFirstTicked": false,
                    "children": []
                }
            ]
        }
    ]
}
"""

// Run the test
do {
    let data = testJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    let checklist = try decoder.decode(Checklist.self, from: data)

    print("✅ Successfully decoded checklist: \(checklist.title)")
    print("📊 Top-level items: \(checklist.items.count)")

    for item in checklist.items {
        print("\n📁 Category: \(item.title)")
        print("   Children count: \(item.children.count)")
        for child in item.children {
            print("   - \(child.title)")
        }
    }

    // Count total items
    var totalItems = 0
    for item in checklist.items {
        totalItems += 1
        totalItems += item.children.count
    }
    print("\n📊 Total items (including nested): \(totalItems)")

} catch {
    print("❌ Error decoding JSON: \(error)")
}