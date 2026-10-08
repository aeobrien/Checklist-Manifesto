import XCTest
@testable import Checklist_Manifesto_v2

class ChecklistTests: XCTestCase {
    
    // MARK: - Item Type Tests
    
    func testPackingItemStageProgression() {
        var item = ChecklistItem(
            title: "Test Item",
            category: "Clothes",
            itemType: .packing
        )
        
        XCTAssertEqual(item.stage, 0)
        XCTAssertFalse(item.isPacked)
        XCTAssertFalse(item.isLoaded)
        XCTAssertFalse(item.isComplete)
        
        // Mark as packed
        item.setStage(1)
        XCTAssertEqual(item.stage, 1)
        XCTAssertTrue(item.isPacked)
        XCTAssertFalse(item.isLoaded)
        XCTAssertFalse(item.isComplete)
        
        // Mark as loaded
        item.setStage(2)
        XCTAssertEqual(item.stage, 2)
        XCTAssertTrue(item.isPacked)
        XCTAssertTrue(item.isLoaded)
        XCTAssertTrue(item.isComplete)
    }
    
    func testTodoItemCompletion() {
        var item = ChecklistItem(
            title: "Call hotel",
            category: "Tasks",
            itemType: .todo
        )
        
        XCTAssertEqual(item.stage, 0)
        XCTAssertFalse(item.isComplete)
        
        // Complete the todo
        item.setStage(2)
        XCTAssertEqual(item.stage, 2)
        XCTAssertTrue(item.isComplete)
    }
    
    // MARK: - Category Status Tests
    
    func testCategoryCompletionStatus() {
        let checklist = Checklist(
            title: "Weekend Trip",
            listType: .weekendTrip
        )
        
        // Test empty category
        XCTAssertEqual(checklist.categoryCompletionStatus(for: []), .complete)
        
        // Test with packing items
        let packingItems = [
            ChecklistItem(title: "Shirt", category: "Clothes", itemType: .packing, stage: 2),
            ChecklistItem(title: "Pants", category: "Clothes", itemType: .packing, stage: 2)
        ]
        XCTAssertEqual(checklist.categoryCompletionStatus(for: packingItems), .complete)
        
        // Test with mixed completion
        let mixedItems = [
            ChecklistItem(title: "Shirt", category: "Clothes", itemType: .packing, stage: 2),
            ChecklistItem(title: "Pants", category: "Clothes", itemType: .packing, stage: 0)
        ]
        XCTAssertEqual(checklist.categoryCompletionStatus(for: mixedItems), .incomplete)
        
        // Test amber state (only final pass items remaining)
        let amberItems = [
            ChecklistItem(title: "Shirt", category: "Clothes", itemType: .packing, stage: 2),
            ChecklistItem(title: "Passport", category: "Clothes", itemType: .packing, stage: 0, finalPass: true)
        ]
        XCTAssertEqual(checklist.categoryCompletionStatus(for: amberItems), .amber)
    }
    
    // MARK: - Migration Tests
    
    func testItemMigration() throws {
        // Test that old items are properly migrated
        let jsonData = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Old Item",
            "isFirstTicked": true,
            "isSecondTicked": false
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let item = try decoder.decode(ChecklistItem.self, from: jsonData)
        
        XCTAssertEqual(item.title, "Old Item")
        XCTAssertEqual(item.category, "General") // Default category
        XCTAssertEqual(item.itemType, .packing) // Default type
        XCTAssertEqual(item.stage, 1) // Migrated from isFirstTicked
        XCTAssertFalse(item.finalPass) // Default false
    }
    
    func testChecklistMigration() throws {
        // Test that old checklists are properly migrated
        let jsonData = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Old List",
            "items": []
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let checklist = try decoder.decode(Checklist.self, from: jsonData)
        
        XCTAssertEqual(checklist.title, "Old List")
        XCTAssertEqual(checklist.listType, .other) // Default type
        XCTAssertEqual(checklist.lastUsedCategory, "General") // Default category
    }
    
    // MARK: - Final Pass Tests
    
    func testFinalPassFiltering() {
        var checklist = Checklist(
            title: "Test List",
            items: [
                ChecklistItem(title: "Regular Item", category: "Cat1", finalPass: false),
                ChecklistItem(title: "Final Pass Item", category: "Cat1", finalPass: true),
                ChecklistItem(title: "Another Final", category: "Cat2", finalPass: true)
            ]
        )
        
        let finalPassItems = checklist.items.filter { $0.finalPass }
        XCTAssertEqual(finalPassItems.count, 2)
        
        let grouped = Dictionary(grouping: finalPassItems, by: { $0.category })
        XCTAssertEqual(grouped.keys.count, 2)
        XCTAssertEqual(grouped["Cat1"]?.count, 1)
        XCTAssertEqual(grouped["Cat2"]?.count, 1)
    }
    
    // MARK: - Category Conversion Tests
    
    func testConvertCategoryToTodoType() {
        var checklist = Checklist(
            title: "Test List",
            items: [
                ChecklistItem(title: "Pack shirt", category: "Clothes", itemType: .packing, stage: 1),
                ChecklistItem(title: "Call hotel", category: "To-do", itemType: .packing, stage: 0),
                ChecklistItem(title: "Book flight", category: "To-do", itemType: .packing, stage: 1)
            ]
        )
        
        checklist.convertCategoryToTodoType("To-do")
        
        // Check that only "To-do" category items were converted
        let clothesItem = checklist.items.first { $0.category == "Clothes" }
        XCTAssertEqual(clothesItem?.itemType, .packing)
        XCTAssertEqual(clothesItem?.stage, 1)
        
        let todoItems = checklist.items.filter { $0.category == "To-do" }
        XCTAssertTrue(todoItems.allSatisfy { $0.itemType == .todo })
        XCTAssertEqual(todoItems[0].stage, 0) // Was not ticked
        XCTAssertEqual(todoItems[1].stage, 2) // Was ticked (stage 1 -> complete for TODO)
    }
    
    // MARK: - Propagation Tests
    
    func testDuplicateDetection() {
        let checklist = Checklist(
            title: "Test List",
            items: [
                ChecklistItem(title: "Toothbrush", category: "Toiletries"),
                ChecklistItem(title: "TOOTHBRUSH", category: "Toiletries"), // Different case
                ChecklistItem(title: "Toothbrush", category: "Other") // Different category
            ]
        )
        
        // Check duplicate detection (case-insensitive, same category)
        let isDuplicate1 = checklist.items.contains { item in
            item.title.lowercased() == "toothbrush" && item.category == "Toiletries"
        }
        XCTAssertTrue(isDuplicate1)
        
        // Different category should not be considered duplicate
        let toiletryItems = checklist.items.filter { $0.category == "Toiletries" }
        let otherItems = checklist.items.filter { $0.category == "Other" }
        XCTAssertEqual(toiletryItems.count, 2)
        XCTAssertEqual(otherItems.count, 1)
    }
    
    // MARK: - Performance Tests
    
    func testLargeListPerformance() {
        self.measure {
            var checklist = Checklist(title: "Large List")
            
            // Add 500 items
            for i in 0..<500 {
                let category = "Category \(i % 10)"
                let item = ChecklistItem(
                    title: "Item \(i)",
                    category: category,
                    itemType: i % 2 == 0 ? .packing : .todo,
                    stage: i % 3,
                    finalPass: i % 10 == 0
                )
                checklist.items.append(item)
            }
            
            // Test category grouping performance
            _ = checklist.allCategoriesComplete()
            _ = checklist.categories
            _ = checklist.completionPercentage
        }
    }
}