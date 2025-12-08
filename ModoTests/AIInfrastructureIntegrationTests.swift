import XCTest
@testable import Modo

/// Integration tests for AI infrastructure
///
/// Tests the interaction between AIServiceUtils, AITaskDTO, and AINotificationManager
final class AIInfrastructureIntegrationTests: XCTestCase {
    
    var notificationManager: AINotificationManager!
    
    override func setUp() {
        super.setUp()
        notificationManager = AINotificationManager.shared
    }
    
    // MARK: - AITaskDTO Conversion Tests
    
    func testTaskItemToDTO() {
        // Given
        let taskItem = createSampleTaskItem()
        
        // When
        let dto = AITaskDTO.from(taskItem)
        
        // Then
        XCTAssertEqual(dto.id, taskItem.id)
        XCTAssertEqual(dto.title, taskItem.title)
        // Check category mapping is correct (both are .fitness)
        XCTAssertEqual(dto.category, .fitness)
        XCTAssertEqual(taskItem.category, .fitness)
        XCTAssertEqual(dto.isAIGenerated, taskItem.isAIGenerated)
        XCTAssertEqual(dto.isDone, taskItem.isDone)
    }
    
    func testDTOToTaskItem() {
        // Given
        let dto = createSampleDTO()
        
        // When
        let taskItem = dto.toTaskItem()
        
        // Then
        XCTAssertEqual(taskItem.id, dto.id)
        XCTAssertEqual(taskItem.title, dto.title)
        // Check category mapping is correct (both are .fitness)
        XCTAssertEqual(dto.category, .fitness)
        XCTAssertEqual(taskItem.category, .fitness)
        XCTAssertEqual(taskItem.isAIGenerated, dto.isAIGenerated)
        XCTAssertEqual(taskItem.isDone, dto.isDone)
    }
    
    func testRoundtripConversion() {
        // Given
        let originalTask = createSampleTaskItem()
        
        // When
        let dto = AITaskDTO.from(originalTask)
        let convertedTask = dto.toTaskItem()
        
        // Then
        XCTAssertEqual(originalTask.id, convertedTask.id)
        XCTAssertEqual(originalTask.title, convertedTask.title)
        XCTAssertEqual(originalTask.category, convertedTask.category)
    }
    
    // MARK: - AIServiceUtils Integration Tests
    
    func testUtilsWithDTO() {
        // Given
        let date = Date()
        let dateString = AIServiceUtils.formatDate(date)
        
        // When
        let dto = createSampleDTO(dateString: dateString)
        
        // Then
        XCTAssertEqual(AIServiceUtils.formatDate(dto.date), dateString)
    }
    
    func testCategoryUtilsWithDTO() {
        // Given
        let dto = createSampleDTO()
        
        // When
        let icon = AIServiceUtils.getCategoryIcon(for: dto.category.rawValue)
        let color = AIServiceUtils.getCategoryColor(for: dto.category.rawValue)
        
        // Then
        XCTAssertFalse(icon.isEmpty)
        XCTAssertFalse(color.isEmpty)
        XCTAssertTrue(color.hasPrefix("#"))
    }
    
    // MARK: - AINotificationManager Integration Tests
    
    func testNotificationWithDTO() {
        // Given
        let expectation = self.expectation(description: "Notification received")
        let dto = createSampleDTO()
        let params = TaskQueryParams(date: Date(), dateRange: 1, category: .fitness, isDone: nil)
        
        var receivedPayload: AINotificationManager.TaskQueryPayload?
        
        // When
        let observer = notificationManager.observeTaskQueryRequest { payload in
            receivedPayload = payload
            expectation.fulfill()
        }
        
        notificationManager.postTaskQueryRequest(params, requestId: "test-123")
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertNotNil(receivedPayload)
            XCTAssertEqual(receivedPayload?.requestId, "test-123")
            XCTAssertEqual(receivedPayload?.params.category, .fitness)
        }
        
        notificationManager.removeObserver(observer)
    }
    
    func testNotificationWithDTOArray() {
        // Given
        let expectation = self.expectation(description: "Create notification received")
        let dtos = [createSampleDTO(), createSampleDTO()]
        
        var receivedTasks: [AITaskDTO]?
        
        // When
        let observer = notificationManager.observeTaskCreateRequest { payload in
            receivedTasks = payload.tasks
            expectation.fulfill()
        }
        
        notificationManager.postTaskCreateRequest(dtos, requestId: "create-123")
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertNotNil(receivedTasks)
            XCTAssertEqual(receivedTasks?.count, 2)
        }
        
        notificationManager.removeObserver(observer)
    }
    
    func testResponseNotification() {
        // Given
        let expectation = self.expectation(description: "Response received")
        let tasks = [createSampleDTO()]
        
        var receivedResponse: AINotificationManager.TaskResponsePayload<[AITaskDTO]>?
        
        // When
        let observer: NSObjectProtocol = notificationManager.observeResponse(
            type: .taskQueryResponse
        ) { (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            receivedResponse = payload
            expectation.fulfill()
        }
        
        notificationManager.postResponse(
            type: .taskQueryResponse,
            requestId: "query-123",
            success: true,
            data: tasks,
            error: nil
        )
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error)
            XCTAssertNotNil(receivedResponse)
            XCTAssertEqual(receivedResponse?.requestId, "query-123")
            XCTAssertTrue(receivedResponse?.success ?? false)
            XCTAssertEqual(receivedResponse?.data?.count, 1)
            XCTAssertNil(receivedResponse?.error)
        }
        
        notificationManager.removeObserver(observer)
    }
    
    // MARK: - Complete Flow Test
    
    func testCompleteQueryFlow() {
        // Given
        let queryExpectation = self.expectation(description: "Query received")
        let responseExpectation = self.expectation(description: "Response received")
        
        let requestId = UUID().uuidString
        let mockTasks = [createSampleDTO()]
        
        // When - Setup observer for query request
        let queryObserver = notificationManager.observeTaskQueryRequest { payload in
            XCTAssertEqual(payload.requestId, requestId)
            queryExpectation.fulfill()
            
            // Simulate response
            self.notificationManager.postResponse(
                type: .taskQueryResponse,
                requestId: payload.requestId,
                success: true,
                data: mockTasks
            )
        }
        
        // Setup observer for response
        let responseObserver: NSObjectProtocol = notificationManager.observeResponse(
            type: .taskQueryResponse
        ) { (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            XCTAssertEqual(payload.requestId, requestId)
            XCTAssertTrue(payload.success)
            XCTAssertEqual(payload.data?.count, 1)
            responseExpectation.fulfill()
        }
        
        // Trigger the flow
        let params = TaskQueryParams(date: Date(), dateRange: 1, category: nil, isDone: nil)
        notificationManager.postTaskQueryRequest(params, requestId: requestId)
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error)
        }
        
        notificationManager.removeObserver(queryObserver)
        notificationManager.removeObserver(responseObserver)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleTaskItem() -> TaskItem {
        return TaskItem(
            id: UUID(),
            title: "Test Task",
            subtitle: "Test Subtitle",
            time: "9:00 AM",
            timeDate: Date(),
            endTime: nil,
            meta: "",
            isDone: false,
            emphasisHex: "#6366F1",
            category: .fitness,
            dietEntries: [],
            fitnessEntries: [],
            createdAt: Date(),
            updatedAt: Date(),
            isAIGenerated: true,
            isDailyChallenge: false
        )
    }
    
    private func createSampleDTO(dateString: String? = nil) -> AITaskDTO {
        let date = dateString != nil ? AIServiceUtils.parseDate(dateString!)! : Date()
        
        return AITaskDTO(
            id: UUID(),
            type: .workout,
            title: "Test Workout",
            subtitle: "Test Description",
            date: date,
            time: "9:00 AM",
            category: .fitness,
            exercises: [
                AITaskDTO.Exercise(
                    name: "Push-ups",
                    sets: 3,
                    reps: "10",
                    restSec: 60,
                    durationMin: 5,
                    calories: 50
                )
            ],
            totalDuration: 5,
            meals: nil,
            totalCalories: 50,
            isAIGenerated: true,
            isDone: false,
            source: "test",
            createdAt: Date()
        )
    }
}

