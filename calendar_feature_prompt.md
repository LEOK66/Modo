# Prompt: 实现日期选择功能和 Map 结构的任务存储

## 项目背景

这是一个 iOS 健康管理应用（使用 SwiftUI），主要功能是让用户创建和管理每日的健康任务（tasks），包括：
- **Diet tasks**（饮食任务）：记录食物摄入和卡路里
- **Fitness tasks**（运动任务）：记录运动量和消耗的卡路里
- **Other tasks**（其他任务）

### 当前项目结构

#### 主要文件位置
- `Modo/UI/MainPages/MainPageView.swift` - 主界面视图（显示任务列表）
- `Modo/UI/MainPages/AddTaskView.swift` - 创建任务的视图
- `Modo/UI/MainPages/CalendarPopupView.swift` - 日历弹窗视图
- `Modo/UI/MainPages/DetailPageView.swift` - 任务详情/编辑视图
- `Modo/UI/MainPages/TaskListView.swift` - 任务列表视图组件（在 MainPageView 内部定义）

#### 当前数据模型

**MainPageView.swift** 中定义了 `TaskItem` struct：
```swift
struct TaskItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let time: String  // 显示用的时间字符串（如 "2:30 PM"）
    let timeDate: Date  // 完整的日期+时间，用于排序
    let endTime: String?
    let meta: String  // 卡路里信息（如 "+500 cal"）
    var isDone: Bool
    let emphasisHex: String  // 颜色代码
    let category: AddTaskView.Category  // diet, fitness, others
    var dietEntries: [AddTaskView.DietEntry]
    var fitnessEntries: [AddTaskView.FitnessEntry]
}
```
#### 当前存储方式

**MainPageView.swift** 中使用：
```swift
@State private var tasks: [TaskItem] = []  // 所有任务存在一个数组里
```

**问题：**
- 所有日期的 tasks 混在一个数组里
- 每次都需要遍历过滤来获取某日期的 tasks
- 没有日期选择功能，无法切换查看不同日期的任务
- 无法限制用户查看的日期范围

#### 当前 UI 结构

**MainPageView** 包含：
1. `TopHeaderView` - 顶部栏（头像、日期显示、日历按钮）
   - 当前日期显示是静态的（只显示今天）
2. `CombinedStatsCard` - 统计卡片（显示已完成任务数、Diet/Fitness 任务数、总卡路里）
   - 当前统计的是 `sortedTasks`（所有任务）
3. `TasksHeader` - 任务列表头部（"Today's Tasks" 标题，"Add Task" 按钮）
4. `TaskListView` - 任务列表
   - 当前显示所有 `tasks`，按 `timeDate` 排序
5. `CalendarPopupView` - 日历弹窗
   - 当前只是一个 UI 组件，选择日期后没有任何功能

**AddTaskView.swift** 当前：
- 使用 `@Binding var tasks: [MainPageView.TaskItem]` 接收任务数组
- 创建 task 时直接 `tasks.append(task)`
- `timeDate: Date = Date()` - 默认是当前时间（包含今天的日期和当前时间）
- 只允许选择时间（hour:minute），不允许选择日期

#### 当前存在的问题

1. **没有日期切换功能**：
   - 用户无法查看过去或未来的任务
   - `CalendarPopupView` 选择日期后没有实际效果
   - 顶部日期显示永远是"今天"

2. **数据组织不清晰**：
   - 所有日期的 tasks 混在一个数组里
   - 查找某日期的任务需要遍历过滤
   - 性能不够优化

3. **无法限制日期范围**：
   - 没有日期范围限制
   - 用户可以无限制地创建过去或未来的任务

4. **Stats 计算不准确**：
   - 当前统计的是所有任务，而不是当前查看日期的任务

## 需求概述

需要实现以下功能：

### 1. 日期选择功能
- 用户点击顶部的日历按钮，弹出 `CalendarPopupView`
- 用户选择日期后，主界面切换到该日期
- 显示该日期的 tasks（而不是所有 tasks）
- 顶部日期显示更新为选中的日期（如果是今天显示 "Today"，否则显示具体日期如 "January 15"）
- Stats 只统计当前选中日期的 tasks

### 2. 日期范围限制
- 只能查看过去 12 个月到未来 3 个月的日期
- 超出范围的日期在日历中显示为灰色，不可点击
- 用户无法选择超出范围的日期

### 3. 使用 Map 结构存储任务
- 将 `tasks: [TaskItem]` 改为 `tasksByDate: [Date: [TaskItem]]`
- Key 是日期（规范化后，只保留日期部分）
- Value 是该日期所有的任务数组
- 好处：查找更快（O(1)），逻辑更清晰，更容易扩展

### 4. 创建任务时使用选中日期
- **注意：`AddTaskView` 的 UI 不需要改变**（时间选择器仍然只显示时间 hour:minute，不显示日期选择）
- 只需要改变参数和创建逻辑：
  - 接收主界面当前选中的日期 `selectedDate`（从 MainPageView 传递）
  - 创建 task 时，将用户选择的时间（hour:minute）合并到 `selectedDate` 的日期上
- 例如：主界面选中了 10月5号，用户在 AddTaskView 选择时间 14:30，则 task 的 `timeDate` 应该是 `2024-10-05 14:30:00`（而不是今天的日期）

## 技术细节

### 日期规范化
所有日期比较和存储都应该使用 `Calendar.current.startOfDay(for:)` 来规范化，只保留日期部分，时间设为 00:00:00。这样确保：
- Map 的 key 是标准化的日期
- 日期比较时只比较日期部分，不受时间影响

**重要提示**：
- `timeDate` 字段（TaskItem 的完整日期+时间）保持不变，只用于排序和显示
- Map 的 key 使用规范化后的日期（`startOfDay`）
- 编辑任务时，只修改 `timeDate` 的 `hour:minute` 部分，日期部分不变（除非用户明确要求修改日期，但当前需求不需要）

### 日期范围计算
```swift
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
let minDate = calendar.date(byAdding: .month, value: -12, to: today)!  // 过去12个月
let maxDate = calendar.date(byAdding: .month, value: 3, to: today)!  // 未来3个月
```

### Map 结构示例
```swift
// 存储结构
tasksByDate = [
    2024-10-01 00:00:00: [task1, task2],  // 10月1号的 tasks
    2024-10-05 00:00:00: [task3, task4],  // 10月5号的 tasks
]

// 查找某日期的 tasks
let dateKey = calendar.startOfDay(for: selectedDate)
let tasks = tasksByDate[dateKey] ?? []
```

### 时间合并逻辑
在 `AddTaskView` 创建 task 时：
```swift
// timeDate 是用户在时间选择器中选择的时间（只有 hour:minute，日期是今天）
// selectedDate 是主界面选中的日期（只有日期部分）
let calendar = Calendar.current
let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                             minute: timeComponents.minute ?? 0,
                             second: 0,
                             of: selectedDate) ?? selectedDate
```
## 实现需求

### 1. 修改 MainPageView.swift

#### 1.1 数据结构变更
- 将 `@State private var tasks: [TaskItem] = []` 改为 `@State private var tasksByDate: [Date: [TaskItem]] = [:]`
- 添加 `@State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())`
- 添加 `dateRange` 计算属性（过去12个月到未来3个月）

#### 1.2 添加任务管理方法
- `tasks(for date: Date) -> [TaskItem]` - 获取某日期的 tasks（已排序）
  - 使用 `calendar.startOfDay(for: date)` 规范化日期作为 key
  - 返回 `tasksByDate[dateKey] ?? []`，并按 `timeDate` 排序
- `addTask(_ task: TaskItem)` - 添加 task（从 task.timeDate 中提取日期）
  - 使用 `calendar.startOfDay(for: task.timeDate)` 规范化日期作为 key
  - 如果该日期没有任务数组，创建新数组
  - 添加 task 到对应日期的数组中
  - **注意**：不需要单独传入 date 参数，因为 task.timeDate 已经包含了完整的日期和时间信息
- `removeTask(_ task: TaskItem)` - 删除 task
  - 遍历 `tasksByDate`，找到包含该 task 的日期（通过 `task.id` 匹配）
  - 从对应数组中移除 task
  - 如果数组变空，可选：保留空数组或移除该日期 key
- `updateTask(_ newTask: TaskItem, oldTask: TaskItem)` - 更新 task（处理日期可能改变的情况）
  - **重要**：比较新旧任务的日期（规范化后）
  - 如果日期相同：直接替换对应日期数组中的 task（通过 id 匹配）
  - 如果日期不同：从旧日期移除，添加到新日期
  - **注意**：必须保持 `task.id` 不变（编辑任务时 id 不应该改变）
- `getTask(by id: UUID) -> TaskItem?` - 通过 id 查找任务
  - 遍历 `tasksByDate` 的所有值，找到匹配 id 的任务
  - 返回找到的任务，如果不存在返回 `nil`

#### 1.3 修改计算属性
- 将 `sortedTasks` 改为 `filteredTasks`，返回 `tasks(for: selectedDate)`
- 移除 `tasksVersion`（如果存在），因为不再需要强制刷新排序

#### 1.4 修改 UI 组件调用
- `TopHeaderView` - 传递 `selectedDate`，显示选中日期或 "Today"
- `CombinedStatsCard` - 使用 `filteredTasks` 而不是 `sortedTasks`
- `CalendarPopupView` - 传递 `selectedDate` 和 `dateRange`
- `AddTaskView` - 传递 `selectedDate` 和 `onTaskCreated` 回调（保留 `newlyAddedTaskId` binding 用于动画）
- `TaskListView` - 传递 `filteredTasks` 和删除/更新回调
- `TaskDetailDestinationView` - 传递 `getTask` 函数和 `onUpdateTask` 回调
- `DetailPageView` - 传递 `taskId`、`getTask` 函数和 `onUpdateTask` 回调（见 5. 修改 DetailPageView.swift）

#### 1.5 修改 TasksHeader 和 TopHeaderView
- **TasksHeader**：将 "Today's Tasks" 改为动态文本
  - 如果 `selectedDate` 是今天：显示 "Today's Tasks"
  - 否则显示格式化的日期，如 "January 15's Tasks" 或简化为 "Tasks"（根据 UI 设计）
  - 使用 `Calendar.current.isDateInToday(selectedDate)` 判断是否是今天
  
- **TopHeaderView**：修改 `formattedDate` 计算属性
  ```swift
  private static func formattedDate(selectedDate: Date) -> String {
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let selected = calendar.startOfDay(for: selectedDate)
      
      if calendar.isDate(selected, inSameDayAs: today) {
          return "Today"
      }
      
      let df = DateFormatter()
      df.setLocalizedDateFormatFromTemplate("MMMM d")
      df.locale = .current
      return df.string(from: selectedDate)
  }
  ```
  - 传递 `selectedDate` 参数给 `formattedDate`（改为实例方法或添加参数）

#### 1.6 数据初始化（可选 - 如果有旧数据）
如果应用已经存在旧的 `tasks` 数组数据（例如从数据库加载），需要在初始化时迁移到 `tasksByDate`：
```swift
// 在 init() 或 onAppear 中
private func migrateTasksToMap(_ oldTasks: [TaskItem]) {
    let calendar = Calendar.current
    for task in oldTasks {
        let dateKey = calendar.startOfDay(for: task.timeDate)
        if tasksByDate[dateKey] == nil {
            tasksByDate[dateKey] = []
        }
        tasksByDate[dateKey]?.append(task)
    }
}
```

### 2. 修改 CalendarPopupView.swift

#### 2.1 参数修改
- 添加 `@Binding var selectedDate: Date`
- 添加 `let dateRange: (min: Date, max: Date)`

#### 2.2 实现日期范围限制
- 添加 `isDateSelectable(_ day: Int, in month: Date) -> Bool` 方法
- 在 `DaysGridView` 中判断日期是否可选
- 不可选的日期显示灰色，点击无效果

#### 2.3 实现日期选择
- 点击 "Confirm" 时，根据选择的日期构建完整 `Date`
  - 使用 `currentMonth` 和 `selectedDay` 构建日期
  - 规范化日期：`calendar.startOfDay(for: builtDate)`
  - 验证日期是否在 `dateRange` 内（双重检查）
- 更新 `selectedDate` binding
- 重置 `selectedDay` 为 `nil`（可选）
- 关闭弹窗

### 3. 修改 AddTaskView.swift

**重要：`AddTaskView` 的 UI 不需要改变**（时间选择器仍然是 `hour:minute`，不显示日期选择）

#### 3.1 参数修改
- 移除 `@Binding var tasks: [MainPageView.TaskItem]`
- 添加 `let selectedDate: Date`（从 MainPageView 传递，表示主界面当前选中的日期）
- 添加 `let onTaskCreated: (MainPageView.TaskItem) -> Void`（创建任务后的回调）
- **保留** `@Binding var newlyAddedTaskId: UUID?`（用于新任务动画，保持不变）

#### 3.2 修改创建逻辑
- **当前**：`timeDate` 直接使用 `Date()` 或 `timeDate`（永远是今天的日期）
- **需要改为**：将用户选择的时间（hour:minute）合并到 `selectedDate` 的日期上
  ```swift
  // timeDate 是用户在时间选择器中选择的时间（只有 hour:minute，日期部分是今天）
  // selectedDate 是主界面选中的日期（只有日期部分）
  let calendar = Calendar.current
  let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
  let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                               minute: timeComponents.minute ?? 0,
                               second: 0,
                               of: selectedDate) ?? selectedDate
  
  let task = MainPageView.TaskItem(
      // ...
      timeDate: finalDate,  // 使用合并后的日期+时间
      // ...
  )
  onTaskCreated(task)
  ```
- 这样创建的任务会属于主界面当前选中的日期，而不是今天的日期
- **注意**：`onTaskCreated` 回调中，MainPageView 应该调用 `addTask(task)` 方法，该方法会从 `task.timeDate` 中自动提取日期并添加到对应日期的数组中

### 4. 修改 TaskListView.swift

#### 4.1 参数修改
- 添加 `let onDeleteTask: (MainPageView.TaskItem) -> Void`
- **注意**：任务完成状态的切换（`isDone`）如果当前通过 `Binding` 直接修改，可以保持这种方式；或者改为通过 `onUpdateTask` 回调统一处理（根据实际代码决定）

#### 4.2 修改删除逻辑
- 删除时调用 `onDeleteTask(task)` 回调，而不是直接删除
- **注意**：在 MainPageView 中实现 `onDeleteTask` 回调时，应该调用 `removeTask(task)` 方法

### 5. 修改 DetailPageView.swift

**重要：** 当前 `DetailPageView` 使用 `taskIndex: Int` 和 `@Binding var tasks: [TaskItem]` 来访问任务。由于我们要改为 Map 结构，需要改变访问方式。

#### 5.1 参数修改
- **移除** `@Binding var tasks: [MainPageView.TaskItem]`
- **移除** `let taskIndex: Int`
- **添加** `let taskId: UUID`（通过 taskId 查找任务）
- **添加** `let onUpdateTask: (MainPageView.TaskItem, MainPageView.TaskItem) -> Void`（更新回调）
- **添加** `let getTask: (UUID) -> MainPageView.TaskItem?`（获取任务的函数，从 MainPageView 传递）
- **移除** `@Binding var tasksVersion: Int`（不再需要）

#### 5.2 修改任务访问方式
- 将 `private var task: MainPageView.TaskItem?` 改为计算属性，通过 `getTask(taskId)` 获取
- 在 `onAppear`、`loadTaskData()` 和所有需要访问任务的地方使用 `getTask(taskId)` 而不是 `tasks[taskIndex]`
- **注意**：`loadTaskData()` 方法中也需要相应修改，使用 `getTask(taskId)` 获取任务

#### 5.3 修改保存逻辑
- 在 `saveChanges()` 方法中：
  1. 使用 `getTask(taskId)` 获取旧任务（如果不存在则返回）
  2. 从旧任务的 `timeDate` 中提取日期部分（规范化）
  3. 从新的时间选择器值中提取 `hour:minute`
  4. 将 `hour:minute` 合并到旧任务的日期上，生成新的 `timeDate`
  5. 创建更新后的任务（保留相同的 `id`，使用新的 `timeDate`）
  6. 调用 `onUpdateTask(newTask, oldTask)` 回调
  7. **重要**：即使只修改时间，也可能导致日期改变（例如从 23:59 改到 00:01）。`updateTask` 方法会处理这种情况（比较新旧日期，如果不同则从旧日期移除，添加到新日期）

#### 5.4 时间选择器处理
- **当前**：`DetailPageView` 的时间选择器只选择 `hour:minute`
- **修改逻辑**：
  1. 加载任务时，从 `task.timeDate` 中提取时间部分显示在时间选择器中
  2. 保存时，将选择的时间合并到原任务的日期上
  3. **示例**：如果任务原本是 `2024-10-05 14:30:00`，用户编辑时间改为 `16:00`，新的 `timeDate` 应该是 `2024-10-05 16:00:00`（日期不变）
  4. **边界情况**：虽然时间选择器只允许选择时间，理论上不会跨天。但如果出现边界情况（如时间从 23:59 改到 00:01），新的 `timeDate` 仍然是 `2024-10-05 00:01:00`（保持原日期不变）。`updateTask` 方法会正确处理任何可能的日期变化。

## 注意事项

1. **日期规范化**：所有日期比较都使用 `Calendar.current.startOfDay(for:)` 规范化
2. **Map 的 Key**：使用规范化后的日期（只保留日期部分）
3. **日期范围边界**：`dateRange` 的 min 和 max 也要规范化
4. **初始化**：`selectedDate` 默认是今天，使用 `startOfDay` 规范化
5. **时间合并**：在 `AddTaskView` 创建 task 时，将时间合并到 `selectedDate` 的日期上
6. **空数组处理**：如果某日期没有 tasks，`tasks(for:)` 返回空数组，UI 会显示 `EmptyTasksView`
7. **边界日期**：超出范围的日期显示灰色且不可点击
8. **日期显示格式**：
   - 顶部日期显示：如果 `selectedDate` 是今天，显示 "Today"
   - 否则使用 `DateFormatter` 显示格式化的日期，如 "January 15"（使用 `setLocalizedDateFormatFromTemplate("MMMM d")`）
   - 考虑国际化：使用 `.current` locale
9. **编辑任务时的日期处理**：
   - 编辑任务时，任务的日期（`timeDate` 的日期部分）**保持不变**
   - 只允许修改时间（hour:minute）
   - 如果用户想改变任务的日期，需要删除旧任务并在新日期创建新任务（或实现移动功能，但当前需求不需要）
10. **任务 ID 保持不变**：编辑任务时，`task.id` 必须保持不变，用于在 Map 中定位和更新
11. **边界情况处理**：
    - `updateTask` 方法会自动处理日期改变的情况：
      - 如果新旧任务的日期相同，直接在 Map 中更新
      - 如果日期不同（理论上不应该发生，因为只修改时间，但如果时间跨天可能会有边界情况），会自动从旧日期移除，添加到新日期
    - **注意**：由于时间选择器只允许选择 `hour:minute`，通常不会跨天。但为了代码健壮性，`updateTask` 应该处理这种情况
12. **数据持久化**：
    - **当前阶段**：`tasksByDate` 使用 `@State`，数据存储在内存中
    - **后续扩展**：如果需要持久化，可以考虑：
      - 保存为 JSON 格式（键值对转换为字符串格式）
      - 使用 Firebase Realtime Database 或 Firestore
      - 使用 SwiftData 或 CoreData
    - **当前实现**：暂时不需要持久化，专注于 Map 结构和日期选择功能
13. **MainPageView 的 TaskDetailDestinationView**：
    - 修改为传递 `taskId` 而不是通过索引查找
    - 传递 `getTask` 函数给 `DetailPageView`
    - 传递 `onUpdateTask` 回调给 `DetailPageView`

## 预期效果

1. ✅ 点击日历选择日期后，主界面切换到该日期
2. ✅ 只显示该日期的 tasks（从 `tasksByDate` 中获取）
3. ✅ Stats 只显示该日期的数据
4. ✅ 在该日期点击 "Add Task"，创建的 task 属于该日期
5. ✅ 超出范围的日期显示灰色不可点击（过去 12 个月之前或未来 3 个月之后）
6. ✅ 顶部显示当前选中的日期（今天是 "Today"，其他显示具体日期）
7. ✅ 切换日期时，tasks 列表和 stats 实时更新
8. ✅ 删除 task 时，从 Map 中正确移除
9. ✅ 编辑 task 时，如果日期改变，会从旧日期移除并添加到新日期

## 测试场景

1. 选择今天：显示今天的 tasks
2. 选择未来日期（如 3 天后）：显示该日期的 tasks（可能为空）
3. 在未来日期创建 task：task 属于该日期
4. 切换回今天：显示今天的 tasks
5. 选择超出范围的日期：该日期不可点击（灰色）
6. Stats 随日期切换而变化
7. 删除 task：从 Map 中正确移除
8. 编辑 task（修改时间，日期不变）：任务在原日期中更新
9. 多个日期都有 tasks：切换日期时正确显示对应日期的 tasks
10. 编辑 task 时通过 taskId 正确查找和更新任务
11. 切换到没有任务的日期：显示 `EmptyTasksView`
12. 在边界日期（过去12个月的第一天，未来3个月的最后一天）创建和查看任务：功能正常

---

## 详细实现步骤

（以下是详细的代码修改指导，具体实现请参考上面的需求描述）

### 文件修改清单

1. **Modo/UI/MainPages/MainPageView.swift**
   - 数据结构：`tasks` → `tasksByDate`，添加 `selectedDate`
   - 添加任务管理方法（addTask, removeTask, updateTask, tasks(for:)）
   - 修改所有 UI 组件的调用和参数传递
   - 修改 `TopHeaderView` 内部实现

2. **Modo/UI/MainPages/CalendarPopupView.swift**
   - 参数：添加 `selectedDate` 和 `dateRange`
   - 实现日期范围判断：`isDateSelectable`
   - 修改 `DaysGridView`：判断日期可选性，灰色显示不可选日期
   - 修改 `DayCell`：支持不可选状态
   - 修改 `ActionButtonsView`：实现日期确认逻辑

3. **Modo/UI/MainPages/AddTaskView.swift**
   - 参数：移除 `tasks` binding，添加 `selectedDate` 和 `onTaskCreated`
   - 创建 task 时合并日期和时间

4. **Modo/UI/MainPages/MainPageView.swift** (TaskListView)
   - 参数：添加 `onDeleteTask` 和 `onUpdateTask` 回调
   - 删除时调用回调而不是直接删除

5. **Modo/UI/MainPages/DetailPageView.swift**
   - **重要修改**：改变访问方式，从 `taskIndex` + `@Binding tasks` 改为 `taskId` + `getTask` 函数
   - 参数：移除 `@Binding var tasks` 和 `taskIndex`，添加 `taskId`、`getTask` 和 `onUpdateTask`
   - 修改任务访问逻辑：使用 `getTask(taskId)` 获取任务
   - 修改保存逻辑：调用 `onUpdateTask` 回调，处理日期可能改变的情况
   - **注意**：编辑任务时只修改时间，不修改日期

6. **Modo/UI/MainPages/MainPageView.swift** (TaskDetailDestinationView)
   - 修改任务查找逻辑：通过 `taskId` 和 `getTask` 函数查找任务
   - 传递 `getTask` 和 `onUpdateTask` 给 `DetailPageView`

---

## 实现要求

**重要：请一步一步来实现，不要一次性完成所有修改。**

1. **拆分任务**：将这个大的实现任务拆分成多个小的、独立的步骤
2. **逐步实现**：每次只完成一小块功能（例如：先修改数据结构，再修改一个 UI 组件）
3. **需要许可**：每完成一个小任务后，必须等待用户的确认和许可才能继续下一个任务
4. **测试验证**：每个小任务完成后，确保代码可以编译和运行，再继续下一步

**建议的实现顺序**：
1. 首先修改 MainPageView 的数据结构（tasks → tasksByDate，添加 selectedDate）
2. 实现基础的任务管理方法（tasks(for:), addTask, removeTask, getTask）
3. 修改 TopHeaderView 显示选中日期
4. 实现 CalendarPopupView 的日期选择功能
5. 修改 AddTaskView 使用选中日期创建任务
6. 修改 TaskListView 使用回调
7. 最后修改 DetailPageView 和 TaskDetailDestinationView

请按照以上需求实现完整的日期选择功能和 Map 结构的任务存储。