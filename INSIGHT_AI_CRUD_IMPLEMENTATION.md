# Insight Page AI CRUD 功能实施指南（含架构优化）

> 从只有Add Task功能到完整的CRUD操作支持 + AI服务架构深度重构
> 
> 📅 预计工作量: 15-20 天
> 
> 🎯 目标: 
> - 实现完整的 CRUD 功能（自然语言对话完成任务管理）
> - 重构 AI 服务架构（清晰分层，可扩展，易维护）
> - 统一数据传输格式（类型安全的 DTO）
> - 优化通知机制（类型安全，可追踪）

---

## 📑 目录

- [架构优化概述](#架构优化概述)
- [现状分析](#现状分析)
- [架构设计](#架构设计)
- [实施步骤](#实施步骤)
  - [阶段 1: 数据模型扩展](#阶段-1-数据模型扩展)
  - [阶段 2: Function Calling 定义](#阶段-2-function-calling-定义)
  - [阶段 3: AI Service 核心逻辑](#阶段-3-ai-service-核心逻辑)
  - [阶段 4: ViewModel 集成](#阶段-4-viewmodel-集成)
  - [阶段 5: UI 组件实现](#阶段-5-ui-组件实现)
  - [阶段 6: 测试与优化](#阶段-6-测试与优化)
- [测试用例](#测试用例)
- [常见问题](#常见问题)

---

## 架构优化概述

### 🚨 为什么需要架构优化？

在实施 CRUD 功能之前，我们发现现有的 AI 服务架构存在以下问题：

| 问题 | 影响 | 优先级 |
|-----|------|--------|
| **职责混乱** | `ModoCoachService` 1049行，混合了对话、任务创建、数据持久化 | 🔴 高 |
| **重复代码** | 相同的初始化代码在3个服务中重复 | 🟡 中 |
| **通知机制不安全** | 字符串类型的通知名，userInfo 格式不一致 | 🔴 高 |
| **Function Calling 难扩展** | 300行的 switch-case，违反开闭原则 | 🟠 中高 |
| **缺乏数据层抽象** | 多种数据模型混用，转换逻辑分散 | 🟡 中 |

### 📐 优化策略

```
Phase 1: 基础设施重构
├── 统一 DTO 模型
├── 类型安全的通知管理
└── 公共工具类提取

Phase 2: 架构分层
├── Coordinator 层（统一入口）
├── Business 层（业务逻辑）
├── Handler 层（Function Calling）
└── Data 层（数据访问）

Phase 3: CRUD 实现
├── Read 功能
├── Update 功能
├── Delete 功能
└── Batch 操作

Phase 4: 集成与测试
├── UI 集成
├── 端到端测试
└── 性能优化
```

### 📄 相关文档

详细的架构优化方案请查看：[AI_SERVICE_ARCHITECTURE_OPTIMIZATION.md](./AI_SERVICE_ARCHITECTURE_OPTIMIZATION.md)

---

## 现状分析

### ✅ 已有功能
- **Create**: 通过 Accept 按钮创建任务
- AI 生成 workout/nutrition 计划
- Function Calling 机制（`generate_workout_plan`, `generate_nutrition_plan`, `generate_multi_day_plan`）

### ❌ 缺失功能
- **Read**: 查询现有任务
- **Update**: 修改任务属性
- **Delete**: 删除任务
- **Bulk Operations**: 批量操作

### 🏗️ 已有基础设施
| 组件 | 路径 | 功能 |
|------|------|------|
| `TaskManagerService` | `Services/Business/` | 完整的CRUD操作 |
| `ModoCoachService` | `Services/AI/` | AI对话和Function Calling |
| `AIPromptBuilder` | `Services/AI/` | 构建AI提示词 |
| `InsightsPageViewModel` | `ViewModels/` | Insight页面逻辑 |
| `DatabaseService` | `Services/Firebase/` | Firebase数据同步 |

---

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                         User Input                           │
│              ("今天有什么任务?" / "删除早餐任务")              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   InsightsPageViewModel                      │
│  - 处理用户输入                                               │
│  - 调用 ModoCoachService                                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    ModoCoachService                          │
│  - 发送消息到 OpenAI                                          │
│  - 处理 Function Calling 响应                                 │
│  - 调用对应的处理函数                                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Function Call Handler Layer                     │
│  ├─ handleReadTasks()    → 查询任务                          │
│  ├─ handleUpdateTask()   → 更新任务                          │
│  ├─ handleDeleteTask()   → 删除任务                          │
│  └─ handleBulkOperations() → 批量操作                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   TaskManagerService                         │
│  - addTask()                                                 │
│  - updateTask()                                              │
│  - removeTask()                                              │
│  - fetchTasks() [需要新增]                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Firebase/Cache (Persistence)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 实施步骤

## 阶段 1: 数据模型扩展

### 📝 任务清单

- [ ] 1.1 扩展 `FirebaseChatMessage` 模型
- [ ] 1.2 创建任务查询结果数据结构
- [ ] 1.3 创建任务操作确认数据结构

---

### 1.1 扩展 `FirebaseChatMessage` 模型

**文件**: `Modo/Models/ChatMessage.swift`

**操作**: 添加新的消息类型和数据结构

```swift
// ============================================================
// STEP 1.1: 在 ChatMessage.swift 中添加以下内容
// ============================================================

// 1. 扩展消息类型枚举
enum ChatMessageType: String, Codable {
    case text = "text"
    case workout_plan = "workout_plan"
    case nutrition_plan = "nutrition_plan"
    case multi_day_plan = "multi_day_plan"
    
    // ✨ 新增类型
    case task_query_result = "task_query_result"
    case task_operation_confirmation = "task_operation_confirmation"
}

// 2. 创建任务查询结果结构
struct TaskQueryResult: Codable {
    let date: String
    let dateRange: String? // "2024-01-01 to 2024-01-03"
    let totalTasks: Int
    let completedTasks: Int
    let tasks: [TaskSummary]
    
    struct TaskSummary: Codable {
        let id: String
        let title: String
        let time: String
        let category: String // "diet", "fitness", "others"
        let isDone: Bool
        let calories: Int?
        let subtitle: String
    }
}

// 3. 创建操作确认结构
struct TaskOperationConfirmation: Codable {
    let operation: String // "update", "delete", "create"
    let success: Bool
    let taskId: String?
    let taskTitle: String?
    let message: String
}

// 4. 在 FirebaseChatMessage 类中添加新属性
@Model
final class FirebaseChatMessage {
    // ... 现有属性 ...
    
    // ✨ 新增属性
    var taskQueryResult: TaskQueryResult?
    var taskOperationConfirmation: TaskOperationConfirmation?
    
    // 更新初始化器和 Codable 实现...
}
```

**验证点**:
```swift
// ✅ 编译无错误
// ✅ SwiftData 能正常初始化新属性
```

---

### 1.2 创建任务查询参数结构

**文件**: 新建 `Modo/Services/AI/TaskQueryModels.swift`

```swift
// ============================================================
// STEP 1.2: 创建新文件 TaskQueryModels.swift
// ============================================================

import Foundation

/// AI 查询任务的参数
struct TaskQueryParams: Codable {
    let date: String // "YYYY-MM-DD"
    let dateRange: Int? // 1-7 days
    let category: String? // "diet", "fitness", "others", nil = all
    let isDone: Bool? // filter by completion status
}

/// AI 更新任务的参数
struct TaskUpdateParams: Codable {
    let taskId: String
    let date: String
    let updates: TaskUpdates
    
    struct TaskUpdates: Codable {
        let title: String?
        let time: String?
        let isDone: Bool?
        let dietEntries: [DietEntryUpdate]?
        let fitnessEntries: [FitnessEntryUpdate]?
    }
    
    struct DietEntryUpdate: Codable {
        let name: String
        let calories: String
    }
    
    struct FitnessEntryUpdate: Codable {
        let name: String
        let calories: String
        let sets: String?
        let reps: String?
    }
}

/// AI 删除任务的参数
struct TaskDeleteParams: Codable {
    let taskId: String
    let date: String
}

/// 批量操作参数
struct BulkOperationParams: Codable {
    let operations: [Operation]
    
    struct Operation: Codable {
        let type: String // "create", "update", "delete"
        let taskId: String?
        let date: String
        let data: [String: Any]? // 灵活的数据结构
    }
}
```

**集成到项目**:
1. 在 Xcode 中右键 `Services/AI/` 文件夹
2. 选择 "New File" → "Swift File"
3. 命名为 `TaskQueryModels.swift`
4. 粘贴以上代码

---

## 阶段 2: Function Calling 定义

### 📝 任务清单

- [ ] 2.1 在 `AIPromptBuilder` 中定义 `read_tasks` 函数
- [ ] 2.2 定义 `update_task` 函数
- [ ] 2.3 定义 `delete_task` 函数
- [ ] 2.4 定义 `bulk_operations` 函数
- [ ] 2.5 更新系统提示词

---

### 2.1 定义 read_tasks 函数

**文件**: `Modo/Services/AI/AIPromptBuilder.swift`

**位置**: 在 `buildTools()` 方法中添加

```swift
// ============================================================
// STEP 2.1: 在 AIPromptBuilder.swift 的 buildTools() 中添加
// ============================================================

private func buildTools() -> [[String: Any]] {
    var tools: [[String: Any]] = []
    
    // ... 现有的工具定义 (generate_workout_plan, etc.) ...
    
    // ✨ 新增: read_tasks 函数
    let readTasksTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "read_tasks",
            "description": """
                Query and retrieve the user's tasks for a specific date or date range.
                Use this when the user asks about their tasks, schedule, or what they need to do.
                Examples:
                - "今天有什么任务?"
                - "这周的健身计划是什么?"
                - "我明天吃什么?"
                """,
            "parameters": [
                "type": "object",
                "properties": [
                    "date": [
                        "type": "string",
                        "description": "Target date in YYYY-MM-DD format. Use today's date if not specified."
                    ],
                    "date_range": [
                        "type": "integer",
                        "description": "Number of days to query (1-7). Default is 1 (single day).",
                        "minimum": 1,
                        "maximum": 7
                    ],
                    "category": [
                        "type": "string",
                        "enum": ["diet", "fitness", "others", "all"],
                        "description": "Filter tasks by category. Default is 'all'."
                    ],
                    "is_done": [
                        "type": "boolean",
                        "description": "Filter by completion status. Omit to show all tasks."
                    ]
                ],
                "required": ["date"]
            ]
        ]
    ]
    tools.append(readTasksTool)
    
    return tools
}
```

---

### 2.2 定义 update_task 函数

```swift
// ============================================================
// STEP 2.2: 继续在 buildTools() 中添加
// ============================================================

let updateTaskTool: [String: Any] = [
    "type": "function",
    "function": [
        "name": "update_task",
        "description": """
            Update an existing task's properties.
            Use this when the user wants to modify a task.
            Examples:
            - "把健身改到下午3点"
            - "标记早餐为已完成"
            - "修改午餐的卡路里"
            """,
        "parameters": [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "UUID of the task to update. Get this from read_tasks first."
                ],
                "date": [
                    "type": "string",
                    "description": "Date of the task in YYYY-MM-DD format."
                ],
                "updates": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "New task title"
                        ],
                        "time": [
                            "type": "string",
                            "description": "New time in HH:mm AM/PM format"
                        ],
                        "is_done": [
                            "type": "boolean",
                            "description": "New completion status"
                        ]
                    ],
                    "description": "Object containing the fields to update"
                ]
            ],
            "required": ["task_id", "date", "updates"]
        ]
    ]
]
tools.append(updateTaskTool)
```

---

### 2.3 定义 delete_task 函数

```swift
// ============================================================
// STEP 2.3: 继续在 buildTools() 中添加
// ============================================================

let deleteTaskTool: [String: Any] = [
    "type": "function",
    "function": [
        "name": "delete_task",
        "description": """
            Delete a task by its ID.
            Use this when the user wants to remove a task.
            Examples:
            - "删除早餐任务"
            - "取消今天的健身"
            IMPORTANT: Always confirm with user before deleting.
            """,
        "parameters": [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "UUID of the task to delete. Get this from read_tasks first."
                ],
                "date": [
                    "type": "string",
                    "description": "Date of the task in YYYY-MM-DD format."
                ],
                "confirmed": [
                    "type": "boolean",
                    "description": "Whether the user has confirmed the deletion. Always ask for confirmation first."
                ]
            ],
            "required": ["task_id", "date", "confirmed"]
        ]
    ]
]
tools.append(deleteTaskTool)
```

---

### 2.4 更新系统提示词

**位置**: 在 `buildSystemPrompt()` 方法中

```swift
// ============================================================
// STEP 2.4: 更新 buildSystemPrompt() 方法
// ============================================================

private func buildSystemPrompt(userProfile: UserProfile?) -> String {
    var prompt = """
        You are Modor, a professional wellness coach AI assistant.
        
        # Your Capabilities
        
        1. **Task Management** (NEW!)
           - Query tasks: Help users check their schedule
           - Update tasks: Modify task properties like time, status
           - Delete tasks: Remove tasks (always confirm first!)
           
        2. **Plan Generation**
           - Generate personalized workout plans
           - Create nutrition plans
           - Build multi-day plans
        
        # Task Management Guidelines
        
        When user asks about their tasks:
        1. Use read_tasks to fetch their schedule
        2. Present information clearly with emojis
        3. Offer helpful suggestions
        
        When user wants to modify tasks:
        1. First use read_tasks to find the task
        2. Then use update_task with the task_id
        3. Confirm the changes to the user
        
        When user wants to delete tasks:
        1. First use read_tasks to find the task
        2. Ask for confirmation explicitly
        3. Only call delete_task when confirmed=true
        
        # Response Format
        
        For task queries, format like:
        "📋 你今天的任务：
        1. ✅ 早餐 (7:30 AM) - 已完成
        2. ⏳ 健身训练 (9:00 AM) - 待完成
        3. ⏳ 午餐 (12:00 PM) - 待完成
        
        需要我帮你调整什么吗？"
        
        For updates/deletes, confirm clearly:
        "✅ 已将健身训练时间从 9:00 AM 改为 3:00 PM"
        
        """
    
    // ... 添加用户信息 ...
    
    return prompt
}
```

---

## 阶段 3: AI Service 核心逻辑

### 📝 任务清单

- [ ] 3.1 在 `ModoCoachService` 中添加新的 Function Call 处理
- [ ] 3.2 实现 `handleReadTasks`
- [ ] 3.3 实现 `handleUpdateTask`
- [ ] 3.4 实现 `handleDeleteTask`
- [ ] 3.5 添加 NotificationCenter 通知机制

---

### 3.1 添加 Function Call 处理入口

**文件**: `Modo/Services/AI/ModoCoachService.swift`

**位置**: 在 `processToolCalls` 方法中添加新的 case

```swift
// ============================================================
// STEP 3.1: 在 ModoCoachService.swift 的 processToolCalls 中添加
// ============================================================

private func processToolCalls(_ toolCalls: [[String: Any]], userProfile: UserProfile?) async {
    // ... 现有代码 ...
    
    for toolCall in toolCalls {
        guard let function = toolCall["function"] as? [String: Any],
              let name = function["name"] as? String,
              let argumentsString = function["arguments"] as? String else {
            continue
        }
        
        // Parse arguments
        guard let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            continue
        }
        
        // ✨ 新增: 处理 CRUD 操作
        switch name {
        case "read_tasks":
            await handleReadTasks(arguments: arguments, userProfile: userProfile)
            
        case "update_task":
            await handleUpdateTask(arguments: arguments, userProfile: userProfile)
            
        case "delete_task":
            await handleDeleteTask(arguments: arguments, userProfile: userProfile)
            
        case "generate_workout_plan":
            // 现有代码...
            
        case "generate_nutrition_plan":
            // 现有代码...
            
        // ... 其他 cases ...
        
        default:
            print("⚠️ Unknown function: \(name)")
        }
    }
}
```

---

### 3.2 实现 handleReadTasks

```swift
// ============================================================
// STEP 3.2: 在 ModoCoachService.swift 底部添加
// ============================================================

// MARK: - Task CRUD Handlers

/// 处理查询任务请求
private func handleReadTasks(arguments: [String: Any], userProfile: UserProfile?) async {
    print("📖 ModoCoachService: Handling read_tasks")
    
    // 解析参数
    guard let dateString = arguments["date"] as? String else {
        sendErrorMessage("无法解析日期参数")
        return
    }
    
    let dateRange = arguments["date_range"] as? Int ?? 1
    let category = arguments["category"] as? String
    let isDone = arguments["is_done"] as? Bool
    
    // 发送通知请求查询任务
    let queryInfo: [String: Any] = [
        "date": dateString,
        "dateRange": dateRange,
        "category": category ?? "all",
        "isDone": isDone as Any
    ]
    
    // 同步等待结果（使用 continuation）
    await withCheckedContinuation { continuation in
        var observer: NSObjectProtocol?
        
        // 监听结果
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskQueryResult"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            defer {
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            
            guard let tasks = notification.userInfo?["tasks"] as? [TaskItem] else {
                continuation.resume()
                return
            }
            
            // 转换为 TaskQueryResult
            let taskSummaries = tasks.map { task in
                TaskQueryResult.TaskSummary(
                    id: task.id.uuidString,
                    title: task.title,
                    time: task.time,
                    category: task.category.rawValue,
                    isDone: task.isDone,
                    calories: task.totalCalories,
                    subtitle: task.subtitle
                )
            }
            
            let result = TaskQueryResult(
                date: dateString,
                dateRange: dateRange > 1 ? "\(dateString) to [end]" : nil,
                totalTasks: tasks.count,
                completedTasks: tasks.filter { $0.isDone }.count,
                tasks: taskSummaries
            )
            
            // 创建消息
            let message = FirebaseChatMessage(
                content: self?.formatTaskQueryResult(result) ?? "",
                isFromUser: false
            )
            message.messageType = "task_query_result"
            message.taskQueryResult = result
            
            self?.messages.append(message)
            self?.saveMessage(message)
            
            continuation.resume()
        }
        
        // 发送查询请求
        NotificationCenter.default.post(
            name: NSNotification.Name("AIRequestTaskQuery"),
            object: nil,
            userInfo: queryInfo
        )
        
        // 超时保护（5秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                continuation.resume()
            }
        }
    }
}

/// 格式化任务查询结果为文本
private func formatTaskQueryResult(_ result: TaskQueryResult) -> String {
    var text = "📋 "
    
    if let dateRange = result.dateRange {
        text += "从 \(result.date) 开始的任务：\n\n"
    } else {
        text += "\(result.date) 的任务：\n\n"
    }
    
    if result.tasks.isEmpty {
        text += "暂无任务 📝\n\n"
        text += "要我帮你创建一些任务吗？"
        return text
    }
    
    for (index, task) in result.tasks.enumerated() {
        let status = task.isDone ? "✅" : "⏳"
        let categoryEmoji = getCategoryEmoji(task.category)
        
        text += "\(index + 1). \(status) \(categoryEmoji) \(task.title)\n"
        text += "   时间: \(task.time)\n"
        
        if let calories = task.calories, calories != 0 {
            text += "   卡路里: \(calories > 0 ? "+" : "")\(calories) kcal\n"
        }
        
        if !task.subtitle.isEmpty {
            text += "   详情: \(task.subtitle)\n"
        }
        
        text += "\n"
    }
    
    text += "完成进度: \(result.completedTasks)/\(result.totalTasks)\n\n"
    text += "需要我帮你调整什么吗？"
    
    return text
}

private func getCategoryEmoji(_ category: String) -> String {
    switch category {
    case "diet": return "🍽️"
    case "fitness": return "💪"
    case "others": return "📌"
    default: return "📝"
    }
}
```

---

### 3.3 实现 handleUpdateTask

```swift
// ============================================================
// STEP 3.3: 继续在 ModoCoachService.swift 中添加
// ============================================================

/// 处理更新任务请求
private func handleUpdateTask(arguments: [String: Any], userProfile: UserProfile?) async {
    print("✏️ ModoCoachService: Handling update_task")
    
    guard let taskId = arguments["task_id"] as? String,
          let dateString = arguments["date"] as? String,
          let updates = arguments["updates"] as? [String: Any] else {
        sendErrorMessage("无法解析更新参数")
        return
    }
    
    // 发送更新请求
    let updateInfo: [String: Any] = [
        "taskId": taskId,
        "date": dateString,
        "updates": updates
    ]
    
    await withCheckedContinuation { continuation in
        var observer: NSObjectProtocol?
        
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskUpdateResult"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            defer {
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            
            let success = notification.userInfo?["success"] as? Bool ?? false
            let taskTitle = notification.userInfo?["taskTitle"] as? String ?? "任务"
            
            let confirmation = TaskOperationConfirmation(
                operation: "update",
                success: success,
                taskId: taskId,
                taskTitle: taskTitle,
                message: success ? "✅ 已成功更新 \(taskTitle)" : "❌ 更新失败"
            )
            
            let message = FirebaseChatMessage(
                content: confirmation.message,
                isFromUser: false
            )
            message.messageType = "task_operation_confirmation"
            message.taskOperationConfirmation = confirmation
            
            self?.messages.append(message)
            self?.saveMessage(message)
            
            continuation.resume()
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("AIRequestTaskUpdate"),
            object: nil,
            userInfo: updateInfo
        )
        
        // 超时保护
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                continuation.resume()
            }
        }
    }
}
```

---

### 3.4 实现 handleDeleteTask

```swift
// ============================================================
// STEP 3.4: 继续在 ModoCoachService.swift 中添加
// ============================================================

/// 处理删除任务请求
private func handleDeleteTask(arguments: [String: Any], userProfile: UserProfile?) async {
    print("🗑️ ModoCoachService: Handling delete_task")
    
    guard let taskId = arguments["task_id"] as? String,
          let dateString = arguments["date"] as? String,
          let confirmed = arguments["confirmed"] as? Bool else {
        sendErrorMessage("无法解析删除参数")
        return
    }
    
    // 如果未确认，先请求确认
    if !confirmed {
        let confirmMessage = FirebaseChatMessage(
            content: "⚠️ 确定要删除这个任务吗？这个操作无法撤销。\n\n请回复「确认删除」来继续。",
            isFromUser: false
        )
        messages.append(confirmMessage)
        saveMessage(confirmMessage)
        return
    }
    
    // 发送删除请求
    let deleteInfo: [String: Any] = [
        "taskId": taskId,
        "date": dateString
    ]
    
    await withCheckedContinuation { continuation in
        var observer: NSObjectProtocol?
        
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskDeleteResult"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            defer {
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            
            let success = notification.userInfo?["success"] as? Bool ?? false
            let taskTitle = notification.userInfo?["taskTitle"] as? String ?? "任务"
            
            let confirmation = TaskOperationConfirmation(
                operation: "delete",
                success: success,
                taskId: taskId,
                taskTitle: taskTitle,
                message: success ? "✅ 已删除 \(taskTitle)" : "❌ 删除失败"
            )
            
            let message = FirebaseChatMessage(
                content: confirmation.message,
                isFromUser: false
            )
            message.messageType = "task_operation_confirmation"
            message.taskOperationConfirmation = confirmation
            
            self?.messages.append(message)
            self?.saveMessage(message)
            
            continuation.resume()
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("AIRequestTaskDelete"),
            object: nil,
            userInfo: deleteInfo
        )
        
        // 超时保护
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                continuation.resume()
            }
        }
    }
}

/// 发送错误消息
private func sendErrorMessage(_ error: String) {
    let message = FirebaseChatMessage(
        content: "❌ \(error)",
        isFromUser: false
    )
    messages.append(message)
    saveMessage(message)
}
```

---

## 阶段 4: ViewModel 集成

### 📝 任务清单

- [ ] 4.1 在 `InsightsPageViewModel` 中添加 TaskManagerService 依赖
- [ ] 4.2 实现通知监听
- [ ] 4.3 处理查询请求
- [ ] 4.4 处理更新请求
- [ ] 4.5 处理删除请求

---

### 4.1 添加 TaskManagerService 依赖

**文件**: `Modo/ViewModels/InsightsPageViewModel.swift`

```swift
// ============================================================
// STEP 4.1: 在 InsightsPageViewModel.swift 顶部添加
// ============================================================

final class InsightsPageViewModel: ObservableObject {
    // ... 现有属性 ...
    
    // ✨ 新增: TaskManagerService 依赖
    private weak var taskManagerService: TaskManagerService?
    
    // ... 其他代码 ...
    
    /// Setup ViewModel with dependencies
    func setup(
        modelContext: ModelContext,
        userProfileService: UserProfileService,
        authService: AuthService,
        taskManagerService: TaskManagerService  // ✨ 新增参数
    ) {
        self.modelContext = modelContext
        self.userProfileService = userProfileService
        self.authService = authService
        self.taskManagerService = taskManagerService  // ✨ 保存引用
        
        loadChatHistory()
        setupKeyboardObservers()
        observeUserChanges()
        setupDatabaseErrorObserver()
        setupTaskOperationObservers()  // ✨ 新增
    }
}
```

---

### 4.2 实现通知监听

```swift
// ============================================================
// STEP 4.2: 在 InsightsPageViewModel.swift 中添加
// ============================================================

// MARK: - Task Operation Observers

/// 设置任务操作的通知监听
private func setupTaskOperationObservers() {
    // 监听查询请求
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("AIRequestTaskQuery"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleTaskQueryRequest(notification.userInfo)
    }
    
    // 监听更新请求
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("AIRequestTaskUpdate"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleTaskUpdateRequest(notification.userInfo)
    }
    
    // 监听删除请求
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("AIRequestTaskDelete"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleTaskDeleteRequest(notification.userInfo)
    }
}
```

---

### 4.3 处理查询请求

```swift
// ============================================================
// STEP 4.3: 继续在 InsightsPageViewModel.swift 中添加
// ============================================================

// MARK: - Task Query Handler

/// 处理任务查询请求
private func handleTaskQueryRequest(_ userInfo: [AnyHashable: Any]?) {
    print("🔍 InsightsPageViewModel: Handling task query request")
    
    guard let dateString = userInfo?["date"] as? String,
          let userId = authService?.currentUser?.uid else {
        print("❌ Missing required parameters for task query")
        return
    }
    
    let dateRange = userInfo?["dateRange"] as? Int ?? 1
    let categoryFilter = userInfo?["category"] as? String ?? "all"
    let isDoneFilter = userInfo?["isDone"] as? Bool
    
    // 解析日期
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let startDate = dateFormatter.date(from: dateString) else {
        print("❌ Invalid date format: \(dateString)")
        return
    }
    
    // 查询任务
    var allTasks: [TaskItem] = []
    let calendar = Calendar.current
    
    for dayOffset in 0..<dateRange {
        guard let queryDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
            continue
        }
        
        // 从 TaskManagerService 获取任务
        if let tasks = taskManagerService?.fetchTasks(for: queryDate, userId: userId) {
            allTasks.append(contentsOf: tasks)
        }
    }
    
    // 应用过滤
    var filteredTasks = allTasks
    
    // 按类别过滤
    if categoryFilter != "all" {
        filteredTasks = filteredTasks.filter { task in
            task.category.rawValue == categoryFilter
        }
    }
    
    // 按完成状态过滤
    if let isDone = isDoneFilter {
        filteredTasks = filteredTasks.filter { $0.isDone == isDone }
    }
    
    // 按时间排序
    filteredTasks.sort { $0.timeDate < $1.timeDate }
    
    print("✅ Found \(filteredTasks.count) tasks (filtered from \(allTasks.count) total)")
    
    // 发送结果
    NotificationCenter.default.post(
        name: NSNotification.Name("TaskQueryResult"),
        object: nil,
        userInfo: ["tasks": filteredTasks]
    )
}
```

**⚠️ 注意**: 这里需要在 `TaskManagerService` 中添加一个新方法：

```swift
// ============================================================
// 需要在 TaskManagerService.swift 中添加
// ============================================================

/// Fetch tasks for a specific date (from cache)
/// - Parameters:
///   - date: Date to fetch tasks for
///   - userId: User ID
/// - Returns: Array of tasks or nil if not in cache
func fetchTasks(for date: Date, userId: String) -> [TaskItem]? {
    return cacheService.getTasks(for: date, userId: userId)
}
```

---

### 4.4 处理更新请求

```swift
// ============================================================
// STEP 4.4: 继续在 InsightsPageViewModel.swift 中添加
// ============================================================

// MARK: - Task Update Handler

/// 处理任务更新请求
private func handleTaskUpdateRequest(_ userInfo: [AnyHashable: Any]?) {
    print("✏️ InsightsPageViewModel: Handling task update request")
    
    guard let taskIdString = userInfo?["taskId"] as? String,
          let taskId = UUID(uuidString: taskIdString),
          let dateString = userInfo?["date"] as? String,
          let updates = userInfo?["updates"] as? [String: Any],
          let userId = authService?.currentUser?.uid else {
        print("❌ Missing required parameters for task update")
        sendUpdateResult(success: false, taskTitle: nil)
        return
    }
    
    // 解析日期
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let date = dateFormatter.date(from: dateString) else {
        print("❌ Invalid date format")
        sendUpdateResult(success: false, taskTitle: nil)
        return
    }
    
    // 获取现有任务
    guard let tasks = taskManagerService?.fetchTasks(for: date, userId: userId),
          let oldTask = tasks.first(where: { $0.id == taskId }) else {
        print("❌ Task not found: \(taskId)")
        sendUpdateResult(success: false, taskTitle: nil)
        return
    }
    
    // 应用更新
    var newTask = oldTask
    var hasChanges = false
    
    if let newTitle = updates["title"] as? String {
        newTask = TaskItem(
            id: newTask.id,
            title: newTitle,
            subtitle: newTask.subtitle,
            time: newTask.time,
            timeDate: newTask.timeDate,
            endTime: newTask.endTime,
            meta: newTask.meta,
            isDone: newTask.isDone,
            emphasisHex: newTask.emphasisHex,
            category: newTask.category,
            dietEntries: newTask.dietEntries,
            fitnessEntries: newTask.fitnessEntries,
            createdAt: newTask.createdAt,
            updatedAt: Date(),
            isAIGenerated: newTask.isAIGenerated,
            isDailyChallenge: newTask.isDailyChallenge
        )
        hasChanges = true
    }
    
    if let newTime = updates["time"] as? String {
        // 解析时间并更新 timeDate
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        if let timeDate = timeFormatter.date(from: newTime) {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            
            var combined = dateComponents
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute
            
            if let newTimeDate = calendar.date(from: combined) {
                newTask = TaskItem(
                    id: newTask.id,
                    title: newTask.title,
                    subtitle: newTask.subtitle,
                    time: newTime,
                    timeDate: newTimeDate,
                    endTime: newTask.endTime,
                    meta: newTask.meta,
                    isDone: newTask.isDone,
                    emphasisHex: newTask.emphasisHex,
                    category: newTask.category,
                    dietEntries: newTask.dietEntries,
                    fitnessEntries: newTask.fitnessEntries,
                    createdAt: newTask.createdAt,
                    updatedAt: Date(),
                    isAIGenerated: newTask.isAIGenerated,
                    isDailyChallenge: newTask.isDailyChallenge
                )
                hasChanges = true
            }
        }
    }
    
    if let isDone = updates["is_done"] as? Bool {
        newTask = newTask.with(isDone: isDone)
        hasChanges = true
    }
    
    guard hasChanges else {
        print("⚠️ No changes detected")
        sendUpdateResult(success: true, taskTitle: oldTask.title)
        return
    }
    
    // 调用 TaskManagerService 更新任务
    taskManagerService?.updateTask(newTask, oldTask: oldTask, userId: userId) { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("✅ Task updated successfully")
                self.sendUpdateResult(success: true, taskTitle: newTask.title)
            case .failure(let error):
                print("❌ Failed to update task: \(error)")
                self.sendUpdateResult(success: false, taskTitle: oldTask.title)
            }
        }
    }
}

/// 发送更新结果通知
private func sendUpdateResult(success: Bool, taskTitle: String?) {
    NotificationCenter.default.post(
        name: NSNotification.Name("TaskUpdateResult"),
        object: nil,
        userInfo: [
            "success": success,
            "taskTitle": taskTitle ?? "Unknown"
        ]
    )
}
```

---

### 4.5 处理删除请求

```swift
// ============================================================
// STEP 4.5: 继续在 InsightsPageViewModel.swift 中添加
// ============================================================

// MARK: - Task Delete Handler

/// 处理任务删除请求
private func handleTaskDeleteRequest(_ userInfo: [AnyHashable: Any]?) {
    print("🗑️ InsightsPageViewModel: Handling task delete request")
    
    guard let taskIdString = userInfo?["taskId"] as? String,
          let taskId = UUID(uuidString: taskIdString),
          let dateString = userInfo?["date"] as? String,
          let userId = authService?.currentUser?.uid else {
        print("❌ Missing required parameters for task delete")
        sendDeleteResult(success: false, taskTitle: nil)
        return
    }
    
    // 解析日期
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let date = dateFormatter.date(from: dateString) else {
        print("❌ Invalid date format")
        sendDeleteResult(success: false, taskTitle: nil)
        return
    }
    
    // 获取任务
    guard let tasks = taskManagerService?.fetchTasks(for: date, userId: userId),
          let task = tasks.first(where: { $0.id == taskId }) else {
        print("❌ Task not found: \(taskId)")
        sendDeleteResult(success: false, taskTitle: nil)
        return
    }
    
    let taskTitle = task.title
    
    // 调用 TaskManagerService 删除任务
    taskManagerService?.removeTask(task, userId: userId) { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("✅ Task deleted successfully")
                self.sendDeleteResult(success: true, taskTitle: taskTitle)
            case .failure(let error):
                print("❌ Failed to delete task: \(error)")
                self.sendDeleteResult(success: false, taskTitle: taskTitle)
            }
        }
    }
}

/// 发送删除结果通知
private func sendDeleteResult(success: Bool, taskTitle: String?) {
    NotificationCenter.default.post(
        name: NSNotification.Name("TaskDeleteResult"),
        object: nil,
        userInfo: [
            "success": success,
            "taskTitle": taskTitle ?? "Unknown"
        ]
    )
}
```

---

## 阶段 5: UI 组件实现

### 📝 任务清单

- [ ] 5.1 更新 `InsightsPageView` 传递 TaskManagerService
- [ ] 5.2 创建任务列表气泡组件
- [ ] 5.3 创建操作确认气泡组件
- [ ] 5.4 更新 `ChatBubble` 支持新消息类型

---

### 5.1 更新 InsightsPageView

**文件**: `Modo/UI/InsightPage/InsightPageView.swift`

```swift
// ============================================================
// STEP 5.1: 更新 InsightPageView.swift 的 onAppear
// ============================================================

struct InsightsPageView: View {
    // ... 现有代码 ...
    
    @EnvironmentObject var taskManagerService: TaskManagerService  // ✨ 添加
    
    var body: some View {
        // ... 现有 UI 代码 ...
        .onAppear {
            viewModel.setup(
                modelContext: modelContext,
                userProfileService: userProfileService,
                authService: authService,
                taskManagerService: taskManagerService  // ✨ 传递
            )
            viewModel.onAppear()
        }
        // ... 其他代码 ...
    }
}
```

**⚠️ 注意**: 需要在 `ModoApp.swift` 中注册 `TaskManagerService` 为环境对象：

```swift
// 在 ModoApp.swift 中
@StateObject private var taskManagerService = TaskManagerService(...)

WindowGroup {
    ContentView()
        .environmentObject(taskManagerService)  // ✨ 添加
        // ... 其他 environmentObject ...
}
```

---

### 5.2 创建任务列表气泡组件

**文件**: 新建 `Modo/UI/Components/Chat/TaskListBubbleView.swift`

```swift
// ============================================================
// STEP 5.2: 创建新文件 TaskListBubbleView.swift
// ============================================================

import SwiftUI

/// 显示任务查询结果的气泡组件
struct TaskListBubbleView: View {
    let result: TaskQueryResult
    let onTaskTap: ((String) -> Void)?
    
    init(result: TaskQueryResult, onTaskTap: ((String) -> Void)? = nil) {
        self.result = result
        self.onTaskTap = onTaskTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("📋 任务列表")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                // 进度指示
                Text("\(result.completedTasks)/\(result.totalTasks)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // 日期范围
            if let dateRange = result.dateRange {
                Text(dateRange)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text(result.date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 任务列表
            if result.tasks.isEmpty {
                emptyStateView
            } else {
                ForEach(result.tasks, id: \.id) { task in
                    TaskRowView(task: task)
                        .onTapGesture {
                            onTaskTap?(task.id)
                        }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("暂无任务")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// 单个任务行视图
struct TaskRowView: View {
    let task: TaskQueryResult.TaskSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // 完成状态
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(task.isDone ? .green : .gray)
            
            // 任务信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(categoryEmoji)
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(task.isDone)
                }
                
                HStack {
                    Text(task.time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if let calories = task.calories, calories != 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(calories > 0 ? "+" : "")\(calories) kcal")
                            .font(.system(size: 12))
                            .foregroundColor(calories > 0 ? .orange : .green)
                    }
                }
                
                if !task.subtitle.isEmpty {
                    Text(task.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 右箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var categoryEmoji: String {
        switch task.category {
        case "diet": return "🍽️"
        case "fitness": return "💪"
        case "others": return "📌"
        default: return "📝"
        }
    }
}

#Preview {
    let sampleResult = TaskQueryResult(
        date: "2024-01-15",
        dateRange: nil,
        totalTasks: 3,
        completedTasks: 1,
        tasks: [
            TaskQueryResult.TaskSummary(
                id: UUID().uuidString,
                title: "早餐",
                time: "7:30 AM",
                category: "diet",
                isDone: true,
                calories: 450,
                subtitle: "燕麦粥 + 鸡蛋"
            ),
            TaskQueryResult.TaskSummary(
                id: UUID().uuidString,
                title: "晨跑",
                time: "9:00 AM",
                category: "fitness",
                isDone: false,
                calories: -300,
                subtitle: "30分钟有氧"
            )
        ]
    )
    
    return TaskListBubbleView(result: sampleResult)
        .padding()
}
```

---

### 5.3 创建操作确认气泡组件

**文件**: 新建 `Modo/UI/Components/Chat/TaskOperationBubbleView.swift`

```swift
// ============================================================
// STEP 5.3: 创建新文件 TaskOperationBubbleView.swift
// ============================================================

import SwiftUI

/// 显示任务操作确认的气泡组件
struct TaskOperationBubbleView: View {
    let confirmation: TaskOperationConfirmation
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(confirmation.success ? .green : .red)
            
            // 消息
            VStack(alignment: .leading, spacing: 4) {
                Text(operationTitle)
                    .font(.system(size: 14, weight: .semibold))
                
                if let taskTitle = confirmation.taskTitle {
                    Text(taskTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Text(confirmation.message)
                    .font(.system(size: 13))
            }
            
            Spacer()
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(16)
    }
    
    private var iconName: String {
        if !confirmation.success {
            return "xmark.circle.fill"
        }
        
        switch confirmation.operation {
        case "update": return "checkmark.circle.fill"
        case "delete": return "trash.circle.fill"
        case "create": return "plus.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }
    
    private var operationTitle: String {
        switch confirmation.operation {
        case "update": return "任务已更新"
        case "delete": return "任务已删除"
        case "create": return "任务已创建"
        default: return "操作完成"
        }
    }
    
    private var backgroundColor: Color {
        confirmation.success
            ? Color.green.opacity(0.1)
            : Color.red.opacity(0.1)
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskOperationBubbleView(
            confirmation: TaskOperationConfirmation(
                operation: "update",
                success: true,
                taskId: UUID().uuidString,
                taskTitle: "晨跑",
                message: "已将时间从 9:00 AM 改为 3:00 PM"
            )
        )
        
        TaskOperationBubbleView(
            confirmation: TaskOperationConfirmation(
                operation: "delete",
                success: true,
                taskId: UUID().uuidString,
                taskTitle: "午餐",
                message: "任务已删除"
            )
        )
        
        TaskOperationBubbleView(
            confirmation: TaskOperationConfirmation(
                operation: "update",
                success: false,
                taskId: nil,
                taskTitle: nil,
                message: "更新失败：任务不存在"
            )
        )
    }
    .padding()
}
```

---

### 5.4 更新 ChatBubble 支持新消息类型

**文件**: `Modo/UI/Components/Chat/ChatBubble.swift` (或类似路径)

```swift
// ============================================================
// STEP 5.4: 在 ChatBubble.swift 中添加
// ============================================================

struct ChatBubble: View {
    let message: FirebaseChatMessage
    let onAccept: ((FirebaseChatMessage) -> Void)?
    let onReject: ((FirebaseChatMessage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isFromUser {
                avatarView
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
                // 根据消息类型显示不同内容
                switch message.messageType {
                case "task_query_result":
                    if let result = message.taskQueryResult {
                        TaskListBubbleView(result: result) { taskId in
                            print("Task tapped: \(taskId)")
                            // 可以添加快速操作
                        }
                    } else {
                        defaultMessageView
                    }
                    
                case "task_operation_confirmation":
                    if let confirmation = message.taskOperationConfirmation {
                        TaskOperationBubbleView(confirmation: confirmation)
                    } else {
                        defaultMessageView
                    }
                    
                case "workout_plan", "nutrition_plan", "multi_day_plan":
                    // 现有的计划展示逻辑
                    existingPlanView
                    
                default:
                    defaultMessageView
                }
            }
            
            if message.isFromUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
    
    // ... 其他视图组件 ...
}
```

---

## 阶段 6: 测试与优化

### 📝 任务清单

- [ ] 6.1 单元测试
- [ ] 6.2 集成测试
- [ ] 6.3 用户体验测试
- [ ] 6.4 性能优化

---

### 6.1 单元测试

**文件**: 新建 `ModoTests/TaskCRUDTests.swift`

```swift
// ============================================================
// STEP 6.1: 创建测试文件
// ============================================================

import XCTest
@testable import Modo

final class TaskCRUDTests: XCTestCase {
    
    var viewModel: InsightsPageViewModel!
    var mockTaskManager: MockTaskManagerService!
    
    override func setUp() {
        super.setUp()
        mockTaskManager = MockTaskManagerService()
        viewModel = InsightsPageViewModel()
        // Setup with mock dependencies
    }
    
    // 测试查询任务
    func testQueryTasks() async {
        // Given
        let date = Date()
        let expectedTasks = [
            createMockTask(title: "早餐", category: .diet),
            createMockTask(title: "健身", category: .fitness)
        ]
        mockTaskManager.mockTasks = expectedTasks
        
        // When
        let result = await queryTasks(date: date)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "早餐")
    }
    
    // 测试更新任务
    func testUpdateTask() async {
        // Given
        let task = createMockTask(title: "原标题")
        let updates = ["title": "新标题"]
        
        // When
        let success = await updateTask(taskId: task.id, updates: updates)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(mockTaskManager.lastUpdatedTask?.title, "新标题")
    }
    
    // 测试删除任务
    func testDeleteTask() async {
        // Given
        let task = createMockTask()
        mockTaskManager.mockTasks = [task]
        
        // When
        let success = await deleteTask(taskId: task.id)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(mockTaskManager.deletedTaskIds.contains(task.id))
    }
    
    // Helper methods
    private func createMockTask(title: String = "Test", category: TaskCategory = .diet) -> TaskItem {
        return TaskItem(
            title: title,
            subtitle: "",
            time: "10:00 AM",
            timeDate: Date(),
            meta: "",
            emphasisHex: "#FF0000",
            category: category,
            dietEntries: [],
            fitnessEntries: []
        )
    }
}
```

---

## 测试用例

### 手动测试场景

#### 场景 1: 查询今天的任务
```
用户输入: "今天有什么任务?"
预期结果: 
- AI 调用 read_tasks 函数
- 显示任务列表气泡
- 列出所有今天的任务
- 显示完成进度
```

#### 场景 2: 查询特定类别
```
用户输入: "今天的饮食任务有哪些?"
预期结果:
- AI 调用 read_tasks(category="diet")
- 只显示饮食类任务
```

#### 场景 3: 更新任务时间
```
用户输入: "把健身改到下午3点"
预期结果:
- AI 先调用 read_tasks 找到健身任务
- 再调用 update_task 更新时间
- 显示确认消息
- Main Page 同步更新
```

#### 场景 4: 删除任务
```
用户输入: "删除午餐任务"
预期结果:
- AI 先请求确认
- 用户回复"确认"后再删除
- 显示删除成功消息
- Main Page 同步删除
```

#### 场景 5: 标记完成
```
用户输入: "标记早餐为已完成"
预期结果:
- AI 调用 update_task(isDone=true)
- 显示确认消息
- Main Page 显示打勾
```

---

## 常见问题

### Q1: 如何确保 Main Page 和 Insight Page 数据同步？
**A**: 使用 `TaskManagerService` 作为单一数据源，通过 cache 和 Firebase 双重同步。

### Q2: 如果 AI 找不到用户提到的任务怎么办？
**A**: AI 会先调用 `read_tasks` 确认任务存在，如果找不到会提示用户并询问是否要创建新任务。

### Q3: 如何处理并发修改冲突？
**A**: 使用 `updatedAt` 时间戳进行冲突检测，后写入的会覆盖先写入的（Last-Write-Wins）。

### Q4: 删除操作可以撤销吗？
**A**: 当前版本不支持撤销，未来可以考虑添加软删除机制。

### Q5: 如何测试 Function Calling？
**A**: 可以在 `ModoCoachService` 中添加日志，查看 OpenAI 返回的 function call 数据。

---

## 完成检查清单

### 阶段 1: 数据模型 ✅
- [ ] `FirebaseChatMessage` 扩展完成
- [ ] `TaskQueryModels.swift` 创建完成
- [ ] SwiftData 迁移成功

### 阶段 2: Function Calling ✅
- [ ] `read_tasks` 定义完成
- [ ] `update_task` 定义完成
- [ ] `delete_task` 定义完成
- [ ] 系统提示词更新完成

### 阶段 3: AI Service ✅
- [ ] `handleReadTasks` 实现完成
- [ ] `handleUpdateTask` 实现完成
- [ ] `handleDeleteTask` 实现完成
- [ ] 通知机制工作正常

### 阶段 4: ViewModel ✅
- [ ] TaskManagerService 集成完成
- [ ] 查询请求处理完成
- [ ] 更新请求处理完成
- [ ] 删除请求处理完成

### 阶段 5: UI ✅
- [ ] `TaskListBubbleView` 创建完成
- [ ] `TaskOperationBubbleView` 创建完成
- [ ] `ChatBubble` 更新完成
- [ ] UI 显示正常

### 阶段 6: 测试 ✅
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 手动测试场景通过
- [ ] 性能测试通过

---

## 预期时间线

| 阶段 | 预计时间 | 依赖 |
|------|---------|------|
| 阶段 1 | 1-2 天 | 无 |
| 阶段 2 | 1-2 天 | 阶段 1 |
| 阶段 3 | 2-3 天 | 阶段 1, 2 |
| 阶段 4 | 2-3 天 | 阶段 3 |
| 阶段 5 | 2-3 天 | 阶段 4 |
| 阶段 6 | 2-3 天 | 阶段 5 |
| **总计** | **10-16 天** | - |

---

## 总结

这个实施方案将 Insight Page 从单一的任务创建功能扩展到完整的 CRUD 操作，让用户可以通过自然语言对话完成所有任务管理操作。

**核心优势**:
1. ✅ 自然语言交互，无需学习复杂界面
2. ✅ 利用现有基础设施，代码复用度高
3. ✅ 渐进式实施，每个阶段都可独立验证
4. ✅ 双向同步，Main Page 和 Insight Page 数据一致

**下一步建议**:
- 添加批量操作支持
- 实现撤销/重做功能
- 添加任务搜索和过滤
- 支持任务模板和快捷创建

---

📝 **文档版本**: 1.0
📅 **创建日期**: 2024-11-16
👤 **负责人**: 开发团队

