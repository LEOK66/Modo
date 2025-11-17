import Foundation

/// AI Function Call Handler Protocol
///
/// Defines the interface for handling AI function calls
///
/// This protocol allows for extensible function call handling using the strategy pattern.
/// Each function (query_tasks, create_tasks, etc.) should have its own handler implementation.
protocol AIFunctionCallHandler {
    /// Function name this handler supports
    var functionName: String { get }
    
    /// Handle the function call
    /// - Parameters:
    ///   - arguments: Function arguments as JSON string
    ///   - requestId: Unique request identifier for tracking
    /// - Throws: AIFunctionCallError if handling fails
    func handle(arguments: String, requestId: String) async throws
}

/// AI Function Call Error
enum AIFunctionCallError: Error, LocalizedError {
    case invalidArguments(String)
    case handlerNotFound(String)
    case executionFailed(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let details):
            return "Invalid function arguments: \(details)"
        case .handlerNotFound(let functionName):
            return "Handler not found for function: \(functionName)"
        case .executionFailed(let details):
            return "Function execution failed: \(details)"
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        }
    }
}

/// AI Function Call Coordinator
///
/// Coordinates function call handling by routing calls to appropriate handlers
///
/// Usage:
/// ```swift
/// let coordinator = AIFunctionCallCoordinator.shared
/// coordinator.registerHandler(QueryTasksHandler())
/// try await coordinator.handleFunctionCall(name: "query_tasks", arguments: json)
/// ```
class AIFunctionCallCoordinator {
    static let shared = AIFunctionCallCoordinator()
    
    private var handlers: [String: AIFunctionCallHandler] = [:]
    
    private init() {}
    
    /// Register a function call handler
    /// - Parameter handler: Handler to register
    func registerHandler(_ handler: AIFunctionCallHandler) {
        handlers[handler.functionName] = handler
        print("✅ Registered handler for: \(handler.functionName)")
    }
    
    /// Register multiple handlers
    /// - Parameter handlers: Array of handlers to register
    func registerHandlers(_ handlers: [AIFunctionCallHandler]) {
        handlers.forEach { registerHandler($0) }
    }
    
    /// Handle a function call
    /// - Parameters:
    ///   - name: Function name
    ///   - arguments: Function arguments as JSON string
    ///   - requestId: Optional request ID (auto-generated if not provided)
    /// - Throws: AIFunctionCallError if handling fails
    func handleFunctionCall(
        name: String,
        arguments: String,
        requestId: String = UUID().uuidString
    ) async throws {
        guard let handler = handlers[name] else {
            throw AIFunctionCallError.handlerNotFound(name)
        }
        
        print("📞 Handling function call: \(name) (requestId: \(requestId))")
        
        do {
            try await handler.handle(arguments: arguments, requestId: requestId)
            print("✅ Function call completed: \(name)")
        } catch {
            print("❌ Function call failed: \(name) - \(error.localizedDescription)")
            throw AIFunctionCallError.executionFailed(error.localizedDescription)
        }
    }
    
    /// Check if a handler exists for a function
    /// - Parameter functionName: Function name to check
    /// - Returns: True if handler exists
    func hasHandler(for functionName: String) -> Bool {
        return handlers[functionName] != nil
    }
    
    /// Get all registered function names
    /// - Returns: Array of registered function names
    func getRegisteredFunctions() -> [String] {
        return Array(handlers.keys)
    }
}

