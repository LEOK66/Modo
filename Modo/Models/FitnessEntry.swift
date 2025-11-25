import Foundation

/// Represents a single fitness entry within a task
/// Contains information about exercises, duration, and calories burned
struct FitnessEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var exercise: MenuData.ExerciseItem?
    var customName: String
    var minutesInt: Int
    var caloriesText: String
    
    var sets: Int?
    var reps: String?
    var restSec: Int?
    
    init(id: UUID = UUID(), exercise: MenuData.ExerciseItem? = nil, customName: String = "", minutesInt: Int = 0, caloriesText: String = "", sets: Int? = nil, reps: String? = nil, restSec: Int? = nil) {
        self.id = id
        self.exercise = exercise
        self.customName = customName
        self.minutesInt = minutesInt
        self.caloriesText = caloriesText
        self.sets = sets
        self.reps = reps
        self.restSec = restSec
    }
    
    static func == (lhs: FitnessEntry, rhs: FitnessEntry) -> Bool {
        lhs.id == rhs.id && 
        lhs.exercise?.id == rhs.exercise?.id && 
        lhs.customName == rhs.customName && 
        lhs.minutesInt == rhs.minutesInt && 
        lhs.caloriesText == rhs.caloriesText &&
        lhs.sets == rhs.sets &&
        lhs.reps == rhs.reps &&
        lhs.restSec == rhs.restSec
    }
}

