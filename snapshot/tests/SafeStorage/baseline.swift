import Foundation
@main struct Baseline {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CHECKLIST_TEST_FILE"]!)
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message); print("FAIL \(message)") }
        }
        let missing = MainViewModel()
        check(missing.appData.checklists.isEmpty && !FileManager.default.fileExists(atPath: url.path), "Missing store must not create sample records")
        try JSONEncoder().encode(AppData()).write(to: url)
        let empty = MainViewModel()
        check(empty.appData.checklists.isEmpty, "Valid empty store must stay empty")
        let corrupt = Data("invalid preserved bytes".utf8)
        try corrupt.write(to: url)
        _ = MainViewModel()
        check(try Data(contentsOf: url) == corrupt, "Unreadable original must remain unchanged")
        let good = AppData(checklists: [Checklist(title: "Synthetic retained list")])
        try JSONEncoder().encode(good).write(to: url)
        let reload = MainViewModel()
        try corrupt.write(to: url)
        reload.reloadData()
        check(reload.appData.checklists.count == 1, "Failed reload must retain last good memory")
        reload.saveData()
        check(try Data(contentsOf: url) == corrupt, "Save after failed reload must not replace original")
        print("BASELINE_FAILURES=\(failures.count)")
        if !failures.isEmpty { exit(1) }
    }
}
