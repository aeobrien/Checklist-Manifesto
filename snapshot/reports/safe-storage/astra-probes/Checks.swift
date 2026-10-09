import Foundation
import Darwin

@main struct IndependentChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        func check(_ value: Bool, _ message: String) { if !value { fatalError(message) } }
        func bytes(_ title: String) throws -> Data { try JSONEncoder().encode(AppData(checklists: [Checklist(title: title)])) }
        let store = root.appendingPathComponent("records.json")
        let original = try bytes("Original"); try original.write(to: store)
        let vm = MainViewModel(storageURL: store)
        let lock = store.appendingPathExtension("lock")
        let other = root.appendingPathComponent("other.txt")
        try Data("must survive".utf8).write(to: other)
        try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: other)
        check(!vm.createChecklist(title:"Refused",tags:[],autoReset:false,resetDays:nil), "symlink lock allowed write")
        check(try Data(contentsOf: store) == original, "source replaced")
        check(try String(contentsOf: other) == "must survive", "lock target changed")
        try FileManager.default.removeItem(at:lock)
        check(vm.reloadData(), "recovery after bad lock failed")
        check(vm.createChecklist(title:"Allowed",tags:[],autoReset:false,resetDays:nil), "recovered write failed")
        check(MainViewModel(storageURL:store).appData.checklists.count == 2, "recovered write missing")
        print("PASS symlink lock refuses without modifying either file, then recovers")

        let saved = try Data(contentsOf:store)
        try Data([0xff,0xfe,0x00]).write(to:store)
        check(!vm.reloadData(), "invalid encoding accepted")
        check(vm.appData.checklists.count == 2, "failed reload lost last good data")
        try FileManager.default.removeItem(at:store)
        check(!vm.reloadData() && !vm.saveData(), "missing formerly corrupt store silently recreated")
        check(!FileManager.default.fileExists(atPath:store.path), "missing file recreated")
        try saved.write(to:store)
        check(vm.reloadData() && vm.storageCanSave && vm.storageError == nil, "restored original not recoverable")
        print("PASS corrupt then missing original stays protected until restored")

        let a=MainViewModel(storageURL:store), b=MainViewModel(storageURL:store)
        check(a.createChecklist(title:"A",tags:[],autoReset:false,resetDays:nil), "first writer failed")
        check(!b.deleteChecklist(b.appData.checklists[0]), "stale delete accepted")
        check(b.reloadData(), "stale writer could not reload")
        check(b.createChecklist(title:"B",tags:[],autoReset:false,resetDays:nil), "second fresh write failed")
        check(!a.saveData(), "first writer lost conflict protection")
        check(MainViewModel(storageURL:store).appData.checklists.map{$0.title} == ["Original","Allowed","A","B"], "conflict/recovery lost records")
        print("PASS alternating writers preserve acknowledged additions across stale deletion")

        let firstRun=root.appendingPathComponent("first.json")
        let fresh=MainViewModel(storageURL:firstRun)
        check(fresh.createChecklist(title:"Only",tags:[],autoReset:false,resetDays:nil), "first create failed")
        check(fresh.deleteChecklist(fresh.appData.checklists[0]), "last delete failed")
        let restarted=MainViewModel(storageURL:firstRun)
        check(restarted.appData.checklists.isEmpty && restarted.storageError == nil, "empty restart seeded")
        check(restarted.createChecklist(title:"New",tags:[],autoReset:false,resetDays:nil), "empty restart not writable")
        print("PASS first create, last delete, restart and fresh create")
        print("ASTRA_STORAGE_CHECKS passed=4 failed=0")
    }
}
