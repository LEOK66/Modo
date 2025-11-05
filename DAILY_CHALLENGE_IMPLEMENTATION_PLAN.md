# Daily Challenge 功能实现规划

## 📖 项目背景

### Modo 应用简介
Modo 是一款基于 SwiftUI 和 Firebase 的健康管理应用，帮助用户通过任务管理、AI 辅助和数据追踪来实现健康目标。应用的核心功能包括：
- **任务管理系统**：用户可以创建、管理和完成每日健康任务（饮食、运动、正念等）
- **AI 智能助手**：通过 Firebase AI 提供个性化建议和任务生成
- **数据追踪**：记录用户的卡路里消耗、运动数据和进度
- **用户画像**：收集和存储用户的基础健康信息（身高、体重、年龄、性别等）

### Daily Challenge 功能背景

#### 功能定位
Daily Challenge（每日挑战）是 Modo 应用中的激励功能，旨在通过每日一个特定挑战来提升用户参与度和健康习惯养成。该功能位于 **Profile 页面**，以卡片形式展示。

#### 现有实现状态
目前 Daily Challenge 的基础框架已经搭建完成，包括：

1. **核心服务**：`DailyChallengeService`
   - 管理当前挑战状态
   - 支持挑战的生成和刷新
   - 与 Firebase 同步挑战数据
   - 监听任务完成状态并更新挑战状态

2. **数据模型**：`DailyChallenge`
   - 包含字段：id, title, subtitle, emoji, type, targetValue, date
   - 支持不同类型：fitness, diet, mindfulness, other

3. **UI 展示**：`DailyChallengeCardView`（位于 ProfilePageView.swift）
   - 显示当前挑战信息
   - 提供 Reset Button（刷新挑战）
   - 提供 Accept Button（将挑战添加到任务列表）

4. **任务集成**：
   - 挑战可以转换为任务添加到主任务列表
   - 任务带有 `isDailyChallenge` 标记
   - 挑战任务在列表中显示特殊的 Trophy 徽章
   - 任务完成时会同步更新挑战完成状态

5. **Firebase 集成**：
   - 数据路径：`users/{userId}/dailyChallenges/{date}`
   - 支持挑战数据的云端存储和同步

#### 现有代码结构
```
Modo/
├── Services/
│   ├── DailyChallengeService.swift          # 核心服务（已实现基础功能）
│   ├── UserProfileService.swift             # 用户画像服务
│   ├── ProgressCalculationService.swift     # 进度计算服务
│   └── AI/
│       ├── FirebaseAIService.swift          # Firebase AI 调用
│       ├── AIPromptBuilder.swift            # AI Prompt 构建器
│       └── AIResponseParser.swift           # AI 响应解析器
├── UI/
│   └── MainPages/
│       ├── MainPageView.swift               # 主页面（任务列表）
│       └── ProfilePageView.swift            # 个人主页（包含 DailyChallengeCardView）
└── Resources/
    ├── exercises.json                       # 运动数据
    └── foods.json                           # 食物数据
```

#### 当前实现的关键逻辑

**1. 挑战生成流程**
```swift
DailyChallengeService.generateTodayChallenge()
  → 创建固定的步数挑战（10,000步）
  → 更新 currentChallenge 状态
  → 重置完成和添加状态
```

**2. 接受挑战流程**
```swift
用户点击 Accept Button
  → DailyChallengeService.addChallengeToTasks()
  → 发送通知到 MainPageView
  → MainPageView 接收通知并创建任务
  → 任务标记为 isDailyChallenge = true
```

**3. 完成同步流程**
```swift
用户在任务列表完成挑战任务
  → MainPageView 更新任务状态
  → 调用 DailyChallengeService.updateChallengeCompletion()
  → 更新 isChallengeCompleted 状态
  → 同步到 Firebase
```

### 待实现的三个核心需求

#### 需求来源
在基础功能测试和用户体验评估后，团队确定了三个关键的增强需求，以提升 Daily Challenge 功能的实用性和用户体验：

#### 需求1：完成状态管理
**问题：** 目前用户完成挑战后，Reset Button 仍然可点击，这在逻辑上不合理
**目标：** 
- 用户完成当天的挑战后，禁用 Reset Button
- 完成状态应该根据实际任务完成情况实时更新
- 提供清晰的视觉反馈表明挑战已完成

#### 需求2：AI 驱动的智能重置
**问题：** 当前 Reset 功能只生成固定的 10,000 步挑战，缺乏个性化
**目标：**
- 用户不喜欢当天的挑战时，可以点击 Reset 获取新挑战
- Reset 功能调用 AI，根据用户数据生成合理的个性化挑战
- AI 生成的挑战应考虑用户的历史数据、健康状况和偏好

#### 需求3：新用户友好体验
**问题：** 新用户或无数据用户可能收到不合理的挑战建议
**目标：**
- 检测用户是否有足够的基础数据（健康信息 + 历史任务）
- 无数据时显示引导提示，要求用户先在 Progress 页面输入信息
- 使用 blur 视觉效果锁定功能，直到用户完成数据输入

### 技术栈说明

#### 前端框架
- **SwiftUI**：构建声明式 UI
- **Combine**：响应式数据流和状态管理
- **SwiftData**：本地数据持久化（用于 UserProfile）

#### 后端服务
- **Firebase Authentication**：用户认证
- **Firebase Realtime Database**：云端数据存储和实时同步
- **Firebase AI (Vertex AI)**：AI 能力集成

#### 开发环境
- **Xcode**：主要开发工具
- **iOS 15.0+**：最低支持版本
- **Swift 5.9+**：编程语言

### 实现原则

1. **渐进增强**：在现有基础上逐步添加功能，避免破坏性修改
2. **用户优先**：所有设计决策以提升用户体验为首要目标
3. **数据驱动**：AI 生成和状态管理都基于真实的用户数据
4. **性能优化**：确保 AI 调用不影响应用响应速度
5. **错误优雅处理**：所有异步操作都有 fallback 机制

---

## 📋 实现顺序

**推荐顺序：需求3 → 需求2 → 需求1**

### 原因分析
1. **需求3 (新用户检测)** 应该最先实现，因为它是功能的入口门槛，决定了用户能否使用整个 Daily Challenge 功能
2. **需求2 (AI重置)** 是核心功能，需要在确认用户有数据后才能工作
3. **需求1 (完成后禁用)** 是在功能正常运行后的状态管理，应该最后实现以避免影响开发和测试流程

---

## 需求3：新用户状态检测与提示
**优先级：最高 ⭐⭐⭐**

### 3.1 数据检测模块
**任务：创建用户数据完整性检查服务**

- [ ] 在 `UserProfileService` 中添加方法检测用户是否有基础健康数据（身高、体重、年龄、性别）
- [ ] 在 `ProgressCalculationService` 或新建服务中检查用户是否有历史任务数据
- [ ] 创建一个 `UserDataValidator` 类来统一管理数据完整性检查
- [ ] 定义最低数据要求标准（例如：至少有基础健康信息 + 至少完成过1个任务）

**涉及文件：**
- `Modo/Services/UserProfileService.swift`
- `Modo/Services/ProgressCalculationService.swift`
- `Modo/Services/UserDataValidator.swift` (新建)

---

### 3.2 数据状态同步
**任务：在 DailyChallengeService 中集成数据检测**

- [ ] 在 `DailyChallengeService` 中添加 `@Published var hasMinimumUserData: Bool` 状态
- [ ] 在服务初始化时调用数据检测方法
- [ ] 监听用户数据变化（通过 Combine 或通知），实时更新 `hasMinimumUserData` 状态
- [ ] 添加日志记录数据检测结果，便于调试

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`

**代码要点：**
```swift
@Published var hasMinimumUserData: Bool = false
private var cancellables = Set<AnyCancellable>()

func checkUserDataAvailability() {
    // 检查用户基础信息
    // 检查历史任务数据
    // 更新 hasMinimumUserData 状态
}
```

---

### 3.3 UI状态展示
**任务：修改 DailyChallengeCardView 显示逻辑**

- [ ] 在 `DailyChallengeCardView` 中订阅 `hasMinimumUserData` 状态
- [ ] 创建一个新的 `EmptyStatePlaceholder` 组件显示提示信息
- [ ] 提示文案：引导用户去 Progress 页面输入数据（中英文）
- [ ] 为无数据状态添加一个 CTA 按钮跳转到 Progress 页面

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift` (DailyChallengeCardView 在此文件中)
- `Modo/UI/Components/Feedback/EmptyStatePlaceholder.swift` (新建)

**UI文案示例：**
- 中文：「开始你的挑战之旅」
- 副标题：「请先在进度页面输入你的健康数据，我们将为你定制专属挑战」
- 按钮：「去设置」

---

### 3.4 Blur 视觉效果
**任务：实现无数据时的模糊效果**

- [ ] 在 `DailyChallengeCardView` 中为 challenge 内容区域添加条件渲染
- [ ] 无数据时显示灰色占位内容（模拟 challenge 卡片）
- [ ] 应用 SwiftUI 的 `.blur(radius:)` 修饰符
- [ ] 添加一个覆盖层（overlay）显示锁定图标和提示文字
- [ ] 确保 blur 效果在有数据后能平滑过渡消失（使用动画）

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift`

**代码要点：**
```swift
ZStack {
    // Challenge content
    VStack {
        // ... challenge UI
    }
    .blur(radius: hasMinimumUserData ? 0 : 8)
    .disabled(!hasMinimumUserData)
    
    // Overlay for empty state
    if !hasMinimumUserData {
        VStack {
            Image(systemName: "lock.fill")
            Text("需要更多数据")
            Button("去设置") { /* navigate */ }
        }
    }
}
.animation(.easeInOut(duration: 0.3), value: hasMinimumUserData)
```

---

### 3.5 边界测试
**任务：测试各种用户状态**

- [ ] 测试完全新用户（无任何数据）
- [ ] 测试有基础信息但无任务历史的用户
- [ ] 测试有任务但无基础信息的用户
- [ ] 测试数据完整的老用户
- [ ] 测试从无数据到有数据的状态转换

**测试场景：**
1. 新注册用户，直接进入 Profile 页面查看 Daily Challenge
2. 用户在 Progress 页面输入数据后，返回查看 blur 效果是否消失
3. 用户删除所有数据后，检查 blur 效果是否重新出现

---

## 需求2：AI驱动的 Challenge 重置
**优先级：高 ⭐⭐**

### 2.1 AI Prompt 设计
**任务：设计 Daily Challenge 生成的 AI Prompt**

- [ ] 在 `AIPromptBuilder.swift` 中添加新方法 `buildDailyChallengePrompt()`
- [ ] Prompt 需要包含的上下文：
  - 用户基础信息（年龄、性别、身高、体重、BMI）
  - 用户历史任务统计（常做的运动类型、饮食偏好、任务完成率）
  - 用户近期表现（最近7天的任务数据）
  - 排除今天已生成过的 challenge（避免重复）
- [ ] 定义 AI 返回格式（JSON schema）：title, subtitle, emoji, type, targetValue, reasoning

**涉及文件：**
- `Modo/Services/AI/AIPromptBuilder.swift`

**Prompt 结构示例：**
```
你是一个专业的健康教练，需要为用户生成一个合理的每日挑战。

用户信息：
- 年龄：{age}
- 性别：{gender}
- BMI：{bmi}
- 健身水平：{fitness_level}

历史数据：
- 最常做的运动：{top_exercises}
- 平均每周完成任务数：{avg_tasks_per_week}
- 最近7天完成率：{completion_rate}

今日已生成的挑战：
{rejected_challenges}

请生成一个：
1. 具有挑战性但可实现的目标
2. 适合用户当前水平
3. 与用户习惯相关的挑战
4. 不要重复已生成的挑战

返回 JSON 格式：
{
  "title": "简短标题",
  "subtitle": "详细描述",
  "emoji": "相关emoji",
  "type": "fitness|diet|mindfulness",
  "targetValue": 数值目标,
  "reasoning": "为什么推荐这个挑战"
}
```

---

### 2.2 AI Response 解析
**任务：创建 Challenge 专用的响应解析器**

- [ ] 在 `AIResponseParser.swift` 中添加 `parseDailyChallengeResponse()` 方法
- [ ] 处理 AI 返回的 JSON 数据并转换为 `DailyChallenge` 对象
- [ ] 添加数据验证逻辑（确保 targetValue 合理、type 有效等）
- [ ] 添加 fallback 机制：AI 失败时返回默认的 challenge
- [ ] 添加错误处理和日志记录

**涉及文件：**
- `Modo/Services/AI/AIResponseParser.swift`

**代码要点：**
```swift
func parseDailyChallengeResponse(_ responseText: String) -> DailyChallenge? {
    // 1. 提取 JSON
    // 2. 验证数据完整性
    // 3. 转换为 DailyChallenge 对象
    // 4. 返回结果或 nil
}

func getDefaultChallenge() -> DailyChallenge {
    // Fallback challenge
    return DailyChallenge(
        id: UUID(),
        title: "10,000 steps",
        subtitle: "Walk 10,000 steps today",
        emoji: "👟",
        type: .fitness,
        targetValue: 10000,
        date: Date()
    )
}
```

---

### 2.3 Service 层集成 AI
**任务：在 DailyChallengeService 中集成 AI 生成**

- [ ] 在 `DailyChallengeService` 中添加 `generateAIChallenge()` 异步方法
- [ ] 调用 `FirebaseAIService` 获取 AI 生成的 challenge
- [ ] 添加 `@Published var isGeneratingChallenge: Bool` 加载状态
- [ ] 添加 `@Published var challengeGenerationError: String?` 错误状态
- [ ] 记录用户今日已生成过的 challenge（避免重复）
- [ ] 将 AI 生成的 challenge 保存到 Firebase

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`
- `Modo/Services/AI/FirebaseAIService.swift`

**代码结构：**
```swift
@Published var isGeneratingChallenge: Bool = false
@Published var challengeGenerationError: String? = nil
private var todayGeneratedChallenges: [DailyChallenge] = []

func generateAIChallenge() async {
    isGeneratingChallenge = true
    challengeGenerationError = nil
    
    do {
        // 1. 收集用户数据
        // 2. 构建 AI prompt
        // 3. 调用 AI 服务
        // 4. 解析响应
        // 5. 更新 currentChallenge
        // 6. 保存到 Firebase
    } catch {
        challengeGenerationError = error.localizedDescription
    }
    
    isGeneratingChallenge = false
}
```

---

### 2.4 Reset Button 逻辑
**任务：修改 Reset Button 的行为**

- [ ] 修改 `DailyChallengeCardView` 中的 Reset Button 点击事件
- [ ] 点击后调用 `challengeService.generateAIChallenge()`
- [ ] 显示加载状态（按钮显示 loading indicator）
- [ ] 成功后更新 UI 显示新的 challenge
- [ ] 失败后显示错误提示（Toast 或 Alert）
- [ ] 添加防抖逻辑（避免用户连续点击）

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift`

**UI交互流程：**
1. 用户点击 Reset 按钮
2. 按钮变为加载状态（旋转图标）
3. 调用 AI 生成
4. 成功：卡片内容平滑过渡到新 challenge
5. 失败：显示 Toast 提示用户重试

---

### 2.5 数据持久化
**任务：保存 AI 生成的 Challenge 历史**

- [ ] 在 Firebase 中设计数据结构存储每日生成的 challenge
- [ ] 路径：`users/{userId}/dailyChallenges/{date}/attempts/[]`
- [ ] 记录每次生成的 challenge 和时间戳
- [ ] 实现 challenge 的重新加载逻辑（用户退出后再进入）
- [ ] 添加每日生成次数限制（例如：最多重置5次）

**Firebase 数据结构：**
```json
{
  "users": {
    "{userId}": {
      "dailyChallenges": {
        "2025-11-05": {
          "currentChallenge": {
            "id": "...",
            "title": "...",
            "type": "fitness",
            "targetValue": 10000,
            "isCompleted": false,
            "isLocked": false
          },
          "attempts": [
            {
              "id": "...",
              "timestamp": 1699200000,
              "aiGenerated": true
            }
          ],
          "resetCount": 2
        }
      }
    }
  }
}
```

---

### 2.6 用户体验优化
**任务：优化 AI 生成的交互体验**

- [ ] 添加生成中的动画效果（卡片微动画或粒子效果）
- [ ] 成功生成后显示庆祝动画
- [ ] 添加触觉反馈（Haptic Feedback）
- [ ] 生成时禁用其他按钮（Accept button）
- [ ] 添加生成时间提示（"AI 正在为你定制挑战..."）

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift`

**动画建议：**
- 生成中：卡片轻微脉动 + 渐变背景流动
- 成功：Confetti 效果 + 卡片弹跳动画
- 触觉：使用 `UIImpactFeedbackGenerator`

---

## 需求1：完成状态管理
**优先级：中 ⭐**

### 1.1 完成状态检测
**任务：在 DailyChallengeService 中完善完成状态逻辑**

- [ ] 确认 `isChallengeCompleted` 状态的更新时机是否准确
- [ ] 添加完成时间记录 `completedAt: Date?`
- [ ] 将完成状态同步到 Firebase（已有基础实现，需验证）
- [ ] 添加完成状态的实时监听（其他设备完成时同步）

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`

**需要验证的逻辑：**
- 任务标记为完成时，DailyChallengeService 是否正确接收通知
- `updateChallengeCompletion()` 方法是否被正确调用
- Firebase 同步是否成功

---

### 1.2 完成后的数据更新
**任务：实现完成后 Challenge 的数据锁定**

- [ ] 在 Firebase 中添加 `isLocked: Bool` 字段标记 challenge 已完成
- [ ] 完成后禁止再次修改或删除该 challenge 对应的任务
- [ ] 确保完成状态跨日期不会被重置
- [ ] 添加完成时的数据快照（记录完成时的详细数据）

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`

**数据锁定逻辑：**
```swift
func lockChallenge() {
    guard let challenge = currentChallenge else { return }
    
    // 1. 设置 isLocked = true
    // 2. 保存完成时间
    // 3. 保存完成时的数据快照
    // 4. 同步到 Firebase
}
```

---

### 1.3 UI 状态更新
**任务：修改 DailyChallengeCardView 的完成状态 UI**

- [ ] 在 `DailyChallengeCardView` 中添加完成状态的条件渲染
- [ ] 完成后 Reset Button 变为禁用状态（灰色）
- [ ] 添加禁用状态的视觉提示（图标 + 文字说明）
- [ ] Accept Button 也应该禁用或隐藏
- [ ] 显示完成时间和完成徽章

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift`

**UI 状态变化：**
- Reset Button：灰色 + "已完成" 文字
- Accept Button：隐藏或显示"已添加"
- 卡片背景：添加金色边框或渐变背景
- 顶部添加：✅ "今日挑战已完成"徽章

---

### 1.4 Reset Button 禁用逻辑
**任务：实现 Reset Button 的禁用状态**

- [ ] 在 Button 上添加 `.disabled(challengeService.isChallengeCompleted)` 修饰符
- [ ] 禁用时显示不同的样式（降低透明度、改变颜色）
- [ ] 添加 Tooltip 或长按提示：解释为什么被禁用
- [ ] 确保禁用状态在整个卡片上都有视觉反馈

**涉及文件：**
- `Modo/UI/MainPages/ProfilePageView.swift`

**代码示例：**
```swift
Button(action: {
    Task {
        await challengeService.generateAIChallenge()
    }
}) {
    HStack {
        Image(systemName: "arrow.clockwise")
        Text(challengeService.isChallengeCompleted ? "已完成" : "换一个")
    }
}
.disabled(challengeService.isChallengeCompleted)
.opacity(challengeService.isChallengeCompleted ? 0.5 : 1.0)
```

---

### 1.5 跨日期逻辑
**任务：处理日期变化时的状态重置**

- [ ] 在 App 启动时检查当前日期是否为新的一天
- [ ] 新的一天到来时自动重置 `isChallengeCompleted` 和 `isChallengeAddedToTasks`
- [ ] 在 `DailyChallengeService` 中添加日期监听器（监听午夜12点）
- [ ] 午夜时自动生成新的 challenge（或清空旧的）
- [ ] 确保用户在跨日期时能看到新的 challenge

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`
- `Modo/ModoApp.swift`

**日期检测逻辑：**
```swift
func checkAndResetForNewDay() {
    let calendar = Calendar.current
    guard let challenge = currentChallenge else { return }
    
    let challengeDate = calendar.startOfDay(for: challenge.date)
    let today = calendar.startOfDay(for: Date())
    
    if challengeDate < today {
        // 新的一天，重置状态
        generateTodayChallenge()
    }
}
```

---

### 1.6 Firebase 数据同步
**任务：确保完成状态在所有设备间同步**

- [ ] 在 `DailyChallengeService` 中添加 Firebase 监听器
- [ ] 监听 `users/{userId}/dailyChallenges/{date}/isCompleted` 路径
- [ ] 其他设备完成时实时更新当前设备状态
- [ ] 添加同步冲突解决逻辑（以最新完成状态为准）

**涉及文件：**
- `Modo/Services/DailyChallengeService.swift`

**Firebase 监听代码：**
```swift
func observeChallengeCompletion() {
    guard let userId = Auth.auth().currentUser?.uid,
          let challenge = currentChallenge else { return }
    
    let dateString = dateFormatter.string(from: challenge.date)
    let ref = databaseRef
        .child("users/\(userId)/dailyChallenges/\(dateString)/isCompleted")
    
    ref.observe(.value) { snapshot in
        if let isCompleted = snapshot.value as? Bool {
            DispatchQueue.main.async {
                self.isChallengeCompleted = isCompleted
            }
        }
    }
}
```

---

### 1.7 用户提示
**任务：添加完成后的用户反馈**

- [ ] 完成 challenge 时显示庆祝动画（confetti 或类似效果）
- [ ] 显示 Toast 消息："太棒了！你完成了今日挑战！"
- [ ] 可选：显示奖励信息（如果有积分或徽章系统）
- [ ] 完成后卡片显示"已完成"状态的特殊样式（金色边框等）

**涉及文件：**
- `Modo/UI/MainPages/MainPageView.swift`
- `Modo/UI/Components/Feedback/Toast.swift`

**庆祝动画建议：**
- 使用 `ConfettiSwiftUI` 库或自定义粒子动画
- 触发时机：`isChallengeCompleted` 从 false 变为 true
- 动画持续时间：2-3秒

---

## 通用任务（所有需求共享）

### 测试与调试
- [ ] 为 `DailyChallengeService` 编写单元测试
- [ ] 测试各种边界情况（无网络、AI超时、数据异常）
- [ ] 在不同设备和iOS版本上测试
- [ ] 测试跨日期的状态转换
- [ ] 测试多设备同步

**测试文件：**
- `ModoTests/DailyChallengeServiceTests.swift` (新建)

---

### 代码优化
- [ ] 检查并移除 console.log / print 语句（或改为条件编译）
- [ ] 添加适当的错误处理和用户友好的错误消息
- [ ] 确保所有异步操作都在主线程更新UI
- [ ] 代码格式化和命名规范检查

---

### 文档
- [ ] 为新增的服务和方法添加代码注释
- [ ] 更新 README 记录 Daily Challenge 功能
- [ ] 创建 Firebase 数据结构文档
- [ ] 记录 AI Prompt 的设计思路

---

## 预估工作量

| 需求 | 任务数 | 预计时间 | 难度 |
|------|--------|----------|------|
| 需求3：新用户检测 | 8-12个 | 4-6小时 | 中 |
| 需求2：AI重置 | 12-15个 | 8-10小时 | 高 |
| 需求1：完成状态管理 | 10-14个 | 5-7小时 | 低 |
| **总计** | **30-41个** | **17-23小时** | - |

---

## 关键依赖

### 技术依赖
- Firebase Realtime Database（数据存储和同步）
- Firebase AI Service（AI 生成 challenge）
- Combine（状态管理和数据流）
- SwiftUI（UI 实现）

### 数据依赖
- UserProfile（用户基础信息）
- Tasks 历史数据（用户行为分析）
- ProgressCalculationService（数据统计）

### 服务依赖
- DailyChallengeService（核心服务）
- UserProfileService（用户数据）
- FirebaseAIService（AI 功能）
- AIPromptBuilder & AIResponseParser（AI 交互）

---

## 风险与注意事项

### 技术风险
1. **AI 响应延迟**：AI 生成可能需要 3-10秒，需要良好的加载状态提示
2. **Firebase 配额**：频繁的 AI 调用可能超出 Firebase 免费配额
3. **数据同步冲突**：多设备同时操作可能导致状态不一致
4. **跨日期边界**：午夜时分的状态切换需要仔细测试

### 用户体验风险
1. **新用户困惑**：需要清晰的引导流程
2. **AI 生成质量**：需要确保 AI 生成的 challenge 合理且可实现
3. **重复生成**：用户可能频繁点击 Reset 寻找"完美"的 challenge
4. **完成状态误判**：任务完成和 challenge 完成的映射关系要准确

---

## 成功标准

### 功能完整性
- ✅ 新用户能看到清晰的引导提示
- ✅ 有数据的用户能正常使用 Daily Challenge
- ✅ Reset 功能能生成合理的新 challenge
- ✅ 完成状态能正确管理和显示
- ✅ 所有状态在多设备间能正确同步

### 用户体验
- ✅ UI 流畅无卡顿
- ✅ 加载状态清晰
- ✅ 错误提示友好
- ✅ 动画效果精致
- ✅ 触觉反馈恰当

### 代码质量
- ✅ 代码结构清晰
- ✅ 注释完整
- ✅ 测试覆盖率 > 80%
- ✅ 无明显性能问题
- ✅ 遵循项目编码规范

---

## 相关文件清单

### 需要修改的现有文件
- `Modo/Services/DailyChallengeService.swift`
- `Modo/Services/UserProfileService.swift`
- `Modo/Services/ProgressCalculationService.swift`
- `Modo/Services/AI/AIPromptBuilder.swift`
- `Modo/Services/AI/AIResponseParser.swift`
- `Modo/Services/AI/FirebaseAIService.swift`
- `Modo/UI/MainPages/ProfilePageView.swift`
- `Modo/UI/MainPages/MainPageView.swift`

### 需要新建的文件
- `Modo/Services/UserDataValidator.swift`
- `Modo/UI/Components/Feedback/EmptyStatePlaceholder.swift`
- `ModoTests/DailyChallengeServiceTests.swift`

---

## 附录

### 参考链接
- [Firebase Realtime Database 文档](https://firebase.google.com/docs/database)
- [SwiftUI Blur Effect](https://developer.apple.com/documentation/swiftui/view/blur(radius:opaque:))
- [Combine Framework](https://developer.apple.com/documentation/combine)

### 设计资源
- 锁定图标：`lock.fill`
- 奖杯图标：`trophy.fill`
- 刷新图标：`arrow.clockwise`
- 完成图标：`checkmark.circle.fill`


