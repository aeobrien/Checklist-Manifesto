# Safe local checklist storage

The app now leaves a missing store empty, keeps an existing empty store empty,
and reports unreadable or damaged files without replacing them with examples.
The last successfully loaded/saved model survives a failed reload. A failed save
restores that model and requires a successful explicit reload before more writes.

`MainViewModel(storageURL:)` allows synthetic tests to use temporary files;
normal app use keeps the existing Documents/checklistData.json location. This
is not a Mac session API or access to an installed phone's container.

`ChecklistStorage.load()` distinguishes missing from decoded data and an error.
It refuses symlinks, nonregular files and stores larger than 32 MiB. Saving holds
a nonblocking exclusive sidecar lock, compares bytes with the last read version,
validates any existing data, atomically replaces the file and verifies readback.
The lock coordinates cooperating writers. An arbitrary external process replacing
files between comparison and replacement is outside that coordination contract.
An unconfirmed save requires reload; the app does not silently retry it.

Saving now returns Bool through the root and detail view models. Import retains
its input and uses its existing error alert on failure. Create/edit/delete sheets
only dismiss following success. The detail view restores its prior checklist on
failure. Item add/title callbacks also return the save result, keeping sheet input
and displaying a local error instead of dismissing on failure. Thin error text in existing screens accompanies the root error alert.
The import parser, hierarchy flattening, metadata copying and duplicate item IDs
are unchanged and remain the separate import/copy repair slice.

## Verification

Run `python3 tests/SafeStorage/run.py` for the actual maintained Swift model and
view-model tests, using only injected temporary URLs. These include damaged,
unreadable, missing and changed stores; lock contention; failed writes; metadata,
nesting and progress round-trip; detail rollback and caller success/failure values.
No real Documents data is read. The old behavior's five failures remain in red-01;
the detail rollback regression remains in caller-red-01.

Run `python3 tests/SafeStorage/compile-ios.py` for a temporary unsigned generic iOS
Simulator build. It never boots a simulator, launches the app or installs anything.
The first sandboxed attempt could not reach Xcode's asset/runtime services; the
normal permission-approved retry compiled successfully. Source compilation does
not establish that a user has seen or accepted the new error text.

## Remaining acceptance

The pre-existing multi-select move/delete and cross-list propagation transaction
shape is not redesigned here. Import identity/copy fixes remain next.

No UI execution, phone-container migration, installed rollout or session access
has been tested or performed. A later disposable UI fixture should verify error
visibility and that failed import/create/edit sheets keep their content and stay
open, then verify reload recovery. That acceptance must use normal screen leases
if it takes the desktop. No malformed real records should be used for that test.
