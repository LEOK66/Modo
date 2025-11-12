import Foundation

/// Represents the category of a task
/// Used to classify tasks into different types: diet, fitness, or others
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case diet = "🥗 Diet"
    case fitness = "🏃 Fitness"
    case others = "📌 Others"
    
    var id: String { rawValue }
}



