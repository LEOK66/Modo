import Foundation
import SwiftData

/// Base protocol for all repositories
/// Repositories coordinate between SwiftData (local) and Firebase (cloud) data sources
protocol RepositoryProtocol {
    /// The model context for SwiftData operations
    var modelContext: ModelContext { get }
    
    /// The database service for Firebase operations
    var databaseService: DatabaseServiceProtocol { get }
}





