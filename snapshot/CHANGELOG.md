# Changelog

## Version 2.0.0 - Major Update

### New Features

#### 1. Category Management on Item Creation
- **Required Category Selection**: When adding items, you must now select a category
- **Last Used Category**: The app remembers your last used category per list for faster entry
- **Inline Category Creation**: Create new categories directly from the Add Item sheet
- **One-Shot Keyboard Flow**: Optimized for quick item entry (name → category → return)

#### 2. Enhanced Move UX with Multi-Select
- **Long-Press Multi-Select**: Long-press any item to enter multi-select mode
- **Batch Operations**: Select multiple items and move or delete them together
- **Context Menu Access**: Right-click or long-press for quick actions
- **Accessibility Support**: Edit/Select fallback for keyboard and assistive technology users
- **Undo/Redo Support**: Full undo/redo for all move operations

#### 3. Item Types and Enhanced Tick Logic
- **Two Item Types**: PACKING items and TODO items
- **Stage System**: 
  - PACKING items have two stages: Packed (stage 1) and Loaded (stage 2)
  - TODO items have simple completion (stage 0 or 2)
- **Stage Enforcement**: Attempting to mark as Loaded before Packed shows confirmation prompt
- **Smart Category Roll-up**: Categories show green when all items complete, considering type-specific rules

#### 4. Final Pass Feature
- **Final Pass Flag**: Mark any item for final review
- **Virtual Final Pass Category**: Pinned section at top of list showing all final pass items
- **Grouped by Category**: Final pass items grouped by their original categories
- **Amber State**: Categories show amber when only final pass items remain
- **Semantic Colors**: System colors that respect light/dark mode and accessibility

#### 5. Item Propagation to Other Lists
- **Flexible Propagation Options**:
  - Add to all lists of same type (Weekend Trip, International, etc.)
  - Manually select specific lists
  - Skip propagation for single-list items
- **Smart Duplicate Detection**: Prevents duplicate items (same name, same category)
- **Category Sync**: Creates categories in target lists if needed
- **One-Time Operation**: No ongoing sync complexity

#### 6. Data Model Improvements
- **List Types**: Weekend Trip, Week Away, International, Day Trip, Business Trip, Camping, Other
- **Migration Support**: Existing items automatically migrated to new system
- **Category Conversion Tool**: Convert legacy "To-do" categories to TODO item type
- **Backward Compatibility**: Old data seamlessly upgraded on first launch

#### 7. Enhanced UI/UX
- **Category Status Badges**: Visual indicators (Grey/Amber/Green) for category completion
- **Multi-Select Toolbar**: Clear selection count and batch action buttons
- **Haptic Feedback**: Tactile feedback on stage changes and moves
- **VoiceOver Support**: Full accessibility labels for all new features
- **Performance Optimized**: Efficient handling of large lists (500+ items)

#### 8. Quality of Life Improvements
- **Undo/Redo**: Complete undo/redo stack for all operations
- **Auto-Collapse**: Completed task groups automatically collapse
- **Type Indicators**: Visual indicators for TODO items and Final Pass items
- **Smart Defaults**: Intelligent defaults based on usage patterns
- **Edge Case Handling**: Robust handling of all edge cases and conflicts

### Technical Improvements
- Enhanced data model with proper migrations
- Improved state management with undo/redo stack
- Performance optimizations for large lists
- Better separation of concerns in ViewModels
- Comprehensive error handling

### Bug Fixes
- Fixed items defaulting to bottom on creation
- Removed clunky organization mode
- Improved move operations UX
- Better handling of nested items

### Breaking Changes
- Organization mode removed in favor of multi-select
- Data model changes (automatic migration provided)

---

## What's New (User-Facing Summary)

### Smarter Item Management
Create items faster with required categories and smart defaults. The app remembers your preferences and streamlines the entry process.

### Powerful Multi-Select
Long-press any item to select multiple items at once. Move them between categories or delete them in batch. Full undo/redo keeps you safe.

### Packing vs To-Dos
Distinguish between packing items (with Packed/Loaded stages) and to-do items (simple completion). The app enforces logical progression and shows clear status.

### Final Pass Review
Mark items for final review before departure. See all final pass items in one place at the top of your list, grouped by category.

### Share Across Lists
Add new items to multiple lists at once. Choose by list type (Weekend Trip, International, etc.) or pick specific lists. Smart duplicate detection prevents clutter.

### Visual Improvements
- Category completion badges (grey/amber/green)
- Item type indicators
- Final pass flags
- Cleaner, more intuitive interface

### Performance & Reliability
- Faster with large lists
- Full undo/redo support
- Automatic data migration
- Comprehensive edge case handling