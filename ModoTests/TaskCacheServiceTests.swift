import XCTest
@testable import Modo

/// Tests for TaskCacheService
/// These tests verify cache management operations
final class TaskCacheServiceTests: XCTestCase {
    
    let testUserId = "test-user-cache"
    
    override func setUp() {
        super.setUp()
        // Clear cache before each test
        TaskCacheService.shared.clearCache(userId: testUserId)
    }
    
    override func tearDown() {
        // Clean up after each test
        TaskCacheService.shared.clearCache(userId: testUserId)
        super.tearDown()
    }
    
    // MARK: - Cache Window Tests
    
    func testCalculateCacheWindow() {
        let today = Date()
        let (minDate, maxDate) = TaskCacheService.shared.calculateCacheWindow(centerDate: today)
        
        let calendar = Calendar.current
        let normalizedToday = calendar.startOfDay(for: today)
        
        // Min date should be 1 month before
        guard let expectedMin = calendar.date(byAdding: .month, value: -1, to: normalizedToday) else {
            XCTFail("Failed to calculate expected min date")
            return
        }
        
        // Max date should be 1 month after
        guard let expectedMax = calendar.date(byAdding: .month, value: 1, to: normalizedToday) else {
            XCTFail("Failed to calculate expected max date")
            return
        }
        
        XCTAssertEqual(calendar.startOfDay(for: minDate), calendar.startOfDay(for: expectedMin), "Min date should be 1 month before")
        XCTAssertEqual(calendar.startOfDay(for: maxDate), calendar.startOfDay(for: expectedMax), "Max date should be 1 month after")
    }
    
    func testIsDateInCacheWindow() {
        let today = Date()
        let (minDate, maxDate) = TaskCacheService.shared.calculateCacheWindow(centerDate: today)
        
        let calendar = Calendar.current
        
        // Test date within window
        let dateInWindow = calendar.date(byAdding: .day, value: 10, to: today)!
        XCTAssertTrue(TaskCacheService.shared.isDateInCacheWindow(dateInWindow, windowMin: minDate, windowMax: maxDate), "Date should be in window")
        
        // Test date before window
        let dateBeforeWindow = calendar.date(byAdding: .month, value: -2, to: today)!
        XCTAssertFalse(TaskCacheService.shared.isDateInCacheWindow(dateBeforeWindow, windowMin: minDate, windowMax: maxDate), "Date should be before window")
        
        // Test date after window
        let dateAfterWindow = calendar.date(byAdding: .month, value: 2, to: today)!
        XCTAssertFalse(TaskCacheService.shared.isDateInCacheWindow(dateAfterWindow, windowMin: minDate, windowMax: maxDate), "Date should be after window")
    }
    
    // MARK: - Cache Validity Tests
    
    func testIsCacheValid() {
        let today = Date()
        
        // Initially cache should be invalid (no metadata)
        XCTAssertFalse(TaskCacheService.shared.isCacheValid(for: testUserId, date: today), "Cache should be invalid initially")
        
        // Save some tasks to create metadata (use today as date to ensure metadata is created)
        let task = TestHelpers.createTestTaskItem(title: "Test Task", timeDate: today)
        TaskCacheService.shared.saveTask(task, date: today, userId: testUserId)
        
        // Cache should now be valid
        XCTAssertTrue(TaskCacheService.shared.isCacheValid(for: testUserId, date: today), "Cache should be valid after saving")
    }
    
    // MARK: - Task CRUD Tests
    
    func testSaveAndGetTask() {
        let date = Date()
        let task = TestHelpers.createTestTaskItem(title: "Cached Task")
        
        // Save task
        TaskCacheService.shared.saveTask(task, date: date, userId: testUserId)
        
        // Get tasks
        let cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        
        XCTAssertEqual(cachedTasks.count, 1, "Should have 1 task")
        XCTAssertEqual(cachedTasks.first?.id, task.id, "Task ID should match")
        XCTAssertEqual(cachedTasks.first?.title, task.title, "Task title should match")
    }
    
    func testSaveMultipleTasks() {
        let date = Date()
        let task1 = TestHelpers.createTestTaskItem(title: "Task 1")
        let task2 = TestHelpers.createTestTaskItem(title: "Task 2")
        let task3 = TestHelpers.createTestTaskItem(title: "Task 3")
        
        // Save multiple tasks
        TaskCacheService.shared.saveTask(task1, date: date, userId: testUserId)
        TaskCacheService.shared.saveTask(task2, date: date, userId: testUserId)
        TaskCacheService.shared.saveTask(task3, date: date, userId: testUserId)
        
        // Get tasks
        let cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        
        XCTAssertEqual(cachedTasks.count, 3, "Should have 3 tasks")
    }
    
    func testSaveTasksForDate() {
        let date = Date()
        let task1 = TestHelpers.createTestTaskItem(title: "Task 1")
        let task2 = TestHelpers.createTestTaskItem(title: "Task 2")
        
        // Save multiple tasks at once
        TaskCacheService.shared.saveTasksForDate([task1, task2], date: date, userId: testUserId)
        
        // Get tasks
        let cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        
        XCTAssertEqual(cachedTasks.count, 2, "Should have 2 tasks")
    }
    
    func testUpdateTask() {
        let date = Date()
        let originalTask = TestHelpers.createTestTaskItem(title: "Original Task", isDone: false)
        
        // Save original task
        TaskCacheService.shared.saveTask(originalTask, date: date, userId: testUserId)
        
        // Update task
        let updatedTask = TestHelpers.createTestTaskItem(
            id: originalTask.id,
            title: "Updated Task",
            isDone: true
        )
        TaskCacheService.shared.saveTask(updatedTask, date: date, userId: testUserId)
        
        // Get tasks
        let cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        
        XCTAssertEqual(cachedTasks.count, 1, "Should still have 1 task")
        XCTAssertEqual(cachedTasks.first?.title, "Updated Task", "Task title should be updated")
        XCTAssertTrue(cachedTasks.first?.isDone ?? false, "Task should be done")
    }
    
    func testDeleteTask() {
        let date = Date()
        let task1 = TestHelpers.createTestTaskItem(title: "Task 1")
        let task2 = TestHelpers.createTestTaskItem(title: "Task 2")
        
        // Save tasks
        TaskCacheService.shared.saveTask(task1, date: date, userId: testUserId)
        TaskCacheService.shared.saveTask(task2, date: date, userId: testUserId)
        
        // Delete one task
        TaskCacheService.shared.deleteTask(taskId: task1.id, date: date, userId: testUserId)
        
        // Get tasks
        let cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        
        XCTAssertEqual(cachedTasks.count, 1, "Should have 1 task remaining")
        XCTAssertEqual(cachedTasks.first?.id, task2.id, "Remaining task should be task2")
    }
    
    func testUpdateTaskWithDateChange() {
        let calendar = Calendar.current
        let oldDate = Date()
        guard let newDate = calendar.date(byAdding: .day, value: 1, to: oldDate) else {
            XCTFail("Failed to create new date")
            return
        }
        
        // Create task with oldDate as timeDate
        let task = TestHelpers.createTestTaskItem(title: "Moving Task", timeDate: oldDate)
        
        // Save task on old date
        TaskCacheService.shared.saveTask(task, date: oldDate, userId: testUserId)
        
        // Verify it's on old date
        var tasks = TaskCacheService.shared.getTasks(for: oldDate, userId: testUserId)
        XCTAssertEqual(tasks.count, 1, "Task should be on old date")
        
        // Update task with new date - create task with newDate as timeDate
        let updatedTask = TestHelpers.createTestTaskItem(
            id: task.id,
            title: task.title,
            timeDate: newDate
        )
        TaskCacheService.shared.updateTask(updatedTask, oldDate: oldDate, userId: testUserId)
        
        // Verify it moved to new date
        tasks = TaskCacheService.shared.getTasks(for: oldDate, userId: testUserId)
        XCTAssertEqual(tasks.count, 0, "Task should no longer be on old date")
        
        let newDateTasks = TaskCacheService.shared.getTasks(for: newDate, userId: testUserId)
        XCTAssertEqual(newDateTasks.count, 1, "Task should be on new date")
        XCTAssertEqual(newDateTasks.first?.id, task.id, "Task ID should match")
    }
    
    // MARK: - Cache Statistics Tests
    
    func testGetCacheStatistics() {
        let date1 = Date()
        let calendar = Calendar.current
        guard let date2 = calendar.date(byAdding: .day, value: 1, to: date1) else {
            XCTFail("Failed to create date2")
            return
        }
        
        // Add tasks to different dates - explicitly set timeDate to ensure they're on different dates
        let task1 = TestHelpers.createTestTaskItem(title: "Task 1", timeDate: date1)
        let task2 = TestHelpers.createTestTaskItem(title: "Task 2", timeDate: date1)
        let task3 = TestHelpers.createTestTaskItem(title: "Task 3", timeDate: date2)
        
        TaskCacheService.shared.saveTask(task1, date: date1, userId: testUserId)
        TaskCacheService.shared.saveTask(task2, date: date1, userId: testUserId)
        TaskCacheService.shared.saveTask(task3, date: date2, userId: testUserId)
        
        // Get statistics
        let stats = TaskCacheService.shared.getCacheStatistics(for: testUserId)
        
        XCTAssertEqual(stats.dateCount, 2, "Should have 2 dates")
        XCTAssertEqual(stats.totalTasks, 3, "Should have 3 tasks total")
        XCTAssertNotNil(stats.cacheAge, "Cache age should not be nil")
    }
    
    // MARK: - Cache Cleanup Tests
    
    func testClearCache() {
        let date = Date()
        let task = TestHelpers.createTestTaskItem(title: "Task to Clear")
        
        // Save task
        TaskCacheService.shared.saveTask(task, date: date, userId: testUserId)
        
        // Verify it's cached
        var cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        XCTAssertEqual(cachedTasks.count, 1, "Task should be cached")
        
        // Clear cache
        TaskCacheService.shared.clearCache(userId: testUserId)
        
        // Verify it's cleared
        cachedTasks = TaskCacheService.shared.getTasks(for: date, userId: testUserId)
        XCTAssertEqual(cachedTasks.count, 0, "Cache should be cleared")
    }
    
    func testCleanCacheOutsideWindow() {
        let today = Date()
        let calendar = Calendar.current
        let (minDate, maxDate) = TaskCacheService.shared.calculateCacheWindow(centerDate: today)
        
        // Add task within window - use today as timeDate
        let taskInWindow = TestHelpers.createTestTaskItem(title: "Task In Window", timeDate: today)
        TaskCacheService.shared.saveTask(taskInWindow, date: today, userId: testUserId)
        
        // Add task outside window (2 months before)
        guard let dateOutsideWindow = calendar.date(byAdding: .month, value: -2, to: today) else {
            XCTFail("Failed to create date outside window")
            return
        }
        let taskOutsideWindow = TestHelpers.createTestTaskItem(title: "Task Outside Window", timeDate: dateOutsideWindow)
        TaskCacheService.shared.saveTask(taskOutsideWindow, date: dateOutsideWindow, userId: testUserId)
        
        // Clean cache outside window
        TaskCacheService.shared.cleanCacheOutsideWindow(windowMin: minDate, windowMax: maxDate, for: testUserId)
        
        // Verify tasks within window remain
        let tasksInWindow = TaskCacheService.shared.getTasks(for: today, userId: testUserId)
        XCTAssertEqual(tasksInWindow.count, 1, "Task in window should remain")
        
        // Verify tasks outside window are removed
        let tasksOutsideWindow = TaskCacheService.shared.getTasks(for: dateOutsideWindow, userId: testUserId)
        XCTAssertEqual(tasksOutsideWindow.count, 0, "Task outside window should be removed")
    }
    
    // MARK: - Cache Window Management Tests
    
    func testIsDateInCurrentCacheWindow() {
        let today = Date()
        let calendar = Calendar.current
        
        // Test date within current window
        let dateInWindow = calendar.date(byAdding: .day, value: 10, to: today)!
        XCTAssertTrue(TaskCacheService.shared.isDateInCurrentCacheWindow(dateInWindow, centerDate: today), "Date should be in current cache window")
        
        // Test date outside current window
        let dateOutsideWindow = calendar.date(byAdding: .month, value: 2, to: today)!
        XCTAssertFalse(TaskCacheService.shared.isDateInCurrentCacheWindow(dateOutsideWindow, centerDate: today), "Date should be outside current cache window")
    }
    
    func testUpdateCacheWindow() {
        let today = Date()
        let calendar = Calendar.current
        
        // Add task on today - use today as timeDate
        let task1 = TestHelpers.createTestTaskItem(title: "Task Today", timeDate: today)
        TaskCacheService.shared.saveTask(task1, date: today, userId: testUserId)
        
        // Add task 2 months in the future (outside current window)
        guard let futureDate = calendar.date(byAdding: .month, value: 2, to: today) else {
            XCTFail("Failed to create future date")
            return
        }
        let task2 = TestHelpers.createTestTaskItem(title: "Task Future", timeDate: futureDate)
        TaskCacheService.shared.saveTask(task2, date: futureDate, userId: testUserId)
        
        // Update cache window (should clean outside window)
        TaskCacheService.shared.updateCacheWindow(centerDate: today, for: testUserId)
        
        // Verify task on today remains
        let tasksToday = TaskCacheService.shared.getTasks(for: today, userId: testUserId)
        XCTAssertEqual(tasksToday.count, 1, "Task today should remain")
        
        // Verify future task is cleaned (if it's outside the new window)
        let tasksFuture = TaskCacheService.shared.getTasks(for: futureDate, userId: testUserId)
        // This depends on whether futureDate is outside the new window
        // The cache window is 1 month before and after, so 2 months in future should be outside
        XCTAssertEqual(tasksFuture.count, 0, "Task outside window should be cleaned")
    }
}

