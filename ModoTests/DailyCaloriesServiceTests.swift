import XCTest
import Combine
@testable import Modo

/// Tests for DailyCaloriesService
/// These tests verify daily calories tracking
final class DailyCaloriesServiceTests: XCTestCase {
    
    var service: DailyCaloriesService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        service = DailyCaloriesService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertEqual(service.todayCalories, 0, "Initial calories should be 0")
    }
    
    // MARK: - Update Calories Tests
    
    func testUpdateCaloriesForToday() {
        let expectation = XCTestExpectation(description: "Calories should update")
        let today = Date()
        let testCalories = 2000
        
        // Observe changes
        service.$todayCalories
            .dropFirst() // Skip initial value
            .sink { calories in
                XCTAssertEqual(calories, testCalories, "Calories should be updated")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update calories
        service.updateCalories(testCalories, for: today)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateCaloriesMultipleTimes() {
        let expectation = XCTestExpectation(description: "Calories should update multiple times")
        expectation.expectedFulfillmentCount = 2
        let today = Date()
        
        var updateCount = 0
        
        // Observe changes
        service.$todayCalories
            .dropFirst() // Skip initial value
            .sink { calories in
                updateCount += 1
                if updateCount == 1 {
                    XCTAssertEqual(calories, 1500, "First update should be 1500")
                } else if updateCount == 2 {
                    XCTAssertEqual(calories, 2500, "Second update should be 2500")
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update calories twice
        service.updateCalories(1500, for: today)
        service.updateCalories(2500, for: today)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testUpdateCaloriesForYesterday() {
        let expectation = XCTestExpectation(description: "Calories should not update for yesterday")
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            XCTFail("Failed to create yesterday date")
            return
        }
        
        let initialCalories = service.todayCalories
        
        // Observe changes - should not fire for yesterday
        service.$todayCalories
            .dropFirst()
            .sink { _ in
                XCTFail("Calories should not update for yesterday")
            }
            .store(in: &cancellables)
        
        // Try to update calories for yesterday
        service.updateCalories(2000, for: yesterday)
        
        // Wait a bit to ensure no update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.todayCalories, initialCalories, "Calories should not change for yesterday")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateCaloriesForTomorrow() {
        let expectation = XCTestExpectation(description: "Calories should not update for tomorrow")
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            XCTFail("Failed to create tomorrow date")
            return
        }
        
        let initialCalories = service.todayCalories
        
        // Observe changes - should not fire for tomorrow
        service.$todayCalories
            .dropFirst()
            .sink { _ in
                XCTFail("Calories should not update for tomorrow")
            }
            .store(in: &cancellables)
        
        // Try to update calories for tomorrow
        service.updateCalories(2000, for: tomorrow)
        
        // Wait a bit to ensure no update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.todayCalories, initialCalories, "Calories should not change for tomorrow")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateCaloriesZero() {
        let expectation = XCTestExpectation(description: "Calories should update to zero")
        let today = Date()
        
        // First update to some value
        service.updateCalories(2000, for: today)
        
        // Wait a bit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Then update to zero
            self.service.$todayCalories
                .dropFirst()
                .sink { calories in
                    XCTAssertEqual(calories, 0, "Calories should be updated to zero")
                    expectation.fulfill()
                }
                .store(in: &self.cancellables)
            
            self.service.updateCalories(0, for: today)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testUpdateCaloriesLargeValue() {
        let expectation = XCTestExpectation(description: "Calories should handle large values")
        let today = Date()
        let largeCalories = 10000
        
        // Observe changes
        service.$todayCalories
            .dropFirst()
            .sink { calories in
                XCTAssertEqual(calories, largeCalories, "Calories should handle large values")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update calories
        service.updateCalories(largeCalories, for: today)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

