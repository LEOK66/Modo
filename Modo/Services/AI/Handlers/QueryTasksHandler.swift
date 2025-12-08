import Foundation
import FirebaseAuth

/// Query Tasks Handler
///
/// Handles query_tasks function calls from AI
///
/// This handler:
/// 1. Parses query parameters from AI
/// 2. Queries tasks from TaskCacheService
/// 3. Posts response via AINotificationManager
class QueryTasksHandler: AIFunctionCallHandler {
    var functionName: String { "query_tasks" }
    
    private let cacheService: TaskCacheService
    private let notificationManager: AINotificationManager
    
    init(
        cacheService: TaskCacheService = TaskCacheService.shared,
        notificationManager: AINotificationManager = .shared
    ) {
        self.cacheService = cacheService
        self.notificationManager = notificationManager
    }
    
    func handle(arguments: String, requestId: String) async throws {
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AIFunctionCallError.executionFailed("User not authenticated")
        }
        
        // Parse arguments
        guard let params = parseArguments(arguments) else {
            throw AIFunctionCallError.invalidArguments("Failed to parse query_tasks arguments")
        }
        
        print("🔍 Query params: date=\(AIServiceUtils.formatDate(params.date)), range=\(params.dateRange), category=\(params.category?.rawValue ?? "all")")
        
        // Query tasks from cache
        let tasks = queryTasks(with: params, userId: userId)
        
        // Convert to DTOs
        let dtos = tasks.map { AITaskDTO.from($0) }
        
        print("✅ Found \(dtos.count) tasks")
        
        // Post response
        notificationManager.postResponse(
            type: .taskQueryResponse,
            requestId: requestId,
            success: true,
            data: dtos,
            error: nil
        )
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(_ arguments: String) -> TaskQueryParams? {
        guard let jsonData = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        // Parse date
        let dateString = json["date"] as? String ?? AIServiceUtils.formatDate(Date())
        guard let date = AIServiceUtils.parseDate(dateString) else {
            return nil
        }
        
        // Parse date_range (optional, will default to 1 in queryTasks if nil)
        let dateRange = json["date_range"] as? Int
        
        // Parse category
        var category: AITaskDTO.Category?
        if let categoryString = json["category"] as? String {
            category = AITaskDTO.Category(rawValue: categoryString)
        }
        
        // Parse is_done
        let isDone = json["is_done"] as? Bool
        
        return TaskQueryParams(
            date: date,
            dateRange: dateRange,
            category: category,
            isDone: isDone
        )
    }
    
    private func queryTasks(with params: TaskQueryParams, userId: String) -> [TaskItem] {
        var allTasks: [TaskItem] = []
        let calendar = Calendar.current
        let dateRange = params.dateRange ?? 1 // Default to 1 day if not specified
        
        // Collect tasks for each day in the range
        for dayOffset in 0..<dateRange {
            guard let currentDate = calendar.date(byAdding: .day, value: dayOffset, to: params.date) else {
                continue
            }
            let dayTasks = cacheService.getTasks(for: currentDate, userId: userId)
            allTasks.append(contentsOf: dayTasks)
        }
        
        // Filter by category
        if let category = params.category {
            let taskCategory: TaskCategory
            switch category {
            case .fitness:
                taskCategory = .fitness
            case .diet:
                taskCategory = .diet
            case .others:
                taskCategory = .others
            }
            allTasks = allTasks.filter { $0.category == taskCategory }
        }
        
        // Filter by completion status
        if let isDone = params.isDone {
            allTasks = allTasks.filter { $0.isDone == isDone }
        }
        
        // Sort by date and time
        return allTasks.sorted { $0.timeDate < $1.timeDate }
    }
}

