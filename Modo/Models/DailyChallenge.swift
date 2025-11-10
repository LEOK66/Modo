import Foundation

// MARK: - Daily Challenge Model

struct DailyChallenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let emoji: String
    let type: ChallengeType
    let targetValue: Int
    let date: Date
    
    enum ChallengeType: String, Codable {
        case fitness = "fitness"
        case diet = "diet"
        case mindfulness = "mindfulness"
        case other = "other"
    }
}

