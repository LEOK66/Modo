# ModoCoachService 重构计划

## 📊 当前状态分析

**文件大小**: 1,379 行代码  
**问题**: 违反单一职责原则，包含过多职责

---

## 🔍 职责分析

### 当前 ModoCoachService 的职责：

| 职责 | 行数估计 | 问题 |
|------|---------|------|
| 1. 消息管理 (CRUD) | ~150 | ✅ 核心职责 |
| 2. AI 对话协调 | ~200 | ✅ 核心职责 |
| 3. Function Call 处理 | ~300 | ⚠️ 应该委托给 Handler |
| 4. Legacy Functions (workout/nutrition) | ~400 | ⚠️ 应该独立服务 |
| 5. 图片分析 | ~100 | ✅ 已委托给 ImageAnalysisService |
| 6. 内容审核 | ~80 | ✅ 已委托给 ContentModerationService |
| 7. 任务创建逻辑 | ~150 | ⚠️ 应该独立服务 |

**总计**: ~1,380 行

---

## 🎯 重构目标

### 1. **保留 - ModoCoachService 核心职责**
- 管理聊天消息列表 (`@Published var messages`)
- 管理处理状态 (`@Published var isProcessing`)
- SwiftData 持久化
- 作为 UI 和 AI 服务的协调者

**目标行数**: ~300-400 行

### 2. **提取 - LegacyPlanService**
负责旧的 plan generation functions：
- `generate_workout_plan`
- `generate_nutrition_plan`
- `generate_multi_day_plan`
- 创建 workout 和 nutrition 任务

**预计行数**: ~500 行

### 3. **提取 - AIResponseCoordinator**
负责 AI 响应的路由和处理：
- 检测响应类型（text/function call）
- 路由到合适的 handler
- 管理 Function Call 生命周期

**预计行数**: ~200 行

### 4. **提取 - MessageHistoryManager**
负责消息历史管理：
- 加载历史
- 保存消息
- 清除历史
- 格式转换

**预计行数**: ~150 行

---

## 📐 重构后的架构

```
┌─────────────────────────────────────────────────────────┐
│                    ModoCoachService                      │
│                    (300-400 lines)                       │
│                                                          │
│  核心职责:                                                │
│  - @Published var messages                              │
│  - @Published var isProcessing                          │
│  - UI 协调                                               │
│  - 委托具体工作给专门的服务                                │
└─────────────────────────────────────────────────────────┘
           ↓ 委托给
┌──────────────────┬──────────────────┬──────────────────┐
│ MessageHistory   │ AIResponse       │ LegacyPlan       │
│ Manager          │ Coordinator      │ Service          │
│ (150 lines)      │ (200 lines)      │ (500 lines)      │
│                  │                  │                  │
│ • 加载历史        │ • 路由响应        │ • Workout plan   │
│ • 保存消息        │ • Function call  │ • Nutrition plan │
│ • 清除历史        │ • CRUD/Legacy    │ • Multi-day plan │
└──────────────────┴──────────────────┴──────────────────┘
```

---

## 🔨 重构步骤

### Phase 1: 提取 LegacyPlanService ⭐️ 优先

#### 文件: `LegacyPlanService.swift`

```swift
import Foundation

/// Legacy Plan Generation Service
///
/// Handles old-style plan generation functions:
/// - generate_workout_plan
/// - generate_nutrition_plan
/// - generate_multi_day_plan
class LegacyPlanService {
    
    // MARK: - Dependencies
    private let firebaseAIService: FirebaseAIService
    private let taskCreationService: TaskCreationService
    
    init(
        firebaseAIService: FirebaseAIService = .shared,
        taskCreationService: TaskCreationService = .init()
    ) {
        self.firebaseAIService = firebaseAIService
        self.taskCreationService = taskCreationService
    }
    
    // MARK: - Handle Function Calls
    
    func handleWorkoutPlan(
        arguments: String,
        userProfile: UserProfile?,
        completion: @escaping (String) -> Void
    ) {
        // 从 ModoCoachService.handleWorkoutPlanFunction() 移过来
    }
    
    func handleNutritionPlan(
        arguments: String,
        userProfile: UserProfile?,
        completion: @escaping (String) -> Void
    ) {
        // 从 ModoCoachService.handleNutritionPlanFunction() 移过来
    }
    
    func handleMultiDayPlan(
        arguments: String,
        userProfile: UserProfile?,
        completion: @escaping (String) -> Void
    ) {
        // 从 ModoCoachService.handleMultiDayPlanFunction() 移过来
    }
    
    // MARK: - Task Creation
    
    func createWorkoutTasks(
        _ workoutPlan: WorkoutPlanData,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 任务创建逻辑
    }
    
    func createNutritionTasks(
        _ nutritionPlan: NutritionPlanData,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 任务创建逻辑
    }
}
```

**移动的方法**:
- `handleWorkoutPlanFunction()`
- `handleNutritionPlanFunction()`
- `handleMultiDayPlanFunction()`
- `createNutritionTasksFromFunction()`
- `getDefaultMealTime()`
- 相关的结构体和解析逻辑

---

### Phase 2: 提取 MessageHistoryManager

#### 文件: `MessageHistoryManager.swift`

```swift
import Foundation
import SwiftData

/// Message History Manager
///
/// Manages chat message persistence and retrieval
class MessageHistoryManager {
    
    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    private var lastLoadedUserId: String?
    
    // MARK: - Load History
    
    func loadHistory(
        from context: ModelContext,
        userId: String
    ) -> [FirebaseChatMessage] {
        // 从 ModoCoachService.loadHistory() 移过来
    }
    
    // MARK: - Save Message
    
    func saveMessage(
        _ message: FirebaseChatMessage,
        context: ModelContext,
        userId: String
    ) {
        // 从 ModoCoachService.saveMessage() 移过来
    }
    
    // MARK: - Clear History
    
    func clearHistory(context: ModelContext, userId: String) {
        // 从 ModoCoachService.clearHistory() 移过来
    }
    
    // MARK: - Convert to ChatMessage Format
    
    func convertToChatMessages(
        messages: [FirebaseChatMessage],
        includeSystemPrompt: Bool,
        userProfile: UserProfile?
    ) -> [ChatMessage] {
        // 从 ModoCoachService.convertToChatMessages() 移过来
    }
}
```

**移动的方法**:
- `loadHistory()`
- `saveMessage()`
- `clearHistory()`
- `convertToChatMessages()`
- `shouldSendUserInfo()`
- `sendInitialUserInfo()`

---

### Phase 3: 提取 AIResponseCoordinator

#### 文件: `AIResponseCoordinator.swift`

```swift
import Foundation

/// AI Response Coordinator
///
/// Routes AI responses to appropriate handlers
class AIResponseCoordinator {
    
    // MARK: - Dependencies
    private let functionCoordinator: AIFunctionCallCoordinator
    private let legacyPlanService: LegacyPlanService
    private let notificationManager: AINotificationManager
    
    // MARK: - State
    private var pendingFunctionCall: PendingFunctionInfo?
    private var functionResponseObservers: [NSObjectProtocol] = []
    
    init(
        functionCoordinator: AIFunctionCallCoordinator = .shared,
        legacyPlanService: LegacyPlanService,
        notificationManager: AINotificationManager = .shared
    ) {
        self.functionCoordinator = functionCoordinator
        self.legacyPlanService = legacyPlanService
        self.notificationManager = notificationManager
        
        setupObservers()
    }
    
    // MARK: - Handle Response
    
    func handleAIResponse(
        _ response: ChatCompletionResponse,
        userProfile: UserProfile?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 从 ModoCoachService.handleAIResponse() 移过来
        // 路由到 CRUD handler 或 Legacy service
    }
    
    // MARK: - Function Call Handling
    
    private func setupObservers() {
        // 从 ModoCoachService.setupFunctionResponseObservers() 移过来
    }
    
    private func handleFunctionResponse<T: Codable>(
        payload: AINotificationManager.TaskResponsePayload<T>
    ) {
        // 从 ModoCoachService.handleFunctionResponse() 移过来
    }
}
```

**移动的方法**:
- `handleAIResponse()`
- `handleFunctionCall()`
- `handleFunctionResponse()`
- `setupFunctionResponseObservers()`
- `sendFunctionResultToAI()`
- `formatFunctionResult()`

---

### Phase 4: 清理 ModoCoachService

#### 重构后的 ModoCoachService

```swift
import Foundation
import SwiftData
import Combine

class ModoCoachService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var messages: [FirebaseChatMessage] = []
    @Published var isProcessing: Bool = false
    
    // MARK: - Dependencies
    private let firebaseAIService: FirebaseAIService
    private let messageHistoryManager: MessageHistoryManager
    private let responseCoordinator: AIResponseCoordinator
    private let legacyPlanService: LegacyPlanService
    private let contentModerator: ContentModerationService
    private let imageAnalyzer: ImageAnalysisService
    
    // MARK: - Initialization
    
    init() {
        self.firebaseAIService = FirebaseAIService.shared
        self.messageHistoryManager = MessageHistoryManager()
        self.legacyPlanService = LegacyPlanService()
        self.responseCoordinator = AIResponseCoordinator(
            legacyPlanService: legacyPlanService
        )
        self.contentModerator = ContentModerationService()
        self.imageAnalyzer = ImageAnalysisService()
    }
    
    // MARK: - Public API
    
    func sendMessage(_ text: String, userProfile: UserProfile?) {
        // 简洁的实现，委托给专门的服务
        
        // 1. 内容审核
        if contentModerator.isInappropriate(text) {
            let refusal = contentModerator.generateRefusalMessage()
            addMessage(refusal, isFromUser: false)
            return
        }
        
        // 2. 添加用户消息
        addMessage(text, isFromUser: true)
        
        // 3. 处理 AI
        isProcessing = true
        Task {
            do {
                let history = messageHistoryManager.convertToChatMessages(
                    messages: messages,
                    includeSystemPrompt: true,
                    userProfile: userProfile
                )
                
                let response = try await firebaseAIService.sendChatRequest(...)
                
                responseCoordinator.handleAIResponse(response, ...) { result in
                    // 更新 UI
                }
            } catch {
                // 错误处理
            }
        }
    }
    
    func analyzeFoodImage(base64Image: String, userProfile: UserProfile?) async {
        // 委托给 imageAnalyzer
        isProcessing = true
        do {
            let result = try await imageAnalyzer.analyzeFoodImage(base64Image)
            addMessage(result, isFromUser: false)
        } catch {
            handleError(error)
        }
        isProcessing = false
    }
    
    func loadHistory(from context: ModelContext, userProfile: UserProfile?) {
        messages = messageHistoryManager.loadHistory(from: context, userId: ...)
    }
    
    // MARK: - Private Helpers
    
    private func addMessage(_ text: String, isFromUser: Bool) {
        let message = FirebaseChatMessage(content: text, isFromUser: isFromUser)
        messages.append(message)
        messageHistoryManager.saveMessage(message, context: ..., userId: ...)
    }
}
```

**保留的职责**:
- `@Published` 属性管理
- 公共 API (`sendMessage`, `analyzeFoodImage`, etc.)
- 协调各个服务
- UI 状态管理

**代码行数**: ~300-400 行

---

## 📋 重构检查清单

### Phase 1: LegacyPlanService
- [ ] 创建 `LegacyPlanService.swift`
- [ ] 移动 workout plan 处理逻辑
- [ ] 移动 nutrition plan 处理逻辑
- [ ] 移动 multi-day plan 处理逻辑
- [ ] 移动任务创建逻辑
- [ ] 测试 legacy functions

### Phase 2: MessageHistoryManager
- [ ] 创建 `MessageHistoryManager.swift`
- [ ] 移动历史加载逻辑
- [ ] 移动消息保存逻辑
- [ ] 移动清除历史逻辑
- [ ] 移动格式转换逻辑
- [ ] 测试消息持久化

### Phase 3: AIResponseCoordinator
- [ ] 创建 `AIResponseCoordinator.swift`
- [ ] 移动响应处理逻辑
- [ ] 移动 Function Call 路由
- [ ] 移动观察者设置
- [ ] 测试 CRUD + Legacy 路由

### Phase 4: ModoCoachService 清理
- [ ] 删除已移动的代码
- [ ] 更新依赖注入
- [ ] 简化公共 API
- [ ] 更新文档
- [ ] 全面测试

---

## ⚠️ 注意事项

### 1. 保持向后兼容
- ✅ 不改变公共 API 签名
- ✅ 保持 `@Published` 属性
- ✅ UI 层无需修改

### 2. 测试策略
- ✅ 每个 Phase 完成后测试
- ✅ 确保现有功能不受影响
- ✅ 重点测试 AI 对话流程

### 3. 渐进式重构
- ✅ 一次一个 Phase
- ✅ 每个 Phase 可独立提交
- ✅ 出问题可快速回滚

---

## 🎯 预期效果

### 重构前
- ModoCoachService: 1,379 行
- 职责混乱，难以维护
- 新功能难以添加

### 重构后
- ModoCoachService: ~350 行 ⬇️ 74% 
- MessageHistoryManager: ~150 行
- AIResponseCoordinator: ~200 行
- LegacyPlanService: ~500 行
- **总计**: ~1,200 行 (节省 180 行 + 更清晰的结构)

### 好处
- ✅ 单一职责原则
- ✅ 易于测试
- ✅ 易于维护
- ✅ 易于扩展
- ✅ 代码复用

---

## 📅 时间估计

- **Phase 1 (LegacyPlanService)**: 2-3 小时
- **Phase 2 (MessageHistoryManager)**: 1-2 小时
- **Phase 3 (AIResponseCoordinator)**: 1-2 小时
- **Phase 4 (清理)**: 1 小时
- **测试**: 2 小时

**总计**: 7-10 小时

---

**最后更新**: 2024-11-17  
**状态**: 计划阶段
**下一步**: 开始 Phase 1 - LegacyPlanService

