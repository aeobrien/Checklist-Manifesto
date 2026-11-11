import Foundation
import Darwin

@main struct Checks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        var failures: [String] = []; var passed = 0
        struct Failed: Error { let message: String }
        func expect(_ condition: Bool, _ message: String) throws {
            if !condition { throw Failed(message: message) }
        }
        func json(_ model: AppData) throws -> Data {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(model)
        }
        func fixture(_ title: String = "Synthetic") -> AppData {
            AppData(checklists: [Checklist(title: title)])
        }
        func test(_ name: String, _ body: (URL) throws -> Void) {
            do {
                let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try body(directory.appendingPathComponent("records.json"))
                passed += 1; print("PASS \(name)")
            } catch { failures.append(name); print("FAIL \(name): \(error)") }
        }
        test("missing store remains absent without examples") { url in
            let vm = MainViewModel(storageURL: url)
            try expect(vm.appData.checklists.isEmpty && vm.storageCanSave && vm.storageError == nil, "Missing did not load empty")
            try expect(!FileManager.default.fileExists(atPath: url.path), "Load wrote data")
            guard case .missing = try ChecklistStorage(url: url).load() else { throw Failed(message: "Not missing") }
        }
        test("valid empty remains empty after restart") { url in
            try json(AppData()).write(to: url)
            let before = try Data(contentsOf: url)
            let vm = MainViewModel(storageURL: url)
            try expect(vm.appData.checklists.isEmpty && vm.storageError == nil, "Empty was seeded")
            try expect(try Data(contentsOf: url) == before, "Initialization wrote")
        }
        test("corrupt original survives init and all save attempts") { url in
            let original = Data("not valid JSON".utf8); try original.write(to: url)
            let vm = MainViewModel(storageURL: url)
            try expect(vm.storageError != nil && !vm.storageCanSave, "Error hidden")
            vm.createChecklist(title: "Must not persist", tags: [], autoReset: false, resetDays: nil)
            try expect(!vm.saveData(), "Blocked store saved")
            try expect(vm.appData.checklists.isEmpty, "Failed addition still in saved model")
            try expect(try Data(contentsOf: url) == original, "Original replaced")
        }
        test("failed reload keeps last good memory and blocks save") { url in
            let good = fixture(); try json(good).write(to: url)
            let vm = MainViewModel(storageURL: url)
            let bad = Data("{".utf8); try bad.write(to: url)
            try expect(!vm.reloadData(), "Bad reload succeeded")
            try expect(try json(vm.appData) == json(good), "Last good memory lost")
            vm.appData.checklists.removeAll()
            try expect(!vm.saveData(), "Bad file overwritten")
            try expect(try json(vm.appData) == json(good), "Failed mutation was adopted")
            try expect(try Data(contentsOf: url) == bad, "Original changed")
        }
        test("changed store refuses stale save then explicit reload recovers") { url in
            try json(fixture("Old")).write(to: url)
            let vm = MainViewModel(storageURL: url)
            let external = try json(fixture("External")); try external.write(to: url)
            vm.appData.checklists[0].title = "Stale"
            try expect(!vm.saveData() && !vm.storageCanSave, "Stale write accepted")
            try expect(try Data(contentsOf: url) == external, "External change lost")
            try expect(vm.reloadData() && vm.appData.checklists[0].title == "External", "Reload did not recover")
            vm.appData.checklists[0].title = "New edit"
            try expect(vm.saveData(), "Fresh save refused")
            let read = MainViewModel(storageURL: url)
            try expect(read.appData.checklists[0].title == "New edit", "Readback mismatch")
        }
        test("missing after successful load preserves memory") { url in
            let good=fixture(); try json(good).write(to: url)
            let vm=MainViewModel(storageURL:url);try FileManager.default.removeItem(at:url)
            try expect(!vm.reloadData() && !vm.saveData(), "Missing prior file treated as first run")
            try expect(try json(vm.appData)==json(good), "Memory lost")
            try expect(!FileManager.default.fileExists(atPath:url.path), "Missing original recreated")
        }
        test("previously missing store appearing before save is not replaced") { url in
            let vm=MainViewModel(storageURL:url)
            let external=try json(fixture("Other"));try external.write(to:url)
            vm.appData=fixture("Ours")
            try expect(!vm.saveData(), "Unexpected file replaced")
            try expect(try Data(contentsOf:url)==external,"Existing file changed")
        }
        test("two instances cannot overwrite each other's read version") { url in
            try json(fixture()).write(to:url)
            let a=MainViewModel(storageURL:url), b=MainViewModel(storageURL:url)
            a.appData.checklists[0].title="First";try expect(a.saveData(),"First failed")
            b.appData.checklists[0].title="Second";try expect(!b.saveData(),"Stale second accepted")
            try expect(MainViewModel(storageURL:url).appData.checklists[0].title=="First","First lost")
        }
        test("write failure is surfaced and memory rolled back") { url in
            let absentParent=url.appendingPathComponent("absent").appendingPathComponent("store.json")
            let vm=MainViewModel(storageURL:absentParent);vm.appData=fixture("New")
            try expect(!vm.saveData() && vm.storageError != nil && vm.showingStorageError,"Write error swallowed")
            try expect(vm.appData.checklists.isEmpty,"Failed save adopted")
        }
        test("symlink store refused without changing target") { url in
            let target=url.appendingPathExtension("target");let good=try json(fixture());try good.write(to:target)
            try FileManager.default.createSymbolicLink(at:url,withDestinationURL:target)
            let vm=MainViewModel(storageURL:url)
            try expect(vm.storageError != nil && !vm.saveData(),"Symlink accepted")
            try expect(try Data(contentsOf:target)==good,"Target changed")
        }
        test("directory and FIFO are refused without hanging") { url in
            try FileManager.default.createDirectory(at:url,withIntermediateDirectories:false)
            try expect(MainViewModel(storageURL:url).storageError != nil,"Directory accepted")
            try FileManager.default.removeItem(at:url)
            try expect(mkfifo(url.path,0o600)==0,"Fixture FIFO creation failed")
            try expect(MainViewModel(storageURL:url).storageError != nil,"FIFO accepted")
        }
        test("unreadable regular file is not replaced") { url in
            let good=try json(fixture());try good.write(to:url);chmod(url.path,0)
            defer { chmod(url.path,0o600) }
            let vm=MainViewModel(storageURL:url)
            try expect(vm.storageError != nil && !vm.saveData(),"Unreadable source accepted")
            chmod(url.path,0o600);try expect(try Data(contentsOf:url)==good,"Unreadable original lost")
        }
        test("oversized file refuses before decode") { url in
            let fd=open(url.path,O_CREAT|O_RDWR,0o600);defer {close(fd)}
            try expect(fd>=0 && ftruncate(fd,off_t(ChecklistStorage.maximumBytes+1))==0,"Sparse fixture failed")
            try expect(MainViewModel(storageURL:url).storageError != nil,"Oversized source accepted")
        }
        test("held writer lock refuses save with original intact") { url in
            let original=try json(fixture());try original.write(to:url)
            let vm=MainViewModel(storageURL:url)
            let fd=open(url.appendingPathExtension("lock").path,O_CREAT|O_RDWR,0o600)
            defer {flock(fd,LOCK_UN);close(fd)}
            try expect(fd>=0 && flock(fd,LOCK_EX|LOCK_NB)==0,"Fixture lock failed")
            vm.appData.checklists[0].title="Blocked"
            try expect(!vm.saveData(),"Concurrent lock ignored")
            try expect(try Data(contentsOf:url)==original,"Locked source changed")
        }
        test("all metadata and nested state round trip exactly") { url in
            let parent=UUID();var child=ChecklistItem(title:"Child",category:"A",parentID:parent,nestingLevel:1,itemType:.todo,stage:2,finalPass:true)
            child.setStage(2);child.isExpanded=false
            var item=ChecklistItem(id:parent,title:"Parent",category:"A",children:[child]);item.setStage(1)
            var list=Checklist(title:"Whole model",items:[item],tags:["one","two"],autoResetEnabled:true,resetAfterDays:7,notes:"Keep these notes",listType:.camping,lastUsedCategory:"A")
            list.createdDate=Date(timeIntervalSince1970:100);list.modifiedDate=Date(timeIntervalSince1970:200);list.lastCompletedDate=Date(timeIntervalSince1970:300)
            let expected=AppData(checklists:[list]);let vm=MainViewModel(storageURL:url);vm.appData=expected
            try expect(vm.saveData(),"Save failed")
            try expect(try json(MainViewModel(storageURL:url).appData)==json(expected),"Metadata changed")
            try expect(vm.saveData(),"Repeated known save failed")
            vm.deleteChecklist(list)
            try expect(MainViewModel(storageURL:url).appData.checklists.isEmpty,"Deleting final list repopulated")
        }
        test("supplied corrupt expected bytes cannot authorize replacement") { url in
            let bad=Data("bad".utf8);try bad.write(to:url)
            do { _=try ChecklistStorage(url:url).save(fixture(),expecting:bad);throw Failed(message:"Corrupt store replaced") }
            catch is ChecklistStorageError { }
            try expect(try Data(contentsOf:url)==bad,"Bad bytes lost")
        }
        test("detail save failure restores the displayed checklist") { url in
            let good=fixture();try json(good).write(to:url)
            let vm=MainViewModel(storageURL:url)
            let detail=ChecklistViewModel(checklist:good.checklists[0],mainViewModel:vm)
            let bad=Data("broken".utf8);try bad.write(to:url)
            detail.checklist.title="Unsaved title"
            detail.saveChanges()
            try expect(detail.checklist.title==good.checklists[0].title,"Detail still displays failed edit as saved")
            try expect(try json(vm.appData)==json(good),"Root memory lost")
            try expect(try Data(contentsOf:url)==bad && vm.storageError != nil,"Original lost or error hidden")
        }
        test("create delete duplicate and import return failure without adopting changes") { url in
            let good=fixture();try json(good).write(to:url)
            let vm=MainViewModel(storageURL:url)
            let external=try json(fixture("Another writer"));try external.write(to:url)
            try expect(!vm.createChecklist(title:"Unsaved",tags:[],autoReset:false,resetDays:nil),"Create reported success")
            try expect(!vm.deleteChecklist(good.checklists[0]),"Delete reported success")
            try expect(!vm.duplicateChecklist(good.checklists[0]),"Duplicate reported success")
            let imported=String(data:try JSONEncoder().encode(good.checklists[0]),encoding:.utf8)!
            try expect(!vm.importChecklist(from:imported),"Import reported success")
            try expect(try json(vm.appData)==json(good),"Unpersisted changes adopted")
            try expect(try Data(contentsOf:url)==external,"External bytes changed")
            try expect(vm.reloadData(),"Explicit reload failed")
            try expect(vm.createChecklist(title:"Saved",tags:[],autoReset:false,resetDays:nil),"Create success not returned")
            try expect(MainViewModel(storageURL:url).appData.checklists.count==2,"Successful create missing")
        }
        test("item add and title callbacks expose failed and successful saves") { url in
            var good=fixture();good.checklists[0].items=[ChecklistItem(title:"Kept")]
            try json(good).write(to:url)
            let vm=MainViewModel(storageURL:url)
            let detail=ChecklistViewModel(checklist:good.checklists[0],mainViewModel:vm)
            let external=try json(fixture("Other"));try external.write(to:url)
            let added:Bool=detail.addItem(title:"Not saved")
            let renamed:Bool=detail.updateItemTitle(good.checklists[0].items[0],newTitle:"Not saved")
            try expect(!added && !renamed,"Failed mutation reported success to sheet")
            try expect(try json(vm.appData)==json(good),"Failed callback adopted model")
            try expect(detail.checklist.items.count==1 && detail.checklist.items[0].title=="Kept","Detail changed after failure")
            try expect(try Data(contentsOf:url)==external,"External store changed")
            try json(good).write(to:url);try expect(vm.reloadData(),"Reload failed")
            try expect(detail.addItem(title:"Saved"),"Successful add reported failure")
            try expect(detail.updateItemTitle(good.checklists[0].items[0],newTitle:"Changed"),"Successful title change reported failure")
            let saved=MainViewModel(storageURL:url)
            try expect(saved.appData.checklists[0].items.map(\.title)==["Changed","Saved"],"Callback success not persisted")
        }
        print("STORAGE_CHECKS passed=\(passed) failed=\(failures.count)")
        if !failures.isEmpty { exit(1) }
    }
}
