# Achievement Statistics Implementation Plan

## 概述
本文档详细说明了如何实现所有成就解锁条件所需的统计数据收集逻辑。

## 实现优先级

### 优先级 1：基础条件（可立即实现）
- [x] `streak` - 已有 StreakService
- [x] `totalTasks` - 从 tasksByDate 统计
- [x] `fitnessTasks` - 从 tasksByDate 统计
- [x] `dietTasks` - 从 tasksByDate 统计
- [x] `aiTasks` - 从 tasksByDate 统计
- [x] `dietTasksAfter11PM` - 已实现时间判断
- [x] `timeOfDayTasks` - 已实现时间判断（before_7am, after_midnight）
- [x] `allTimePeriods` - 已实现时间判断

### 优先级 2：需要额外数据收集（中等难度）
- [x] `calorieAccuracy` - 已实现（必须完全相等）
- [x] `macroStreak` - 已实现宏量营养素计算
- [x] `allMacrosStreak` - 已实现宏量营养素计算
- [x] `dailyChallengeTotal` - 已实现统计
- [x] `dailyTasksTotal` - 已实现统计
- [x] `dailyChallengesStreak` - 已实现连续天数统计
- [x] `aiGeneratedTasksAdded` - 已实现统计
- [x] `dietTasksSkipped` - 已实现统计（连续超过目标1000卡路里）

### 优先级 3：需要历史记录（较难）
- [x] `streakRestarts` - 已实现 streak 历史追踪
- [x] `streakComeback` - 已实现 streak 历史追踪
- [x] `weekendOnlyStreak` - 已实现按周统计（仅在周末完成任务的连续周数）
- [x] `allCategoriesInWeek` - 已实现按周统计（连续周数内完成所有类别任务）
- [x] `consecutiveDaysSkipped` - 已实现每日完成记录统计
- [x] `almostPerfectDays` - 已实现每日完成记录统计

### 优先级 4：需要新功能追踪（暂时跳过）
- [ ] `remindersSnoozed` - 需要提醒系统集成
- [ ] `taskRescheduled` - 需要任务历史记录
- [ ] `aiPlansGenerated` - 需要 AI 服务集成
- [ ] `insightsPageVisits` - 需要页面访问追踪
- [ ] `aiGoalsCompleted` - 需要 AI 服务集成
- [ ] `aiFeatureUsage` - 需要多个功能追踪
- [ ] `aiPlanRegenerations` - 需要 AI 服务集成

---

## 详细实现计划

### 1. 时间段统计

#### 时间段定义
```swift
enum TimePeriod {
    case morning      // 6:00 - 12:00
    case afternoon    // 12:00 - 18:00
    case evening      // 18:00 - 22:00
    case night        // 22:00 - 6:00 (次日)
}
```

#### 实现方法
- 从 `TaskItem.timeDate` 提取时间
- 判断任务完成时间属于哪个时间段
- 统计各时间段完成的任务数
- 统计在 4 个时间段都完成任务的日期数

#### 需要实现的条件
- `timeOfDayTasks` (before_7am, after_midnight)
- `allTimePeriods`

---

### 2. 卡路里和宏量营养素统计

#### 数据来源
- **目标卡路里**: `UserProfile.dailyCalories` 或 `HealthCalculator.targetCalories()`
- **实际卡路里**: 从 `TaskItem.totalCalories` 累加（已完成的任务）
- **目标宏量营养素**: `HealthCalculator.recommendedMacros()`
  - 蛋白质: `UserProfile.dailyProtein` 或计算值
  - 碳水化合物: 计算值
  - 脂肪: 计算值
- **实际宏量营养素**: 从 `TaskItem.dietEntries` 计算

#### 实现方法
1. 获取用户目标值（从 UserProfile）
2. 计算每日实际值（从已完成任务）
3. 判断是否达标（卡路里 ±50，宏量营养素在范围内）
4. 统计连续达标天数

#### 需要实现的条件
- `calorieAccuracy` - 卡路里在目标 ±50 范围内的连续天数
- `macroStreak` (protein/carbs/fats) - 单个宏量营养素连续达标天数
- `allMacrosStreak` - 所有宏量营养素连续达标天数
- `dietTasksSkipped` - 连续超过目标卡路里 1000 的天数

---

### 3. Streak 相关统计

#### 数据来源
- `StreakService.calculateStreak()` - 当前 streak
- Firebase: `users/{userId}/streakHistory/` - streak 历史记录

#### 需要存储的数据
```swift
struct StreakHistory {
    var lastStreak: Int
    var maxStreak: Int
    var restartCount: Int
    var lastBreakDate: Date?
}
```

#### 实现方法
1. **streakRestarts**:
   - 每次计算 streak 时，对比上次的 streak 值
   - 如果当前 < 上次，说明中断了，restartCount++
   - 保存到 Firebase

2. **streakComeback**:
   - 记录中断前的最大 streak
   - 如果当前 streak >= 7 且之前中断过，触发

#### 需要实现的条件
- `streakRestarts` - 重新开始 streak 的次数
- `streakComeback` - 回归后达到指定天数

---

### 4. Daily Challenge 统计

#### 数据来源
- `TaskItem.isDailyChallenge` - 标记是否为每日挑战
- `TaskItem.isDone` - 是否完成

#### 实现方法
1. 统计 `isDailyChallenge == true && isDone == true` 的任务数
2. 统计连续完成每日挑战的天数
3. 统计 AI 生成的每日挑战任务数

#### 需要实现的条件
- `dailyChallengeTotal` - 完成的每日挑战总数
- `dailyTasksTotal` - 完成的每日任务总数
- `dailyChallengesStreak` - 连续完成每日挑战的天数
- `aiGeneratedTasksAdded` - 添加的 AI 生成每日任务总数

---

### 5. 周数统计

#### 时间段定义
- 一周：周一到周日（或任意连续 7 天）
- 周末：周六和周日

#### 需要存储的数据
```swift
struct WeeklyCompletion {
    var weekStartDate: Date
    var completedCategories: Set<String> // ["diet", "fitness", "others"]
    var weekendOnly: Bool // 是否只在周末完成任务
}
```

#### 实现方法
1. **weekendOnlyStreak**:
   - 按周分组任务
   - 检查每周是否只在周末（周六、周日）完成任务
   - 统计连续周数

2. **allCategoriesInWeek**:
   - 按周分组任务
   - 检查每周是否包含所有类别（diet, fitness, others）
   - 统计连续周数

#### 需要实现的条件
- `weekendOnlyStreak` - 仅在周末完成任务的连续周数
- `allCategoriesInWeek` - 连续周数内完成所有类别任务

---

### 6. Humor 成就统计

#### 需要存储的数据
```swift
struct DailyCompletion {
    var date: Date
    var tasksCompleted: Int
    var totalTasks: Int
    var allTasksSkipped: Bool
}
```

#### 实现方法
1. **consecutiveDaysSkipped**:
   - 检查每天是否有未完成的任务
   - 如果某天所有任务都未完成，计数++
   - 统计连续天数

2. **almostPerfectDays**:
   - 检查每天任务完成率
   - 如果完成 4/5 任务（80%），计数++
   - 统计总天数

#### 需要实现的条件
- [x] `consecutiveDaysSkipped` - 已实现（连续跳过所有任务的天数）
- [x] `almostPerfectDays` - 已实现（完成 4/5 任务的天数）

---

### 7. AI 功能统计（优先级 4 - 暂时跳过）

#### 需要追踪的事件
- AI 计划生成
- Insights 页面访问
- AI 目标完成
- AI 功能使用（meal scan, insights, plan generation）
- AI 计划重新生成

#### 实现方法
- 在各个功能点添加事件追踪
- 存储到 Firebase: `users/{userId}/aiUsage/`

#### 需要实现的条件（暂时跳过）
- `aiPlansGenerated`
- `insightsPageVisits`
- `aiGoalsCompleted`
- `aiFeatureUsage`
- `aiPlanRegenerations`

---

### 8. 其他统计（优先级 4 - 暂时跳过）

#### remindersSnoozed
- 需要提醒系统集成
- 追踪提醒延迟事件

#### taskRescheduled
- 需要任务历史记录
- 追踪任务重新安排事件

---

## 数据存储结构

### Firebase 数据结构

```
users/{userId}/
  ├── achievements/{achievementId}/
  │   ├── id: String
  │   ├── achievementId: String
  │   ├── status: String (locked/unlocked)
  │   ├── currentProgress: Int
  │   └── unlockedAt: Timestamp?
  │
  ├── streakHistory/
  │   ├── lastStreak: Int
  │   ├── maxStreak: Int
  │   ├── restartCount: Int
  │   └── lastBreakDate: Timestamp?
  │
  ├── dailyCompletion/{date}/
  │   ├── date: Timestamp
  │   ├── tasksCompleted: Int
  │   ├── totalTasks: Int
  │   ├── completedCategories: [String]
  │   ├── caloriesActual: Int
  │   ├── caloriesTarget: Int
  │   ├── macrosActual: {protein, carbs, fats}
  │   ├── macrosTarget: {protein, carbs, fats}
  │   └── allTasksSkipped: Bool
  │
  └── weeklyCompletion/{weekStartDate}/
      ├── weekStartDate: Timestamp
      ├── completedCategories: [String]
      └── weekendOnly: Bool
```

---

## 实现步骤

### Step 1: 扩展 AchievementStatistics 结构
- [x] 添加所有新统计字段
- [x] 实现 `value(for conditionType:)` 方法支持所有类型

### Step 2: 实现时间段统计
- [x] 创建时间段判断工具函数（TimePeriodHelper）
- [x] 实现 `timeOfDayTasks` 统计（before_7am, after_midnight）
- [x] 实现 `allTimePeriods` 统计
- [x] 实现 `dietTasksAfter11PM` 统计

### Step 3: 实现卡路里和宏量营养素统计
- [x] 创建卡路里计算工具函数（NutritionCalculator）
- [x] 创建宏量营养素计算工具函数（NutritionCalculator）
- [x] 实现 `calorieAccuracy` 统计（必须完全相等）
- [x] 实现 `macroStreak` 统计（protein/carbs/fats，±5% 范围）
- [x] 实现 `allMacrosStreak` 统计（所有宏量营养素连续达标）
- [x] 实现 `dietTasksSkipped` 统计（连续超过目标1000卡路里）

### Step 4: 实现 Streak 历史追踪
- [x] 创建 StreakHistory 数据结构（StreakHistoryService）
- [x] 实现 streak 历史保存到 Firebase
- [x] 实现 `streakRestarts` 统计（追踪 streak 中断次数）
- [x] 实现 `streakComeback` 统计（回归后达到指定天数，需要 >= 7 天且之前中断过）

### Step 5: 实现 Daily Challenge 统计
- [x] 实现 `dailyChallengeTotal` 统计
- [x] 实现 `dailyTasksTotal` 统计
- [x] 实现 `dailyChallengesStreak` 统计（连续完成所有每日挑战的天数）
- [x] 实现 `aiGeneratedTasksAdded` 统计

### Step 6: 实现周数统计
- [x] 创建周数计算工具函数（WeekHelper）
- [x] 实现 `weekendOnlyStreak` 统计（仅在周末完成任务的连续周数）
- [x] 实现 `allCategoriesInWeek` 统计（连续周数内完成所有类别任务）

### Step 7: 实现 Humor 成就统计
- [x] 实现每日完成记录（从 tasksByDate 计算每日完成率）
- [x] 实现 `consecutiveDaysSkipped` 统计（连续跳过所有任务的天数）
- [x] 实现 `almostPerfectDays` 统计（完成 4/5 任务的天数，80% 完成率）

### Step 8: 更新 AchievementStatisticsCollector
- [x] 集成所有新的统计收集逻辑
- [x] 优化性能（使用异步版本获取完整统计，包括 streak 历史）

### Step 9: 更新 AchievementService
- [x] 支持所有新的条件类型
- [x] 处理带参数的条件（macro, timeWindow）

### Step 10: 实现解锁逻辑
- [x] 更新 `checkAndUnlockAchievements` 方法支持所有条件类型
- [x] 实现条件判断逻辑（包括带参数的条件）
- [x] 实现解锁状态更新和保存
- [x] 实现解锁队列管理（AchievementUnlockManager）
- [x] 集成解锁动画触发

### Step 11: 集成到应用
- [x] 在适当时机触发统计收集（使用异步版本，支持 userProfile 和 previousStreak）
- [x] 在适当时机触发成就检查（任务完成时、App 启动时）
- [x] 在 MainPageView 中添加 AchievementUnlockContainer
- [ ] 测试完整解锁流程（需要用户测试）

### Step 12: 测试
- [ ] 单元测试每个统计收集逻辑
- [ ] 单元测试解锁逻辑
- [ ] 集成测试成就解锁流程
- [ ] 边界测试

---

## 解锁逻辑实现计划

### 概述
在所有统计收集逻辑完成后，需要实现完整的成就解锁逻辑，包括：
1. 检查成就是否满足解锁条件
2. 更新成就状态
3. 触发解锁动画
4. 保存解锁记录

### 解锁检查流程

#### 1. 触发时机
成就检查应在以下时机触发：
- **任务完成时**: 用户完成一个任务后
- **每日结算时**: 午夜结算每日完成状态时
- **App 启动时**: 检查是否有遗漏的解锁
- **Streak 变化时**: Streak 值更新时
- **挑战完成时**: 完成每日挑战时

#### 2. 检查流程
```
1. 收集当前统计数据 (AchievementStatistics)
   ↓
2. 获取用户所有成就进度 (getUserAchievements)
   ↓
3. 遍历所有成就 (Achievement.allAchievements)
   ↓
4. 对每个未解锁的成就：
   a. 获取对应的统计值
   b. 检查是否满足解锁条件
   c. 如果满足：
      - 更新成就状态为 unlocked
      - 设置 unlockedAt 时间戳
      - 保存到 Firebase
      - 添加到解锁队列
   d. 如果不满足：
      - 更新 currentProgress
      - 保存到 Firebase
   ↓
5. 返回新解锁的成就列表
```

#### 3. 条件判断逻辑

##### 基础条件判断
```swift
// 简单数值比较
if statistics.value(for: condition.type) >= condition.targetValue {
    // 解锁
}
```

##### 带参数的条件判断
```swift
// macroStreak (需要 macro 参数)
if condition.type == .macroStreak {
    let macroValue = statistics.macroStreak(for: condition.macro)
    if macroValue >= condition.targetValue {
        // 解锁
    }
}

// timeOfDayTasks (需要 timeWindow 参数)
if condition.type == .timeOfDayTasks {
    let timeValue = statistics.timeOfDayTasks(for: condition.timeWindow)
    if timeValue >= condition.targetValue {
        // 解锁
    }
}
```

#### 4. 解锁队列管理

##### 使用 AchievementUnlockManager
- 当成就解锁时，调用 `queueUnlock(achievement:userAchievement:)`
- Manager 会自动管理队列，按顺序显示解锁动画
- 每个解锁动画显示完成后，自动显示下一个

##### 队列处理流程
```
解锁事件发生
   ↓
添加到队列
   ↓
如果当前没有显示动画，立即显示第一个
   ↓
用户关闭动画
   ↓
延迟 0.3 秒
   ↓
显示下一个（如果有）
```

#### 5. 解锁状态保存

##### Firebase 数据结构
```
users/{userId}/achievements/{achievementId}/
  - id: String
  - achievementId: String
  - status: "unlocked" | "locked"
  - currentProgress: Int
  - unlockedAt: Timestamp (可选)
```

##### 保存时机
- 成就解锁时立即保存
- 进度更新时保存（即使未解锁）

#### 6. 解锁动画集成

##### 在 MainPageView 中添加
```swift
ZStack {
    // ... 现有内容
    
    // 成就解锁动画容器
    AchievementUnlockContainer(
        onViewDetails: { achievement in
            // 跳转到成就详情页面
        }
    )
}
```

##### 动画显示流程
1. AchievementUnlockManager 检测到新解锁
2. 设置 `isShowing = true`
3. AchievementUnlockContainer 显示 AchievementUnlockView
4. 播放解锁动画
5. 用户点击关闭或查看详情
6. 触发 `onDismiss()`，显示下一个（如果有）

### 实现步骤

#### Step 1: 更新 AchievementService.checkAndUnlockAchievements
- [ ] 支持所有新的条件类型
- [ ] 实现带参数的条件判断（macro, timeWindow）
- [ ] 实现进度更新逻辑
- [ ] 实现解锁状态更新逻辑

#### Step 2: 实现条件判断辅助方法
- [ ] 创建 `getValueForCondition(condition:statistics:)` 方法
- [ ] 处理所有条件类型的值获取
- [ ] 处理带参数的条件

#### Step 3: 更新 AchievementStatistics.value(for:)
- [ ] 支持所有新的条件类型
- [ ] 返回对应的统计值

#### Step 4: 集成解锁队列
- [ ] 在 AchievementService 中调用 AchievementUnlockManager
- [ ] 确保解锁事件正确添加到队列

#### Step 5: 在应用中集成
- [ ] 在 MainPageView 中添加 AchievementUnlockContainer
- [ ] 在适当时机调用 AchievementCheckTrigger
- [ ] 测试完整流程

#### Step 6: 错误处理和边界情况
- [ ] 处理数据缺失情况
- [ ] 处理并发解锁情况
- [ ] 处理网络错误情况

### 注意事项

1. **性能优化**:
   - 批量检查成就，避免逐个查询
   - 只检查未解锁的成就
   - 缓存统计数据

2. **数据一致性**:
   - 确保解锁状态正确保存
   - 确保进度值正确更新
   - 处理保存失败的情况

3. **用户体验**:
   - 解锁动画不要打断用户操作
   - 多个成就按顺序显示
   - 提供跳过选项

4. **测试**:
   - 测试各种解锁条件
   - 测试并发解锁
   - 测试边界情况

---

## 注意事项

1. **性能优化**:
   - 批量查询 Firebase 数据
   - 缓存常用统计数据
   - 异步处理复杂计算

2. **数据一致性**:
   - 确保每日完成记录在午夜结算时保存
   - 确保 streak 历史及时更新

3. **向后兼容**:
   - 新字段使用可选值
   - 提供默认值

4. **错误处理**:
   - 处理数据缺失情况
   - 处理计算错误

---

## 待确认事项

1. **时间段定义**: 确认时间段划分是否符合需求 - （符合）
2. **周数计算**: 确认是按自然周（周一到周日）还是任意连续 7 天 - （自然周）
3. **宏量营养素范围**: 确认达标范围（±5%? ±10%?） - 完全吻合
4. **卡路里精确度**: 确认 ±50 卡路里的范围是否合适-  就必须完全一样
5. **AI 功能追踪**: 确认何时开始实现优先级 4 的功能 - 先忽略，TODO

---

## 更新日志

