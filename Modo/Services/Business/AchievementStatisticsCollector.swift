import Foundation
import SwiftData

/// Helper class to collect achievement statistics from various data sources
class AchievementStatisticsCollector {
    private let streakService: StreakService
    private let streakHistoryService: StreakHistoryService
    private let modelContext: ModelContext
    
    init(
        streakService: StreakService = .shared,
        streakHistoryService: StreakHistoryService = StreakHistoryService(),
        modelContext: ModelContext
    ) {
        self.streakService = streakService
        self.streakHistoryService = streakHistoryService
        self.modelContext = modelContext
    }
    
    /// Collect all statistics for a user (synchronous version)
    /// Note: Streak history statistics (streakRestarts, streakComeback) will be 0 in this version
    /// Use collectStatisticsAsync for complete statistics including streak history
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Dictionary of dates to tasks (for task counting)
    ///   - userProfile: User profile for nutrition target calculations (optional)
    /// - Returns: AchievementStatistics
    func collectStatistics(
        userId: String,
        tasksByDate: [Date: [TaskItem]]? = nil,
        userProfile: UserProfile? = nil
    ) -> AchievementStatistics {
        var statistics = AchievementStatistics()
        
        // Get streak
        if let tasksByDate = tasksByDate {
            statistics.streak = streakService.calculateStreak(
                userId: userId,
                modelContext: modelContext,
                tasksByDate: tasksByDate
            )
        }
        
        // Count tasks from tasksByDate
        if let tasksByDate = tasksByDate {
            var totalTasks = 0
            var fitnessTasks = 0
            var dietTasks = 0
            var aiTasks = 0
            
            // Time-based statistics
            var dietTasksAfter11PM = 0
            var timeOfDayTasksBefore7AM = 0
            var timeOfDayTasksAfterMidnight = 0
            
            // Daily Challenge statistics
            var dailyChallengeTotal = 0
            var dailyTasksTotal = 0
            var aiGeneratedTasksAdded = 0
            
            // Track days with all time periods
            var daysWithAllTimePeriods = 0
            
            for (date, tasks) in tasksByDate {
                var completedPeriods: Set<TimePeriod> = []
                
                for task in tasks {
                    // Count daily challenge tasks (all tasks, completed or not)
                    if task.isDailyChallenge {
                        dailyTasksTotal += 1
                        if task.isDone {
                            dailyChallengeTotal += 1
                        }
                    }
                    
                    // Count AI-generated tasks added (all tasks, completed or not)
                    if task.isAIGenerated {
                        aiGeneratedTasksAdded += 1
                    }
                    
                    // Only count completed tasks for other statistics
                    guard task.isDone else { continue }
                    
                    totalTasks += 1
                    
                    // Check category
                    if task.category == .fitness {
                        fitnessTasks += 1
                    } else if task.category == .diet {
                        dietTasks += 1
                        
                        // Check if diet task completed after 11 PM
                        if TimePeriodHelper.isAfter11PM(task.timeDate) {
                            dietTasksAfter11PM += 1
                        }
                    }
                    
                    // Check if AI-generated (for completed tasks only)
                    if task.isAIGenerated {
                        aiTasks += 1
                    }
                    
                    // Time period checks
                    if TimePeriodHelper.isBefore7AM(task.timeDate) {
                        timeOfDayTasksBefore7AM += 1
                    }
                    if TimePeriodHelper.isAfterMidnight(task.timeDate) {
                        timeOfDayTasksAfterMidnight += 1
                    }
                    
                    // Track time periods for this date
                    let period = TimePeriodHelper.timePeriod(for: task.timeDate)
                    completedPeriods.insert(period)
                }
                
                // Check if this date has tasks in all 4 time periods
                if completedPeriods.count == 4 {
                    daysWithAllTimePeriods += 1
                }
            }
            
            statistics.totalTasks = totalTasks
            statistics.fitnessTasks = fitnessTasks
            statistics.dietTasks = dietTasks
            statistics.aiTasks = aiTasks
            
            // Time-based statistics
            statistics.dietTasksAfter11PM = dietTasksAfter11PM
            statistics.timeOfDayTasksBefore7AM = timeOfDayTasksBefore7AM
            statistics.timeOfDayTasksAfterMidnight = timeOfDayTasksAfterMidnight
            statistics.allTimePeriodsDays = daysWithAllTimePeriods
            
            // Daily Challenge statistics
            statistics.dailyChallengeTotal = dailyChallengeTotal
            statistics.dailyTasksTotal = dailyTasksTotal
            statistics.aiGeneratedTasksAdded = aiGeneratedTasksAdded
            
            // Calculate daily challenges streak
            statistics.dailyChallengesStreak = calculateDailyChallengesStreak(tasksByDate: tasksByDate)
            
            // Calculate weekly statistics
            calculateWeeklyStatistics(tasksByDate: tasksByDate, statistics: &statistics)
            
            // Calculate humor achievement statistics (daily completion based)
            calculateDailyCompletionStatistics(tasksByDate: tasksByDate, statistics: &statistics)
            
            // Calculate nutrition statistics if userProfile is available
            if let userProfile = userProfile {
                calculateNutritionStatistics(
                    tasksByDate: tasksByDate,
                    userProfile: userProfile,
                    statistics: &statistics
                )
            }
        }
        
        // Challenges count - you'll need to implement this based on your challenge tracking
        // For now, leaving it at 0
        
        // Note: streakRestarts and streakComeback are set to 0 in sync version
        // Use collectStatisticsAsync for complete statistics
        
        return statistics
    }
    
    /// Collect all statistics for a user (asynchronous version with streak history)
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Dictionary of dates to tasks (for task counting)
    ///   - userProfile: User profile for nutrition target calculations (optional)
    ///   - previousStreak: Previous streak value (for tracking restarts, optional)
    /// - Returns: AchievementStatistics with complete streak history
    func collectStatisticsAsync(
        userId: String,
        tasksByDate: [Date: [TaskItem]]? = nil,
        userProfile: UserProfile? = nil,
        previousStreak: Int? = nil
    ) async throws -> AchievementStatistics {
        var statistics = collectStatistics(
            userId: userId,
            tasksByDate: tasksByDate,
            userProfile: userProfile
        )
        
        // Get streak history
        let currentStreak = statistics.streak
        
        // Update streak history if previous streak is provided
        let history: StreakHistory
        if let previousStreak = previousStreak {
            history = try await streakHistoryService.updateStreakHistory(
                userId: userId,
                currentStreak: currentStreak,
                previousStreak: previousStreak
            )
        } else {
            history = try await streakHistoryService.getStreakHistory(userId: userId)
        }
        
        // Set streak history statistics
        statistics.streakRestarts = history.restartCount
        statistics.streakComeback = streakHistoryService.calculateStreakComeback(
            currentStreak: currentStreak,
            history: history
        )
        
        return statistics
    }
    
    /// Calculate nutrition-related statistics
    private func calculateNutritionStatistics(
        tasksByDate: [Date: [TaskItem]],
        userProfile: UserProfile,
        statistics: inout AchievementStatistics
    ) {
        let calendar = Calendar.current
        var dailyNutritionData: [Date: DailyNutrition] = [:]
        
        // Calculate nutrition for each date
        for (date, tasks) in tasksByDate {
            if let nutrition = NutritionCalculator.calculateDailyNutrition(
                for: date,
                tasks: tasks,
                userProfile: userProfile
            ) {
                dailyNutritionData[date] = nutrition
            }
        }
        
        // Calculate streaks
        let sortedDates = dailyNutritionData.keys.sorted(by: >)
        
        // Calorie accuracy streak (must be exactly equal)
        var calorieAccuracyStreak = 0
        var currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.isCaloriesAccurate {
                    calorieAccuracyStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.calorieAccuracyStreak = calorieAccuracyStreak
        
        // Macro streaks - calculate each separately
        // Protein streak
        var proteinStreak = 0
        currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.isProteinAccurate {
                    proteinStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.macroStreakProtein = proteinStreak
        
        // Carbs streak
        var carbsStreak = 0
        currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.isCarbsAccurate {
                    carbsStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.macroStreakCarbs = carbsStreak
        
        // Fats streak
        var fatsStreak = 0
        currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.isFatsAccurate {
                    fatsStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.macroStreakFats = fatsStreak
        
        // All macros streak
        var allMacrosStreak = 0
        currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.areAllMacrosAccurate {
                    allMacrosStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.allMacrosStreak = allMacrosStreak
        
        // Diet tasks skipped streak (consecutive days over target by 1000)
        var dietSkippedStreak = 0
        currentDate = calendar.startOfDay(for: Date())
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let nutrition = dailyNutritionData[date], nutrition.isCaloriesOverBy1000 {
                    dietSkippedStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        statistics.dietTasksSkippedStreak = dietSkippedStreak
    }
    
    /// Calculate daily challenges streak (consecutive days completing all daily challenges)
    /// Streak continues only if:
    /// - The day has daily challenge tasks AND all are completed
    /// - If a day has no daily challenge tasks, it doesn't break the streak but doesn't count either
    private func calculateDailyChallengesStreak(
        tasksByDate: [Date: [TaskItem]]
    ) -> Int {
        let calendar = Calendar.current
        var dailyChallengeCompletion: [Date: Bool] = [:]
        
        // Check each date to see if all daily challenges were completed
        for (date, tasks) in tasksByDate {
            let dailyChallengeTasks = tasks.filter { $0.isDailyChallenge }
            
            // If there are no daily challenge tasks for this date, skip it (doesn't break streak)
            guard !dailyChallengeTasks.isEmpty else {
                continue
            }
            
            // Check if all daily challenge tasks are completed
            let allCompleted = dailyChallengeTasks.allSatisfy { $0.isDone }
            dailyChallengeCompletion[date] = allCompleted
        }
        
        // Calculate streak from most recent date backwards
        let sortedDates = dailyChallengeCompletion.keys.sorted(by: >)
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            
            // Check if this date matches the expected date in the streak
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let completed = dailyChallengeCompletion[date], completed {
                    streak += 1
                    // Move to previous day
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    // Streak broken - daily challenges exist but not all completed
                    break
                }
            } else {
                // Gap in dates - streak is broken if we expected a date but it's missing
                // or if the date has challenges but they weren't completed
                break
            }
        }
        
        return streak
    }
    
    /// Calculate daily completion based statistics (humor achievements)
    private func calculateDailyCompletionStatistics(
        tasksByDate: [Date: [TaskItem]],
        statistics: inout AchievementStatistics
    ) {
        let calendar = Calendar.current
        var dailyStatus: [Date: (completed: Int, total: Int)] = [:]
        
        // Build daily completion status
        for (date, tasks) in tasksByDate {
            let normalizedDate = calendar.startOfDay(for: date)
            let total = tasks.count
            let completed = tasks.filter { $0.isDone }.count
            dailyStatus[normalizedDate] = (completed: completed, total: total)
        }
        
        // consecutiveDaysSkipped: streak of consecutive days where total > 0 and completed == 0
        let sortedDates = dailyStatus.keys.sorted(by: >)
        var skippedStreak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if let status = dailyStatus[dateStart],
                   status.total > 0,
                   status.completed == 0 {
                    skippedStreak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                // gap or out of sequence -> streak ends
                break
            }
        }
        statistics.consecutiveDaysSkipped = skippedStreak
        
        // almostPerfectDays: days with completion rate >= 80% (total > 0)
        var almostPerfectCount = 0
        for (_, status) in dailyStatus {
            guard status.total > 0 else { continue }
            if Double(status.completed) / Double(status.total) >= 0.8 {
                almostPerfectCount += 1
            }
        }
        statistics.almostPerfectDays = almostPerfectCount
    }
    
    /// Calculate weekly statistics (weekendOnlyStreak, allCategoriesInWeek)
    private func calculateWeeklyStatistics(
        tasksByDate: [Date: [TaskItem]],
        statistics: inout AchievementStatistics
    ) {
        // Calculate weekly completions
        let weeklyCompletions = WeekHelper.calculateWeeklyCompletions(tasksByDate: tasksByDate)
        
        // Calculate weekendOnlyStreak (consecutive weeks only completing on weekends)
        statistics.weekendOnlyStreak = WeekHelper.calculateConsecutiveWeeksStreak(
            weeklyCompletions: weeklyCompletions
        ) { weekCompletion in
            weekCompletion.weekendOnly
        }
        
        // Calculate allCategoriesInWeekStreak (consecutive weeks completing all categories)
        statistics.allCategoriesInWeekStreak = WeekHelper.calculateConsecutiveWeeksStreak(
            weeklyCompletions: weeklyCompletions
        ) { weekCompletion in
            // Check if all three categories are completed
            weekCompletion.completedCategories.contains("diet") &&
            weekCompletion.completedCategories.contains("fitness") &&
            weekCompletion.completedCategories.contains("others")
        }
    }
    
    /// Collect statistics from Firebase (for server-side data)
    /// This can be used when you have server-side statistics stored
    func collectStatisticsFromFirebase(
        userId: String
    ) async throws -> AchievementStatistics {
        // TODO: Implement Firebase statistics collection
        // This would query Firebase for aggregated statistics
        return AchievementStatistics()
    }
}

