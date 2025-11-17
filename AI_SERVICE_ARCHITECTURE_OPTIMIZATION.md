# AI Service 架构优化与 CRUD 实施方案

> 深度重构 AI 服务架构，统一任务操作接口，实现完整的 CRUD 功能
> 
> 📅 预计工作量: 15-20 天
> 
> 🎯 目标: 
> - 清晰的分层架构
> - 统一的任务操作接口
> - 可扩展的 Function Calling 机制
> - 类型安全的通信层

---

## 📑 目录

- [现状分析](#现状分析)
- [架构问题](#架构问题)
- [重构方案](#重构方案)
- [新架构设计](#新架构设计)
- [实施步骤](#实施步骤)
- [代码示例](#代码示例)
- [迁移指南](#迁移指南)

---

## 现状分析

### 📊 现有 AI 服务结构

```
Services/AI/
├── ModoCoachService.swift (1049行) ⚠️ 职责过重
├── AITaskGenerator.swift (558行)
├── AddTaskAIService.swift (540行) ⚠️ 重复代码
├── MainPageAIService.swift (93行)
├── FirebaseAIService.swift (590行)
├── AIPromptBuilder.swift (705行)
├── AIResponseParser.swift (324行)
├── ExerciseDataService.swift
├── NutritionLookupService.swift
├── ModoAIError.swift
├── AddTaskAIParser.swift
└── OpenAIConfig.swift
```

### 🔍 代码审查发现

#### 问题 1: 职责混乱

**ModoCoachService** (1049行)
```swift
class ModoCoachService {
    // ❌ 混合职责
    - 管理对话消息
    - 处理 Function Calling
    - 发送 NotificationCenter 通知创建任务
    - 管理 SwiftData 持久化
    - 处理图片分析
    - 生成 AI 回复
}
```

**问题**:
- 违反单一职责原则
- 难以测试
- 难以复用
- 修改一个功能可能影响其他功能

---

#### 问题 2: 重复代码

**相同代码出现在 3 个地方**:
```swift
// AITaskGenerator.swift (line 14)
private let promptBuilder = AIPromptBuilder()
private let firebaseAIService = FirebaseAIService.shared

// AddTaskAIService.swift (line 8)
private let firebaseAIService = FirebaseAIService.shared
private let promptBuilder = AIPromptBuilder()

// ModoCoachService.swift (line 17)
private let promptBuilder = AIPromptBuilder()
private let firebaseAIService = FirebaseAIService.shared
```

**问题**:
- 没有依赖注入
- 难以 mock 测试
- 配置分散

---

#### 问题 3: 通知机制混乱

**散落在多处的通知**:
```swift
// InsightsPageViewModel.swift
NotificationCenter.default.post(
    name: NSNotification.Name("CreateWorkoutTask"),
    object: nil,
    userInfo: userInfo
)

// ModoCoachService.swift
NotificationCenter.default.post(
    name: NSNotification.Name("CreateNutritionTask"),
    object: nil,
    userInfo: userInfo
)

// 未来需要添加
NotificationCenter.default.post(
    name: NSNotification.Name("AIRequestTaskQuery"),
    ...
)
NotificationCenter.default.post(
    name: NSNotification.Name("AIRequestTaskUpdate"),
    ...
)
NotificationCenter.default.post(
    name: NSNotification.Name("AIRequestTaskDelete"),
    ...
)
```

**问题**:
- 字符串类型不安全
- 缺乏中心化管理
- userInfo 格式不一致
- 难以追踪和调试

---

#### 问题 4: Function Calling 处理冗长

**ModoCoachService.swift** (约 300 行的 switch-case):
```swift
private func processToolCalls(...) {
    for toolCall in toolCalls {
        switch name {
        case "generate_workout_plan":
            // 50+ lines
            
        case "generate_nutrition_plan":
            // 50+ lines
            
        case "generate_multi_day_plan":
            // 80+ lines
            
        // 未来需要添加
        case "read_tasks":
            // 需要添加大量代码
            
        case "update_task":
            // 需要添加大量代码
            
        case "delete_task":
            // 需要添加大量代码
        }
    }
}
```

**问题**:
- 违反开闭原则
- 每个 case 太长
- 难以维护
- 添加新功能需要修改主函数

---

#### 问题 5: 缺乏统一的数据层

**多种数据模型混用**:
```swift
// AITaskGenerator.swift
struct AIGeneratedTask { ... }
struct AIExercise { ... }
struct AIMeal { ... }

// TaskItem.swift
struct TaskItem { ... }

// WorkoutPlanFunctionResponse
struct WorkoutPlanFunctionResponse { ... }

// 数据转换逻辑分散
// - InsightsPageViewModel: AIGeneratedTask -> NotificationCenter
// - TaskCreationService: NotificationCenter -> TaskItem
// - ModoCoachService: WorkoutPlanFunctionResponse -> NotificationCenter
```

**问题**:
- 缺乏统一的 DTO
- 数据转换逻辑重复
- 难以保证数据一致性

---

#### 问题 6: 工具函数重复

**日期格式化** (出现 5+ 次):
```swift
// AITaskGenerator.swift (line 289)
private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

// InsightsPageViewModel.swift (类似代码)
// AddTaskAIService.swift (类似代码)
// ModoCoachService.swift (类似代码)
```

**Meal Time 获取** (出现 3+ 次):
```swift
// AITaskGenerator.swift (line 502)
private func getMealTime(_ mealName: String) -> String {
    switch mealName.lowercased() {
    case "breakfast": return "08:00 AM"
    case "lunch": return "12:00 PM"
    case "dinner": return "06:00 PM"
    case "snack": return "03:00 PM"
    default: return "12:00 PM"
    }
}

// ModoCoachService.swift (line 821)
private func getDefaultMealTime(for mealType: String) -> String {
    // 相同逻辑
}
```

---

## 架构问题

### 🚨 核心问题总结

| 问题类型 | 严重程度 | 影响 | 优化优先级 |
|---------|---------|------|-----------|
| 职责混乱 | 🔴 高 | 难以维护，修改风险大 | P0 |
| 重复代码 | 🟡 中 | 代码臃肿，不易测试 | P1 |
| 通知机制混乱 | 🔴 高 | 类型不安全，难以追踪 | P0 |
| Function Calling 处理冗长 | 🟠 中高 | 难以扩展，违反开闭原则 | P0 |
| 缺乏数据层抽象 | 🟡 中 | 数据转换逻辑分散 | P1 |
| 工具函数重复 | 🟢 低 | 代码重复但不影响功能 | P2 |

### 🎯 设计原则违反

1. **单一职责原则 (SRP)** - ModoCoachService 违反
2. **开闭原则 (OCP)** - Function Calling 处理违反
3. **依赖倒置原则 (DIP)** - 缺乏接口抽象
4. **不要重复自己 (DRY)** - 大量重复代码

---

## 重构方案

### 🏗️ 核心思路

```
旧架构: ViewModel -> Service -> NotificationCenter -> ViewModel
                    (混乱，紧耦合)

新架构: ViewModel -> Coordinator -> Handler -> Service -> TaskManager
                    (清晰，松耦合，可测试)
```

### 📐 设计模式应用

1. **Coordinator Pattern** - 统一协调 AI 服务
2. **Strategy Pattern** - Function Call 处理策略
3. **Factory Pattern** - 创建不同的处理器
4. **Observer Pattern** - 改进的通知机制
5. **Repository Pattern** - 统一数据访问
6. **DTO Pattern** - 统一数据传输

---

## 新架构设计

### 🎨 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                       │
│  ┌─────────────────────┐       ┌─────────────────────┐         │
│  │ InsightsPageViewModel│       │  TaskListViewModel  │         │
│  └──────────┬───────────┘       └──────────┬──────────┘         │
└─────────────┼──────────────────────────────┼────────────────────┘
              │                              │
              ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Coordination Layer                          │
│           ┌───────────────────────────────────┐                 │
│           │     AIServiceCoordinator          │                 │
│           │  - 统一入口                        │                 │
│           │  - 路由请求                        │                 │
│           │  - 管理生命周期                    │                 │
│           └─────────────┬─────────────────────┘                 │
└─────────────────────────┼───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Business Logic Layer                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  ChatService    │  │TaskOperations   │  │AnalysisService  │ │
│  │  - 对话管理      │  │  - CRUD接口     │  │  - 任务分析      │ │
│  │  - 消息历史      │  │  - 类型安全     │  │  - 智能建议      │ │
│  └────────┬────────┘  └────────┬────────┘  └─────────────────┘ │
└───────────┼─────────────────────┼───────────────────────────────┘
            │                     │
            ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Function Calling Layer                        │
│           ┌───────────────────────────────────┐                 │
│           │   FunctionCallHandlerFactory      │                 │
│           └─────────────┬─────────────────────┘                 │
│                         │                                        │
│    ┌────────────────────┼────────────────────┐                 │
│    ▼                    ▼                    ▼                  │
│  ┌─────────┐      ┌──────────┐      ┌──────────┐              │
│  │ Create  │      │  Read    │      │ Update   │              │
│  │ Handler │      │  Handler │      │ Handler  │              │
│  └─────────┘      └──────────┘      └──────────┘              │
│                          ▼                                       │
│                    ┌──────────┐                                 │
│                    │  Delete  │                                 │
│                    │  Handler │                                 │
│                    └──────────┘                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ TaskRepository  │  │ Firebase AI     │  │  Cache Service  │ │
│  │                 │  │  Service        │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 实施步骤

## 阶段 1: 基础设施重构 (3-4天)

### 📝 任务清单

- [ ] 1.1 创建统一的任务操作协议
- [ ] 1.2 创建统一的 DTO 模型
- [ ] 1.3 创建类型安全的通知管理器
- [ ] 1.4 提取公共工具类

---

### 1.1 创建统一的任务操作协议

**文件**: 新建 `Modo/Protocols/AITaskOperationProtocol.swift`

```swift
// ============================================================
// STEP 1.1: 创建统一的任务操作接口
// ============================================================

import Foundation

/// AI 任务操作类型
enum AITaskOperationType {
    case create
    case read
    case update
    case delete
    case batch
}

/// AI 任务操作结果
enum AITaskOperationResult {
    case success(AITaskOperationResponse)
    case failure(Error)
}

/// AI 任务操作响应
struct AITaskOperationResponse {
    let operation: AITaskOperationType
    let data: Any?
    let message: String?
}

/// AI 任务操作协议
protocol AITaskOperationProtocol {
    /// 执行任务操作
    /// - Parameters:
    ///   - operation: 操作类型
    ///   - parameters: 操作参数
    ///   - completion: 完成回调
    func execute(
        operation: AITaskOperationType,
        parameters: [String: Any],
        completion: @escaping (AITaskOperationResult) -> Void
    )
}

/// AI 任务 CRUD 协议
protocol AITaskCRUDProtocol {
    /// 创建任务
    func createTasks(_ tasks: [AITaskDTO], completion: @escaping (Result<[UUID], Error>) -> Void)
    
    /// 查询任务
    func queryTasks(params: TaskQueryParams, completion: @escaping (Result<[AITaskDTO], Error>) -> Void)
    
    /// 更新任务
    func updateTask(_ taskId: UUID, updates: TaskUpdateParams, completion: @escaping (Result<AITaskDTO, Error>) -> Void)
    
    /// 删除任务
    func deleteTask(_ taskId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 批量操作
    func batchOperations(_ operations: [TaskBatchOperation], completion: @escaping (Result<[AITaskDTO], Error>) -> Void)
}
```

---

### 1.2 创建统一的 DTO 模型

**文件**: 新建 `Modo/Models/AI/AITaskDTO.swift`

```swift
// ============================================================
// STEP 1.2: 创建统一的数据传输对象
// ============================================================

import Foundation

/// AI 任务数据传输对象（统一所有 AI 服务的数据格式）
struct AITaskDTO: Codable, Identifiable {
    let id: UUID
    let type: TaskType
    let title: String
    let subtitle: String?
    let date: Date
    let time: String
    let category: Category
    
    // Fitness specific
    var exercises: [Exercise]?
    var totalDuration: Int? // minutes
    
    // Nutrition specific
    var meals: [Meal]?
    var totalCalories: Int?
    
    // Metadata
    var isAIGenerated: Bool
    var source: String? // "coach", "main_page", "add_task"
    var createdAt: Date
    
    enum TaskType: String, Codable {
        case workout
        case nutrition
        case custom
    }
    
    enum Category: String, Codable {
        case fitness
        case diet
        case others
    }
    
    struct Exercise: Codable {
        let name: String
        let sets: Int
        let reps: String
        let restSec: Int
        let durationMin: Int
        let calories: Int
        let targetRPE: Int?
        let alternatives: [String]?
    }
    
    struct Meal: Codable {
        let name: String
        let time: String
        let foods: [Food]
        let totalCalories: Int
        let macros: Macros?
    }
    
    struct Food: Codable {
        let name: String
        let portion: String
        let calories: Int
        let macros: Macros?
    }
    
    struct Macros: Codable {
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}

// MARK: - Conversion Extensions

extension AITaskDTO {
    /// 从 TaskItem 转换
    static func from(_ taskItem: TaskItem) -> AITaskDTO {
        let type: TaskType = taskItem.category == .fitness ? .workout : .nutrition
        
        let exercises: [Exercise]? = taskItem.fitnessEntries.isEmpty ? nil : taskItem.fitnessEntries.map { entry in
            Exercise(
                name: entry.name,
                sets: Int(entry.setsText) ?? 0,
                reps: entry.repsText,
                restSec: Int(entry.restText) ?? 60,
                durationMin: Int(entry.durationText) ?? 0,
                calories: Int(entry.caloriesText) ?? 0,
                targetRPE: nil,
                alternatives: nil
            )
        }
        
        let meals: [Meal]? = taskItem.dietEntries.isEmpty ? nil : [
            Meal(
                name: taskItem.title,
                time: taskItem.time,
                foods: taskItem.dietEntries.map { entry in
                    Food(
                        name: entry.name,
                        portion: "1 serving",
                        calories: Int(entry.caloriesText) ?? 0,
                        macros: nil
                    )
                },
                totalCalories: Int(taskItem.dietEntries.reduce(0) { $0 + (Int($1.caloriesText) ?? 0) }),
                macros: nil
            )
        ]
        
        return AITaskDTO(
            id: taskItem.id,
            type: type,
            title: taskItem.title,
            subtitle: taskItem.subtitle,
            date: taskItem.timeDate,
            time: taskItem.time,
            category: Category(rawValue: taskItem.category.rawValue) ?? .others,
            exercises: exercises,
            totalDuration: exercises?.reduce(0, { $0 + $1.durationMin }),
            meals: meals,
            totalCalories: meals?.first?.totalCalories,
            isAIGenerated: taskItem.isAIGenerated,
            source: nil,
            createdAt: taskItem.createdAt
        )
    }
    
    /// 转换为 TaskItem
    func toTaskItem() -> TaskItem {
        let taskCategory: TaskCategory
        switch category {
        case .fitness:
            taskCategory = .fitness
        case .diet:
            taskCategory = .diet
        case .others:
            taskCategory = .others
        }
        
        let dietEntries: [DietEntry] = meals?.flatMap { meal in
            meal.foods.map { food in
                DietEntry(
                    name: food.name,
                    caloriesText: String(food.calories)
                )
            }
        } ?? []
        
        let fitnessEntries: [FitnessEntry] = exercises?.map { exercise in
            FitnessEntry(
                name: exercise.name,
                caloriesText: String(exercise.calories),
                setsText: String(exercise.sets),
                repsText: exercise.reps,
                restText: String(exercise.restSec),
                durationText: String(exercise.durationMin)
            )
        } ?? []
        
        return TaskItem(
            id: id,
            title: title,
            subtitle: subtitle ?? "",
            time: time,
            timeDate: date,
            endTime: nil,
            meta: "",
            isDone: false,
            emphasisHex: taskCategory == .fitness ? "#6366F1" : "#F59E0B",
            category: taskCategory,
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries,
            createdAt: createdAt,
            updatedAt: Date(),
            isAIGenerated: isAIGenerated,
            isDailyChallenge: false
        )
    }
    
    /// 从 AIGeneratedTask 转换
    static func from(_ aiTask: AIGeneratedTask, source: String = "main_page") -> AITaskDTO {
        let exercises: [Exercise]? = aiTask.exercises.isEmpty ? nil : aiTask.exercises.map { ex in
            Exercise(
                name: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                restSec: ex.restSec,
                durationMin: ex.durationMin,
                calories: ex.calories,
                targetRPE: nil,
                alternatives: nil
            )
        }
        
        let meals: [Meal]? = aiTask.meals.isEmpty ? nil : aiTask.meals.map { meal in
            Meal(
                name: meal.name,
                time: meal.time,
                foods: meal.foodItems.map { food in
                    Food(
                        name: food.name,
                        portion: "1 serving",
                        calories: food.calories,
                        macros: nil
                    )
                },
                totalCalories: meal.totalCalories,
                macros: nil
            )
        }
        
        return AITaskDTO(
            id: UUID(),
            type: aiTask.type == .workout ? .workout : .nutrition,
            title: aiTask.title,
            subtitle: nil,
            date: aiTask.date,
            time: meals?.first?.time ?? "09:00 AM",
            category: aiTask.type == .workout ? .fitness : .diet,
            exercises: exercises,
            totalDuration: aiTask.totalDuration,
            meals: meals,
            totalCalories: aiTask.totalCalories,
            isAIGenerated: true,
            source: source,
            createdAt: Date()
        )
    }
}

// MARK: - Query & Update Parameters

/// 任务查询参数
struct TaskQueryParams: Codable {
    let date: Date
    let dateRange: Int? // 查询几天（1-7）
    let category: AITaskDTO.Category?
    let isDone: Bool?
}

/// 任务更新参数
struct TaskUpdateParams: Codable {
    var title: String?
    var time: String?
    var date: Date?
    var isDone: Bool?
    var exercises: [AITaskDTO.Exercise]?
    var meals: [AITaskDTO.Meal]?
}

/// 批量操作
struct TaskBatchOperation: Codable {
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }
    
    let type: OperationType
    let taskId: UUID?
    let taskData: AITaskDTO?
    let updateParams: TaskUpdateParams?
}
```

---

### 1.3 创建类型安全的通知管理器

**文件**: 新建 `Modo/Services/Utilities/AINotificationManager.swift`

```swift
// ============================================================
// STEP 1.3: 创建类型安全的通知管理器
// ============================================================

import Foundation

/// AI 通知管理器 - 提供类型安全的通知机制
class AINotificationManager {
    static let shared = AINotificationManager()
    
    private init() {}
    
    // MARK: - Notification Names
    
    enum NotificationName: String {
        case taskCreateRequest = "AI.Task.Create.Request"
        case taskCreateResponse = "AI.Task.Create.Response"
        
        case taskQueryRequest = "AI.Task.Query.Request"
        case taskQueryResponse = "AI.Task.Query.Response"
        
        case taskUpdateRequest = "AI.Task.Update.Request"
        case taskUpdateResponse = "AI.Task.Update.Response"
        
        case taskDeleteRequest = "AI.Task.Delete.Request"
        case taskDeleteResponse = "AI.Task.Delete.Response"
        
        case taskBatchRequest = "AI.Task.Batch.Request"
        case taskBatchResponse = "AI.Task.Batch.Response"
        
        var name: Notification.Name {
            return Notification.Name(self.rawValue)
        }
    }
    
    // MARK: - Notification Payloads
    
    struct TaskCreatePayload: Codable {
        let tasks: [AITaskDTO]
        let requestId: String
    }
    
    struct TaskQueryPayload: Codable {
        let params: TaskQueryParams
        let requestId: String
    }
    
    struct TaskUpdatePayload: Codable {
        let taskId: UUID
        let updates: TaskUpdateParams
        let requestId: String
    }
    
    struct TaskDeletePayload: Codable {
        let taskId: UUID
        let requestId: String
    }
    
    struct TaskResponsePayload<T: Codable>: Codable {
        let requestId: String
        let success: Bool
        let data: T?
        let error: String?
    }
    
    // MARK: - Post Methods
    
    /// 发送创建任务请求
    func postTaskCreateRequest(_ tasks: [AITaskDTO], requestId: String = UUID().uuidString) {
        let payload = TaskCreatePayload(tasks: tasks, requestId: requestId)
        post(name: .taskCreateRequest, payload: payload)
    }
    
    /// 发送查询任务请求
    func postTaskQueryRequest(_ params: TaskQueryParams, requestId: String = UUID().uuidString) {
        let payload = TaskQueryPayload(params: params, requestId: requestId)
        post(name: .taskQueryRequest, payload: payload)
    }
    
    /// 发送更新任务请求
    func postTaskUpdateRequest(taskId: UUID, updates: TaskUpdateParams, requestId: String = UUID().uuidString) {
        let payload = TaskUpdatePayload(taskId: taskId, updates: updates, requestId: requestId)
        post(name: .taskUpdateRequest, payload: payload)
    }
    
    /// 发送删除任务请求
    func postTaskDeleteRequest(taskId: UUID, requestId: String = UUID().uuidString) {
        let payload = TaskDeletePayload(taskId: taskId, requestId: requestId)
        post(name: .taskDeleteRequest, payload: payload)
    }
    
    /// 发送响应
    func postResponse<T: Codable>(
        type: NotificationName,
        requestId: String,
        success: Bool,
        data: T?,
        error: String? = nil
    ) {
        let payload = TaskResponsePayload(
            requestId: requestId,
            success: success,
            data: data,
            error: error
        )
        post(name: type, payload: payload)
    }
    
    // MARK: - Observe Methods
    
    /// 监听创建任务请求
    func observeTaskCreateRequest(_ handler: @escaping (TaskCreatePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskCreateRequest, handler: handler)
    }
    
    /// 监听查询任务请求
    func observeTaskQueryRequest(_ handler: @escaping (TaskQueryPayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskQueryRequest, handler: handler)
    }
    
    /// 监听更新任务请求
    func observeTaskUpdateRequest(_ handler: @escaping (TaskUpdatePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskUpdateRequest, handler: handler)
    }
    
    /// 监听删除任务请求
    func observeTaskDeleteRequest(_ handler: @escaping (TaskDeletePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskDeleteRequest, handler: handler)
    }
    
    /// 监听响应
    func observeResponse<T: Codable>(
        type: NotificationName,
        handler: @escaping (TaskResponsePayload<T>) -> Void
    ) -> NSObjectProtocol {
        return observe(name: type, handler: handler)
    }
    
    // MARK: - Private Methods
    
    private func post<T: Codable>(name: NotificationName, payload: T) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to encode payload for notification: \(name.rawValue)")
            return
        }
        
        NotificationCenter.default.post(
            name: name.name,
            object: nil,
            userInfo: dict
        )
        
        print("📤 Posted notification: \(name.rawValue)")
    }
    
    private func observe<T: Codable>(
        name: NotificationName,
        handler: @escaping (T) -> Void
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: name.name,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
                  let payload = try? JSONDecoder().decode(T.self, from: jsonData) else {
                print("❌ Failed to decode payload for notification: \(name.rawValue)")
                return
            }
            
            print("📥 Received notification: \(name.rawValue)")
            handler(payload)
        }
    }
    
    /// 移除观察者
    func removeObserver(_ observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

---

### 1.4 提取公共工具类

**文件**: 新建 `Modo/Services/Utilities/AIServiceUtils.swift`

```swift
// ============================================================
// STEP 1.4: 提取公共工具类
// ============================================================

import Foundation

/// AI 服务工具类
class AIServiceUtils {
    
    // MARK: - Date Formatting
    
    /// 日期格式化器（线程安全）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// 时间格式化器
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// 格式化日期为字符串 (YYYY-MM-DD)
    static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// 解析日期字符串
    static func parseDate(_ dateString: String) -> Date? {
        return dateFormatter.date(from: dateString)
    }
    
    /// 格式化时间为字符串 (HH:MM AM/PM)
    static func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    /// 解析时间字符串
    static func parseTime(_ timeString: String) -> Date? {
        return timeFormatter.date(from: timeString)
    }
    
    // MARK: - Meal Time Utilities
    
    /// 获取默认餐点时间
    static func getDefaultMealTime(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast":
            return "8:00 AM"
        case "lunch":
            return "12:00 PM"
        case "dinner":
            return "6:00 PM"
        case "snack":
            return "3:00 PM"
        default:
            return "12:00 PM"
        }
    }
    
    /// 检测餐点类型
    static func detectMealType(from text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("breakfast") {
            return "breakfast"
        } else if lowercased.contains("lunch") {
            return "lunch"
        } else if lowercased.contains("dinner") {
            return "dinner"
        } else if lowercased.contains("snack") {
            return "snack"
        }
        return nil
    }
    
    // MARK: - Calorie Utilities
    
    /// 计算总卡路里
    static func calculateTotalCalories(from entries: [AITaskDTO.Food]) -> Int {
        return entries.reduce(0) { $0 + $1.calories }
    }
    
    /// 计算总时长
    static func calculateTotalDuration(from exercises: [AITaskDTO.Exercise]) -> Int {
        return exercises.reduce(0) { $0 + $1.durationMin }
    }
    
    // MARK: - Validation Utilities
    
    /// 验证任务数据完整性
    static func validateTaskData(_ task: AITaskDTO) -> (isValid: Bool, error: String?) {
        if task.title.isEmpty {
            return (false, "Title cannot be empty")
        }
        
        if task.type == .workout && (task.exercises == nil || task.exercises!.isEmpty) {
            return (false, "Workout task must have exercises")
        }
        
        if task.type == .nutrition && (task.meals == nil || task.meals!.isEmpty) {
            return (false, "Nutrition task must have meals")
        }
        
        return (true, nil)
    }
    
    // MARK: - Category Utilities
    
    /// 获取类别图标
    static func getCategoryIcon(for category: AITaskDTO.Category) -> String {
        switch category {
        case .fitness:
            return "💪"
        case .diet:
            return "🍽️"
        case .others:
            return "📌"
        }
    }
    
    /// 获取类别颜色
    static func getCategoryColor(for category: AITaskDTO.Category) -> String {
        switch category {
        case .fitness:
            return "#6366F1" // Purple
        case .diet:
            return "#F59E0B" // Orange
        case .others:
            return "#8B5CF6" // Indigo
        }
    }
}
```

---

## 阶段 2: 核心服务重构 (4-5天)

### 📝 任务清单

- [ ] 2.1 创建 AIServiceCoordinator
- [ ] 2.2 重构 ModoCoachService (拆分职责)
- [ ] 2.3 创建 TaskOperationsService
- [ ] 2.4 创建 FunctionCallHandlerFactory

---

### 2.1 创建 AIServiceCoordinator

**文件**: 新建 `Modo/Services/AI/AIServiceCoordinator.swift`

```swift
// ============================================================
// STEP 2.1: 创建统一的 AI 服务协调器
// ============================================================

import Foundation
import SwiftData

/// AI 服务协调器 - 统一入口，协调所有 AI 相关操作
class AIServiceCoordinator {
    
    // MARK: - Singleton
    
    static let shared = AIServiceCoordinator()
    
    // MARK: - Dependencies
    
    private let chatService: ChatService
    private let taskOperations: TaskOperationsService
    private let notificationManager: AINotificationManager
    private let firebaseAI: FirebaseAIService
    
    private init(
        chatService: ChatService = ChatService(),
        taskOperations: TaskOperationsService = TaskOperationsService(),
        notificationManager: AINotificationManager = .shared,
        firebaseAI: FirebaseAIService = .shared
    ) {
        self.chatService = chatService
        self.taskOperations = taskOperations
        self.notificationManager = notificationManager
        self.firebaseAI = firebaseAI
        
        setupNotificationObservers()
    }
    
    // MARK: - Observers
    
    private var observers: [NSObjectProtocol] = []
    
    private func setupNotificationObservers() {
        // 监听任务操作请求
        let createObserver = notificationManager.observeTaskCreateRequest { [weak self] payload in
            self?.handleTaskCreateRequest(payload)
        }
        observers.append(createObserver)
        
        let queryObserver = notificationManager.observeTaskQueryRequest { [weak self] payload in
            self?.handleTaskQueryRequest(payload)
        }
        observers.append(queryObserver)
        
        let updateObserver = notificationManager.observeTaskUpdateRequest { [weak self] payload in
            self?.handleTaskUpdateRequest(payload)
        }
        observers.append(updateObserver)
        
        let deleteObserver = notificationManager.observeTaskDeleteRequest { [weak self] payload in
            self?.handleTaskDeleteRequest(payload)
        }
        observers.append(deleteObserver)
    }
    
    // MARK: - Public API
    
    /// 发送聊天消息（用于 Insight Page）
    func sendChatMessage(
        _ message: String,
        userProfile: UserProfile?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        chatService.sendMessage(message, userProfile: userProfile, completion: completion)
    }
    
    /// 生成任务（用于 Main Page）
    func generateTasks(
        for date: Date,
        missing: [String],
        userProfile: UserProfile?,
        onEachTask: @escaping (AITaskDTO) -> Void,
        onComplete: @escaping () -> Void
    ) {
        taskOperations.generateMissingTasks(
            missing: missing,
            for: date,
            userProfile: userProfile,
            onEachTask: onEachTask,
            onComplete: onComplete
        )
    }
    
    /// 查询任务
    func queryTasks(
        params: TaskQueryParams,
        completion: @escaping (Result<[AITaskDTO], Error>) -> Void
    ) {
        taskOperations.queryTasks(params: params, completion: completion)
    }
    
    /// 更新任务
    func updateTask(
        _ taskId: UUID,
        updates: TaskUpdateParams,
        completion: @escaping (Result<AITaskDTO, Error>) -> Void
    ) {
        taskOperations.updateTask(taskId, updates: updates, completion: completion)
    }
    
    /// 删除任务
    func deleteTask(
        _ taskId: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        taskOperations.deleteTask(taskId, completion: completion)
    }
    
    // MARK: - Request Handlers
    
    private func handleTaskCreateRequest(_ payload: AINotificationManager.TaskCreatePayload) {
        print("🎯 AIServiceCoordinator: Handling task create request")
        
        taskOperations.createTasks(payload.tasks) { result in
            switch result {
            case .success(let taskIds):
                self.notificationManager.postResponse(
                    type: .taskCreateResponse,
                    requestId: payload.requestId,
                    success: true,
                    data: taskIds
                )
            case .failure(let error):
                self.notificationManager.postResponse(
                    type: .taskCreateResponse,
                    requestId: payload.requestId,
                    success: false,
                    data: nil as [UUID]?,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    private func handleTaskQueryRequest(_ payload: AINotificationManager.TaskQueryPayload) {
        print("🎯 AIServiceCoordinator: Handling task query request")
        
        queryTasks(params: payload.params) { result in
            switch result {
            case .success(let tasks):
                self.notificationManager.postResponse(
                    type: .taskQueryResponse,
                    requestId: payload.requestId,
                    success: true,
                    data: tasks
                )
            case .failure(let error):
                self.notificationManager.postResponse(
                    type: .taskQueryResponse,
                    requestId: payload.requestId,
                    success: false,
                    data: nil as [AITaskDTO]?,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    private func handleTaskUpdateRequest(_ payload: AINotificationManager.TaskUpdatePayload) {
        print("🎯 AIServiceCoordinator: Handling task update request")
        
        updateTask(payload.taskId, updates: payload.updates) { result in
            switch result {
            case .success(let task):
                self.notificationManager.postResponse(
                    type: .taskUpdateResponse,
                    requestId: payload.requestId,
                    success: true,
                    data: task
                )
            case .failure(let error):
                self.notificationManager.postResponse(
                    type: .taskUpdateResponse,
                    requestId: payload.requestId,
                    success: false,
                    data: nil as AITaskDTO?,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    private func handleTaskDeleteRequest(_ payload: AINotificationManager.TaskDeletePayload) {
        print("🎯 AIServiceCoordinator: Handling task delete request")
        
        deleteTask(payload.taskId) { result in
            switch result {
            case .success:
                self.notificationManager.postResponse(
                    type: .taskDeleteResponse,
                    requestId: payload.requestId,
                    success: true,
                    data: true
                )
            case .failure(let error):
                self.notificationManager.postResponse(
                    type: .taskDeleteResponse,
                    requestId: payload.requestId,
                    success: false,
                    data: nil as Bool?,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        observers.forEach { notificationManager.removeObserver($0) }
    }
}
```

---

由于内容太长，我将继续在下一部分...

