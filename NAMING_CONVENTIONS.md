# Naming Conventions

This document defines the naming conventions used in the Modo iOS application codebase.

## General Principles

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use clear, descriptive names that explain intent
- Prefer clarity over brevity
- Use English for all code, comments, and documentation

## Variable Naming

### Boolean Variables
- **Always use `is` prefix** for boolean properties and variables
- Examples:
  - ✅ `isDone`, `isCompleted`, `isVisible`, `isLoading`
  - ❌ `done`, `completed`, `visible`, `loading`
  - ❌ `showCalendar` (use `isShowingCalendar` instead)

### State Variables
- Use descriptive names that indicate state
- For SwiftUI `@State` variables, use `is` prefix for booleans:
  - ✅ `@State private var isShowingCalendar = false`
  - ✅ `@State private var isViewVisible = false`
  - ❌ `@State private var showCalendar = false`

### Collections
- Use plural nouns for arrays and sets
- Examples: `tasks`, `users`, `items`

### Optionals
- Use descriptive names that indicate optionality
- Examples: `selectedDate`, `currentUser`, `optionalValue`

## Method Naming

### Action Methods
- **Always start with a verb**
- Use imperative mood for actions
- Examples:
  - ✅ `addTask()`, `removeTask()`, `updateTask()`, `loadTasks()`
  - ✅ `setupListener()`, `stopListener()`, `evaluateCompletion()`
  - ❌ `taskAdd()`, `taskRemove()`, `taskUpdate()`

### Query Methods
- Start with a verb that indicates querying
- Examples:
  - ✅ `getTask(by:)`, `findUser(with:)`, `hasPermission(for:)`
  - ✅ `isDateInRange(_:)`, `canPerformAction(_:)`

### Computed Properties
- Use noun phrases for computed properties
- Examples: `totalCalories`, `filteredTasks`, `dateRange`

## Type Naming

### Classes and Structs
- Use **PascalCase** (capitalize first letter of each word)
- Use nouns or noun phrases
- Examples: `TaskItem`, `UserProfile`, `DailyChallengeService`

### Protocols
- Use **PascalCase**
- End with `Protocol` suffix if it's a protocol (optional, but be consistent)
- Examples: `TaskServiceProtocol`, `AuthServiceProtocol`
- Or use descriptive names: `Codable`, `Identifiable`

### Enums
- Use **PascalCase** for enum name
- Use **camelCase** for cases
- Examples:
  ```swift
  enum TaskCategory {
      case diet
      case fitness
      case others
  }
  ```

## Service Naming

- End with `Service` suffix
- Use descriptive names that indicate responsibility
- Examples: `TaskManagerService`, `AuthService`, `DatabaseService`

## Constants

### Static Constants
- Use **camelCase** for static properties
- Use descriptive names
- Examples: `inputFieldMaxWidth`, `defaultTimeout`, `maxRetryCount`

### Enum Cases for Constants
- Group related constants in enums
- Examples:
  ```swift
  enum AppConstants {
      enum DateRange {
          static let pastMonths = 12
          static let futureMonths = 3
      }
  }
  ```

## File Naming

- Match file name with primary type/struct name
- Use **PascalCase**
- Examples: `TaskItem.swift`, `MainPageView.swift`, `AuthService.swift`

## Migration Notes

### Current Inconsistencies to Fix

1. **Boolean variables:**
   - `isDone` (TaskItem) ✅
   - `isCompleted` (DailyCompletion) ✅
   - `showDailyChallengeDetail` → should be `isShowingDailyChallengeDetail`
   - `showAITaskLoading` → should be `isAITaskLoading` (not showing, but loading state)

2. **Method names:**
   - Most methods already follow verb-first convention ✅
   - Verify all methods start with verbs

## Examples

### Good Examples

```swift
// Boolean state
@State private var isShowingCalendar = false
@State private var isViewVisible = false

// Action methods
func addTask(_ task: TaskItem)
func removeTask(_ task: TaskItem)
func updateTask(_ newTask: TaskItem, oldTask: TaskItem)

// Query methods
func getTask(by id: UUID) -> TaskItem?
func isDateInCacheWindow(_ date: Date) -> Bool

// Computed properties
var totalCalories: Int
var filteredTasks: [TaskItem]
```

### Bad Examples

```swift
// Boolean without is prefix
@State private var showCalendar = false  // ❌
var done: Bool  // ❌

// Method without verb
func taskAdd()  // ❌
func taskRemove()  // ❌

// Unclear naming
var data: [TaskItem]  // ❌ (too generic)
func process()  // ❌ (unclear what it processes)
```

