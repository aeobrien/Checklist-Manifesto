# Preserve checklist data when loading or saving fails

Baseline c80bf457203fbb81226c7a63613b23b8f06960f0. This slice repairs local storage
and view-model error handling only. Import/copy semantics, session access, phone
container data, app installation and UI acceptance remain separate. No automatic
sample records. Own AppData.swift, MainViewModel.swift, thin TagsView error display,
and dedicated tests/docs/evidence; preserve all other work.

## Step 1: Reproduce destructive storage behavior with synthetic files

Compile the maintained models/view model with only a temporary storage URL in a
copy, retaining source hashes. Reproduce missing/empty stores being seeded,
corrupt bytes overwritten, and last good memory lost after failed reload. No app,
phone, screen, provider or actual Documents store is used.

- The file `reports/safe-storage/red-01/cli-run-result.json` exists.
- The file `tests/SafeStorage/baseline.swift` exists.

## Step 2: Make storage results explicit and writes acknowledged

Implement injected storage URL, explicit missing/loaded/error outcomes, bounded
regular-file reads and atomic saves. Preserve unreadable original bytes, keep a
valid empty store empty, never seed on load. Preserve last good memory on reload
failure. Refuse saves after failed load and changes since last read rather than
overwrite unknown data. Report save failures and do not present failed changes as
persisted. Keep existing stored model fields and migration intact. Expose plain
storage errors through a thin existing view, without UI redesign or import changes.

- The command `python3 tests/SafeStorage/run.py` exits 0.

## Step 3: Verify the maintained callers and retain honest limits

Run actual model/view-model regressions with temporary URLs, including empty,
corrupt, missing, malformed/nonregular source, write failure, repeated save,
changed-source refusal and metadata/progress round-trip. Compile affected iOS
callers where the local toolchain supports it without booting a simulator. Obtain
independent Astra/Fable reviews, committed Understudy review and canonical gate.
Do not claim UI execution or installed phone behavior from source/model tests.

- The file `docs/SAFE-STORAGE.md` exists.
- The file `reports/safe-storage/reviews.json` exists.
