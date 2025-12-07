import Foundation
import Combine
/// Dependency injection container for managing service instances
/// 
/// This container provides a centralized way to register and resolve service dependencies,
/// enabling better testability and reducing coupling between components.
///
final class ServiceContainer: ObservableObject {
    /// Shared singleton instance of the service container
    static let shared = ServiceContainer()
    
    // MARK: - Service Storage
    
    /// Dictionary to store service instances by their protocol type
    private var services: [String: Any] = [:]
    
    /// Thread-safe queue for service registration and resolution
    private let queue = DispatchQueue(label: "com.modo.servicecontainer", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - Service Registration
    
    /// Register a service instance for a protocol type
    /// - Parameters:
    ///   - service: The service instance to register
    ///   - type: The protocol type to register the service for
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = service
        }
    }
    
    /// Register a service factory (lazy initialization)
    /// - Parameters:
    ///   - factory: Closure that creates the service instance
    ///   - type: The protocol type to register the service for
    func register<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = factory
        }
    }
    
    // MARK: - Service Resolution
    
    /// Resolve a service instance for a protocol type
    /// - Parameter type: The protocol type to resolve
    /// - Returns: The service instance, or nil if not registered
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return queue.sync {
            guard let service = services[key] else {
                return nil
            }
            
            // If it's a factory closure, call it
            if let factory = service as? () -> T {
                return factory()
            }
            
            // Otherwise, return the service directly
            return service as? T
        }
    }
    
    /// Resolve a service instance, throwing an error if not found
    /// - Parameter type: The protocol type to resolve
    /// - Returns: The service instance
    /// - Throws: ServiceContainerError.serviceNotFound if service is not registered
    func resolveRequired<T>(_ type: T.Type) throws -> T {
        guard let service = resolve(type) else {
            throw ServiceContainerError.serviceNotFound(String(describing: type))
        }
        return service
    }
    
    // MARK: - Default Service Registration
    
    /// Register default service implementations
    /// Services are registered with proper dependency injection where applicable
    private func registerDefaultServices() {
        // Register DatabaseService first (no dependencies)
        let databaseService = DatabaseService.shared
        register(databaseService, for: DatabaseServiceProtocol.self)
        
        // Register DailyChallengeService with DatabaseService dependency
        let challengeService = DailyChallengeService(databaseService: databaseService)
        register(challengeService, for: ChallengeServiceProtocol.self)
        
        // Register AuthService with challenge service dependency
        let authService = AuthService(challengeService: challengeService)
        register(authService, for: AuthServiceProtocol.self)
        
        // Register TaskManagerService with DatabaseService dependency
        let taskManagerService = TaskManagerService(databaseService: databaseService)
        register(taskManagerService, for: TaskServiceProtocol.self)
        
        // Register AchievementService with DatabaseService dependency
        let achievementService = AchievementService(databaseService: databaseService)
        register(achievementService, for: AchievementServiceProtocol.self)
    }
    
    // MARK: - Service Cleanup
    
    /// Remove a service from the container
    /// - Parameter type: The protocol type to remove
    func remove<T>(_ type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services.removeValue(forKey: key)
        }
    }
    
    /// Clear all registered services
    func clear() {
        queue.async(flags: .barrier) {
            self.services.removeAll()
        }
    }
}

// MARK: - ServiceContainerError

enum ServiceContainerError: Error, LocalizedError {
    case serviceNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let serviceName):
            return "Service not found: \(serviceName)"
        }
    }
}

// MARK: - ServiceContainer Extensions

extension ServiceContainer {
    /// Convenience method to get AuthService
    /// Returns the registered service or falls back to shared instance for backward compatibility
    /// Note: Returns AuthService (not protocol) because it needs to be ObservableObject for @StateObject
    var authService: AuthService {
        if let service = resolve(AuthServiceProtocol.self) as? AuthService {
            return service
        }
        return AuthService.shared
    }
    
    /// Convenience method to get DatabaseService
    /// Returns the registered service or falls back to shared instance for backward compatibility
    var databaseService: DatabaseServiceProtocol {
        return resolve(DatabaseServiceProtocol.self) ?? DatabaseService.shared
    }
    
    /// Convenience method to get TaskService
    /// Returns the registered service or creates a new instance with DatabaseService for backward compatibility
    var taskService: TaskServiceProtocol {
        if let service = resolve(TaskServiceProtocol.self) {
            return service
        }
        // Fallback: create new instance with DatabaseService dependency
        let databaseService = resolve(DatabaseServiceProtocol.self) ?? DatabaseService.shared
        return TaskManagerService(databaseService: databaseService)
    }
    
    /// Convenience method to get ChallengeService
    /// Returns the registered service or creates a new instance with DatabaseService for backward compatibility
    /// Note: Returns DailyChallengeService (not protocol) because it needs to be ObservableObject for @StateObject
    var challengeService: DailyChallengeService {
        if let service = resolve(ChallengeServiceProtocol.self) as? DailyChallengeService {
            return service
        }
        // Fallback: create new instance with DatabaseService dependency
        let databaseService = resolve(DatabaseServiceProtocol.self) ?? DatabaseService.shared
        return DailyChallengeService(databaseService: databaseService)
    }
    
    /// Convenience method to get AchievementService
    /// Returns the registered service or creates a new instance with DatabaseService for backward compatibility
    var achievementService: AchievementServiceProtocol {
        if let service = resolve(AchievementServiceProtocol.self) {
            return service
        }
        // Fallback: create new instance with DatabaseService dependency
        let databaseService = resolve(DatabaseServiceProtocol.self) ?? DatabaseService.shared
        return AchievementService(databaseService: databaseService)
    }
}

