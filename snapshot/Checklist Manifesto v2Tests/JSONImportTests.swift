import XCTest
@testable import Checklist_Manifesto_v2

class JSONImportTests: XCTestCase {

    func testImportHouseholdWeeklyShopJSON() throws {
        let json = """
        {
            "title": "Household Weekly Shop",
            "tags": [
                "Home",
                "Supplies",
                "Weekly"
            ],
            "autoResetEnabled": true,
            "resetAfterDays": 7,
            "notes": "Weekly restock checklist by room.",
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
                            "title": "Decongestion Nose Spray",
                            "nestingLevel": 1,
                            "isFirstTicked": false,
                            "children": []
                        },
                        {
                            "id": "b1000000-0000-0000-0000-000000000202",
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

        // Test decoding
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let checklist = try decoder.decode(Checklist.self, from: data)

        // Verify basic properties
        XCTAssertEqual(checklist.title, "Household Weekly Shop")
        XCTAssertEqual(checklist.tags, ["Home", "Supplies", "Weekly"])
        XCTAssertEqual(checklist.autoResetEnabled, true)
        XCTAssertEqual(checklist.resetAfterDays, 7)
        XCTAssertEqual(checklist.notes, "Weekly restock checklist by room.")

        // Verify top-level items
        XCTAssertEqual(checklist.items.count, 2, "Should have 2 top-level categories")

        // Check Living Room category
        let livingRoom = checklist.items[0]
        XCTAssertEqual(livingRoom.title, "Living Room")
        XCTAssertEqual(livingRoom.children.count, 2, "Living Room should have 2 children")

        // Check Living Room children
        XCTAssertEqual(livingRoom.children[0].title, "Sellotape")
        XCTAssertEqual(livingRoom.children[1].title, "Gaffer Tape")

        // Check Bathroom category
        let bathroom = checklist.items[1]
        XCTAssertEqual(bathroom.title, "Bathroom")
        XCTAssertEqual(bathroom.children.count, 2, "Bathroom should have 2 children")

        // Check Bathroom children
        XCTAssertEqual(bathroom.children[0].title, "Decongestion Nose Spray")
        XCTAssertEqual(bathroom.children[1].title, "Shampoo")

        // Check total item count
        XCTAssertEqual(checklist.totalItemCount, 6, "Should have 6 total items (2 categories + 4 children)")

        print("✅ JSON Import Test Passed!")
        print("  - Title: \(checklist.title)")
        print("  - Top-level items: \(checklist.items.count)")
        print("  - Total items: \(checklist.totalItemCount)")

        for item in checklist.items {
            print("  📁 \(item.title): \(item.children.count) children")
            for child in item.children {
                print("    - \(child.title)")
            }
        }
    }
}