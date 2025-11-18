import Foundation

/// Service responsible for exercise data lookup and calorie calculations
/// Current: Formula-based calculation
/// Future: External exercise API integration (placeholder ready)
class ExerciseDataService {
    
    // MARK: - Constants
    
    /// Estimated seconds per rep for duration calculation
    private let secondsPerRep = 3
    
    /// Rounding buffer for duration calculation (seconds)
    private let durationRoundingBuffer = 30
    
    /// Seconds in a minute
    private let secondsPerMinute = 60
    
    /// Baseline weight for calorie calculations (kg)
    private let baselineWeightKg = 70.0
    
    /// Minimum duration in minutes
    private let minDurationMinutes = 1
    
    /// Minimum calories burned
    private let minCaloriesBurned = 10
    
    /// Base calories per minute by intensity level
    private struct CaloriesPerMinute {
        static let high: Double = 12.0      // HIIT, compound lifts with low reps
        static let moderate: Double = 8.0   // Bodyweight exercises, moderate weights
        static let low: Double = 5.0        // Isolation movements, stretching
    }
    
    // MARK: - Calorie Calculation
    
    /// Calculate calories burned for an exercise
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - sets: Number of sets
    ///   - reps: Reps per set (can be string like "10-12")
    ///   - restSec: Rest seconds between sets
    ///   - userWeight: User's weight in kg (optional)
    /// - Returns: Estimated calories burned
    func calculateCalories(
        for exerciseName: String,
        sets: Int,
        reps: String,
        restSec: Int,
        userWeight: Double? = nil
    ) -> Int {
        // Extract average reps if range provided
        let avgReps = extractAvgReps(from: reps)
        
        // Determine exercise intensity
        let intensity = determineIntensity(exerciseName: exerciseName, reps: avgReps)
        
        // Calculate duration (rough estimate)
        let workTime = sets * avgReps * secondsPerRep
        let restTime = sets * restSec
        let totalSeconds = workTime + restTime
        let minutes = Double(totalSeconds) / Double(secondsPerMinute)
        
        // Base calories per minute by intensity
        let baseCalPerMin: Double
        switch intensity {
        case .high:
            baseCalPerMin = CaloriesPerMinute.high
        case .moderate:
            baseCalPerMin = CaloriesPerMinute.moderate
        case .low:
            baseCalPerMin = CaloriesPerMinute.low
        }
        
        // Adjust for user weight if available (heavier people burn more)
        let weightMultiplier = userWeight.map { $0 / baselineWeightKg } ?? 1.0
        
        let calories = Int(baseCalPerMin * minutes * weightMultiplier)
        
        print("   💪 Calculated \(exerciseName): \(calories) cal (\(minutes.rounded())min)")
        return max(calories, minCaloriesBurned)
    }
    
    // MARK: - Exercise Analysis
    
    /// Determine exercise intensity from name and reps
    private func determineIntensity(exerciseName: String, reps: Int) -> ExerciseIntensity {
        let lowercased = exerciseName.lowercased()
        
        // High intensity exercises
        if lowercased.contains("burpee") ||
           lowercased.contains("jump") ||
           lowercased.contains("sprint") ||
           lowercased.contains("hiit") ||
           lowercased.contains("mountain climber") ||
           lowercased.contains("box jump") {
            return .high
        }
        
        // High intensity if low reps + compound movements
        if reps <= 6 && (
            lowercased.contains("deadlift") ||
            lowercased.contains("squat") ||
            lowercased.contains("bench press") ||
            lowercased.contains("overhead press")
        ) {
            return .high
        }
        
        // Moderate intensity exercises
        if lowercased.contains("push-up") ||
           lowercased.contains("pull-up") ||
           lowercased.contains("squat") ||
           lowercased.contains("lunge") ||
           lowercased.contains("plank") ||
           lowercased.contains("row") ||
           lowercased.contains("dip") {
            return .moderate
        }
        
        // Low intensity (isolation movements, stretching)
        if lowercased.contains("curl") ||
           lowercased.contains("extension") ||
           lowercased.contains("raise") ||
           lowercased.contains("stretch") {
            return .low
        }
        
        // Default to moderate
        return .moderate
    }
    
    /// Extract average reps from string (handles ranges like "10-12")
    private func extractAvgReps(from repsString: String) -> Int {
        let numbers = repsString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        if numbers.count >= 2 {
            return (numbers[0] + numbers[1]) / 2
        } else if let first = numbers.first {
            return first
        }
        return 10 // default
    }
    
    // MARK: - Duration Calculation
    
    /// Calculate exercise duration in minutes
    /// - Parameters:
    ///   - sets: Number of sets
    ///   - reps: Reps per set
    ///   - restSec: Rest seconds between sets
    /// - Returns: Duration in minutes
    func calculateDuration(sets: Int, reps: String, restSec: Int) -> Int {
        let avgReps = extractAvgReps(from: reps)
        let workTime = sets * avgReps * secondsPerRep
        let restTime = sets * restSec
        let totalSeconds = workTime + restTime
        let minutes = (totalSeconds + durationRoundingBuffer) / secondsPerMinute // Round up
        return max(minutes, minDurationMinutes)
    }
    
    // MARK: - Future API Integration (Placeholder)
    
    /// Placeholder for future external exercise API integration
    /// When available, this would lookup exercise data from a third-party service
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - completion: Completion handler with exercise data (nil if not found)
    func lookupExercise(name exerciseName: String, completion: @escaping (ExerciseData?) -> Void) {
        // TODO: Future integration point for exercise APIs
        // Examples:
        // - ExerciseDB API (exercise.com)
        // - Wger Workout Manager API
        // - Custom exercise database
        
        print("   📍 Exercise API placeholder - not yet implemented")
        print("   Using formula-based calculation instead")
        
        // Currently returns nil, triggering fallback to formula-based calculation
        completion(nil)
    }
    
    /// Batch lookup for multiple exercises
    /// - Parameters:
    ///   - exerciseNames: Array of exercise names
    ///   - completion: Completion handler with array of exercise data
    func lookupExercisesBatch(_ exerciseNames: [String], completion: @escaping ([ExerciseData]) -> Void) {
        // TODO: Implement when exercise API is available
        print("   📍 Batch exercise API placeholder - not yet implemented")
        completion([])
    }
}

// MARK: - Data Models

enum ExerciseIntensity {
    case high    // 12 cal/min - HIIT, compound lifts with low reps
    case moderate // 8 cal/min - Bodyweight exercises, moderate weights
    case low      // 5 cal/min - Isolation movements, stretching
}

/// Data structure for exercise information from external API
struct ExerciseData {
    let name: String
    let category: String       // e.g., "Strength", "Cardio", "Flexibility"
    let muscleGroups: [String] // e.g., ["Chest", "Triceps"]
    let equipment: String?      // e.g., "Barbell", "Dumbbell", "Bodyweight"
    let difficulty: String?     // e.g., "Beginner", "Intermediate", "Advanced"
    let instructions: String?
    let caloriesPerMinute: Double? // If provided by API
    
    // Future extension: video URLs, images, alternative exercises, etc.
}

