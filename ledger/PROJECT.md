# ChecklistManifesto

> Checklist app inspired by The Checklist Manifesto, with pre-built checklists for packing, processes, and more.

## Overview

A checklist app built around the principles from The Checklist Manifesto. Features pre-built checklists (packing lists for various trip types, process checklists) with a sophisticated item management system. Supports two item types (PACKING with packed/loaded stages, TODO with simple completion), categories with status roll-up, final pass review, cross-list item propagation, multi-select batch operations, and full undo/redo.

Actively used. In maintenance/refinement phase after a major v2.0 rewrite.

**Platform:** iOS (SwiftUI)
**Language:** Swift
**Persistence:** JSON-based (AppData model)
**Bundle:** Checklist Manifesto v2

## Architecture

### Code Organisation

```
Checklist Manifesto v2/
  Checklist_Manifesto_v2App.swift — App entry point
  ContentView.swift               — Root view
  Models/
    AppData.swift                 — Top-level data model
    Checklist.swift               — Checklist model
    ChecklistItem.swift           — Item model (types, stages, final pass)
    Theme.swift                   — Visual theming
  ViewModels/
    MainViewModel.swift           — App-level state
    ChecklistViewModel.swift      — Single checklist state
  Views/
    ChecklistView.swift           — Main checklist display
    ChecklistItemRow.swift        — Individual item row
    AddItemView.swift             — Item creation with category selection
    ChecklistEditorView.swift     — Checklist configuration
    ChecklistEditSheet.swift      — Edit sheet
    MoveSelectedItemsSheet.swift  — Batch move UI
    ImportView.swift              — Import functionality
    TagsView.swift                — Tag management
    CustomCheckbox.swift          — Custom checkbox component
  Services/                       — (empty, reserved)
  Resources/                      — Pre-built checklist templates
```

### Key Concepts

- **Item Types:** PACKING (two-stage: Packed then Loaded) and TODO (simple completion)
- **Final Pass:** Items flagged for final review, shown in pinned virtual category
- **Category Roll-up:** Categories show grey/amber/green based on item completion
- **Propagation:** Add items to multiple lists at once with duplicate detection
- **List Types:** Weekend Trip, Week Away, International, Day Trip, Business Trip, Camping, Other

## Subsystems

| Subsystem | Status | Document |
|-----------|--------|----------|
| Data Model | Stable | — |
| Checklist UI | Stable | — |
| Item Management | Stable | — |

## Phase

**Maintenance / refinement.** v2.0 complete and in active use.

## Linked Projects

| Project | Relationship | Notes |
|---------|-------------|-------|
| — | — | — |

## Open Questions

- Any remaining rough edges from v2.0 migration
- Whether to add CloudKit sync for cross-device use
