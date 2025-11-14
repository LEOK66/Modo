import Foundation

/// Represents a single fitness entry within a task
/// Contains information about exercises, duration, and calories burned
struct FitnessEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var exercise: MenuData.ExerciseItem?
    var customName: String
    var minutesInt: Int
    var caloriesText: String
    
    init(id: UUID = UUID(), exercise: MenuData.ExerciseItem? = nil, customName: String = "", minutesInt: Int = 0, caloriesText: String = "") {
        self.id = id
        self.exercise = exercise
        self.customName = customName
        self.minutesInt = minutesInt
        self.caloriesText = caloriesText
    }
    
    static func == (lhs: FitnessEntry, rhs: FitnessEntry) -> Bool {
        lhs.id == rhs.id && 
        lhs.exercise?.id == rhs.exercise?.id && 
        lhs.customName == rhs.customName && 
        lhs.minutesInt == rhs.minutesInt && 
        lhs.caloriesText == rhs.caloriesText
    }
}

