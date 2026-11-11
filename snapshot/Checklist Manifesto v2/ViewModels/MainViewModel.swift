import Foundation
import SwiftUI

@MainActor
class MainViewModel: ObservableObject {
    @Published var appData: AppData
    @Published var selectedTag: String?
    @Published var showingCreateChecklist = false
    @Published var showingImport = false
    
    @Published private(set) var storageError: String?
    @Published var showingStorageError = false
    @Published private(set) var storageCanSave = false
    private let storage: ChecklistStorage
    private var expectedBytes: Data?
    private var lastGoodData = AppData()
    private var hasSeenStore = false

    init(storageURL: URL = AppData.fileURL) {
        self.appData = AppData()
        self.storage = ChecklistStorage(url: storageURL)
        reloadData()
    }

    @discardableResult
    func saveData() -> Bool {
        guard storageCanSave else {
            appData = lastGoodData
            showingStorageError = true
            return false
        }
        do {
            expectedBytes = try storage.save(appData, expecting: expectedBytes)
            lastGoodData = appData
            hasSeenStore = true
            storageError = nil
            return true
        } catch {
            appData = lastGoodData
            reportStorageError(error)
            return false
        }
    }

    @discardableResult
    func reloadData() -> Bool {
        do {
            switch try storage.load() {
            case .missing:
                guard !hasSeenStore else { throw ChecklistStorageError.missingExisting }
                appData = AppData()
                expectedBytes = nil
            case .loaded(let data, let bytes):
                appData = data
                expectedBytes = bytes
                hasSeenStore = true
            }
            lastGoodData = appData
            storageCanSave = true
            storageError = nil
            showingStorageError = false
            return true
        } catch {
            hasSeenStore = true
            reportStorageError(error)
            return false
        }
    }

    private func reportStorageError(_ error: Error) {
        storageCanSave = false
        storageError = error.localizedDescription
        showingStorageError = true
    }

    func getAllUsedItemTitles() -> [String] {
        var titles = Set<String>()
        
        func collectTitles(from items: [ChecklistItem]) {
            for item in items {
                titles.insert(item.title)
                if !item.children.isEmpty {
                    collectTitles(from: item.children)
                }
            }
        }
        
        for checklist in appData.checklists {
            collectTitles(from: checklist.items)
        }
        
        return Array(titles).sorted()
    }
    
    @discardableResult
    func deleteChecklist(_ checklist: Checklist) -> Bool {
        appData.checklists.removeAll { $0.id == checklist.id }
        return saveData()
    }
    
    @discardableResult
    func duplicateChecklist(_ checklist: Checklist) -> Bool {
        var newChecklist = Checklist(
            id: UUID(),
            title: "\(checklist.title) (Copy)",
            items: checklist.items,
            tags: checklist.tags,
            autoResetEnabled: checklist.autoResetEnabled,
            resetAfterDays: checklist.resetAfterDays
        )
        newChecklist.reset()
        
        appData.checklists.append(newChecklist)
        return saveData()
    }
    
    @discardableResult
    func createChecklist(title: String, tags: [String], autoReset: Bool, resetDays: Int?) -> Bool {
        let newChecklist = Checklist(
            title: title,
            tags: tags,
            autoResetEnabled: autoReset,
            resetAfterDays: resetDays
        )
        appData.checklists.append(newChecklist)
        return saveData()
    }
    
    @discardableResult
    func importChecklist(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let decodedChecklist = try? JSONDecoder().decode(Checklist.self, from: data) else {
            return false
        }
        
        var checklist = Checklist(
            id: UUID(),
            title: decodedChecklist.title,
            items: decodedChecklist.items,
            tags: decodedChecklist.tags,
            autoResetEnabled: decodedChecklist.autoResetEnabled,
            resetAfterDays: decodedChecklist.resetAfterDays
        )
        checklist.reset()
        
        appData.checklists.append(checklist)
        return saveData()
    }
    
}
