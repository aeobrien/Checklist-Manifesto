# Storage verification boundary

The executable checks compile actual maintained AppData, Checklist, ChecklistItem,
MainViewModel and ChecklistViewModel source. All runtime paths are injected private
temporary files, including permission errors, symlinks, FIFO, sparse oversized file,
external edits and a held flock. There is no replacement model or real Documents
store. Test execution is through Understudy; each receipt retains actual exit,
stdout, duration and source hashes. The complete current run is green-04 (19 groups).

Two behavioral red runs preserve data-loss and detail-rollback failures. The third
red is explicitly a Swift compile failure because item callbacks returned Void
instead of a save result; it is not described as a runtime failure. Final green
checks exercise the actual result path, rollback and successful durable readback.

The generic iOS compile includes actual maintained SwiftUI callers. Initial
sandbox failure was a denied Xcode asset/runtime service, not treated as source
success. Normal permission-approved ios-compile-02 succeeded; after item callback
changes ios-compile-03 succeeded. Both are builds only, not tests of rendered UI.
The existing unused categoryExists warning remains unchanged.

Future UI acceptance should use a separate disposable app fixture: open a valid
synthetic list, replace storage with malformed bytes, attempt import/create/edit
and item add/title changes, confirm each relevant sheet retains input and reports
failure, check stored bad bytes remain exact, restore valid storage deliberately,
and verify explicit reload followed by an acknowledged edit. No live user records
or installed phone state are part of this source slice.
