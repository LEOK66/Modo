import Foundation

/// AI Notification Manager
///
/// Provides type-safe notification mechanism for AI task operations
///
/// This manager replaces string-based NotificationCenter calls with strongly-typed,
/// Codable payloads to ensure type safety and better debugging.
///
/// Usage:
/// ```swift
/// // Post a query request
/// AINotificationManager.shared.postTaskQueryRequest(params, requestId: "uuid")
///
/// // Observe query requests
/// let observer = AINotificationManager.shared.observeTaskQueryRequest { payload in
///     // Handle query
/// }
/// ```
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
    
    struct TaskBatchPayload: Codable {
        let operations: [TaskBatchOperation]
        let requestId: String
    }
    
    struct TaskResponsePayload<T: Codable>: Codable {
        let requestId: String
        let success: Bool
        let data: T?
        let error: String?
    }
    
    // MARK: - Post Methods
    
    /// Post task create request
    /// - Parameters:
    ///   - tasks: Tasks to create
    ///   - requestId: Unique request identifier
    func postTaskCreateRequest(_ tasks: [AITaskDTO], requestId: String = UUID().uuidString) {
        let payload = TaskCreatePayload(tasks: tasks, requestId: requestId)
        post(name: .taskCreateRequest, payload: payload)
    }
    
    /// Post task query request
    /// - Parameters:
    ///   - params: Query parameters
    ///   - requestId: Unique request identifier
    func postTaskQueryRequest(_ params: TaskQueryParams, requestId: String = UUID().uuidString) {
        let payload = TaskQueryPayload(params: params, requestId: requestId)
        post(name: .taskQueryRequest, payload: payload)
    }
    
    /// Post task update request
    /// - Parameters:
    ///   - taskId: Task ID to update
    ///   - updates: Update parameters
    ///   - requestId: Unique request identifier
    func postTaskUpdateRequest(taskId: UUID, updates: TaskUpdateParams, requestId: String = UUID().uuidString) {
        let payload = TaskUpdatePayload(taskId: taskId, updates: updates, requestId: requestId)
        post(name: .taskUpdateRequest, payload: payload)
    }
    
    /// Post task delete request
    /// - Parameters:
    ///   - taskId: Task ID to delete
    ///   - requestId: Unique request identifier
    func postTaskDeleteRequest(taskId: UUID, requestId: String = UUID().uuidString) {
        let payload = TaskDeletePayload(taskId: taskId, requestId: requestId)
        post(name: .taskDeleteRequest, payload: payload)
    }
    
    /// Post task batch request
    /// - Parameters:
    ///   - operations: Batch operations
    ///   - requestId: Unique request identifier
    func postTaskBatchRequest(operations: [TaskBatchOperation], requestId: String = UUID().uuidString) {
        let payload = TaskBatchPayload(operations: operations, requestId: requestId)
        post(name: .taskBatchRequest, payload: payload)
    }
    
    /// Post response
    /// - Parameters:
    ///   - type: Response notification type
    ///   - requestId: Original request ID
    ///   - success: Whether operation succeeded
    ///   - data: Response data
    ///   - error: Error message if failed
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
    
    /// Observe task create request
    /// - Parameter handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
    func observeTaskCreateRequest(_ handler: @escaping (TaskCreatePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskCreateRequest, handler: handler)
    }
    
    /// Observe task query request
    /// - Parameter handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
    func observeTaskQueryRequest(_ handler: @escaping (TaskQueryPayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskQueryRequest, handler: handler)
    }
    
    /// Observe task update request
    /// - Parameter handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
    func observeTaskUpdateRequest(_ handler: @escaping (TaskUpdatePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskUpdateRequest, handler: handler)
    }
    
    /// Observe task delete request
    /// - Parameter handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
    func observeTaskDeleteRequest(_ handler: @escaping (TaskDeletePayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskDeleteRequest, handler: handler)
    }
    
    /// Observe task batch request
    /// - Parameter handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
    func observeTaskBatchRequest(_ handler: @escaping (TaskBatchPayload) -> Void) -> NSObjectProtocol {
        return observe(name: .taskBatchRequest, handler: handler)
    }
    
    /// Observe response
    /// - Parameters:
    ///   - type: Response notification type
    ///   - handler: Handler to call when notification received
    /// - Returns: Observer token (must be retained and removed later)
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
            print("❌ AINotificationManager: Failed to encode payload for \(name.rawValue)")
            return
        }
        
        NotificationCenter.default.post(
            name: name.name,
            object: nil,
            userInfo: dict
        )
        
        print("📤 AINotificationManager: Posted \(name.rawValue)")
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
                print("❌ AINotificationManager: Failed to decode payload for \(name.rawValue)")
                return
            }
            
            print("📥 AINotificationManager: Received \(name.rawValue)")
            handler(payload)
        }
    }
    
    /// Remove observer
    /// - Parameter observer: Observer token to remove
    func removeObserver(_ observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
    }
}

