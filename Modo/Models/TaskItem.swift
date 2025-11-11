import Foundation

/// Represents a task item in the application
/// A task can be a diet entry, fitness activity, or other type of task
/// Tasks are the core data structure for tracking daily activities
struct TaskItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let time: String
    let timeDate: Date // For sorting tasks by time
    let endTime: String? // For fitness tasks with duration
    let meta: String
    var isDone: Bool
    let emphasisHex: String
    let category: TaskCategory // diet, fitness, others
    var dietEntries: [DietEntry]
    var fitnessEntries: [FitnessEntry]
    var createdAt: Date // For sync conflict resolution
    var updatedAt: Date // For sync conflict resolution
    var isAIGenerated: Bool // Mark if task is AI generated
    var isDailyChallenge: Bool // Mark if task is a daily challenge
    
    init(id: UUID = UUID(), title: String, subtitle: String, time: String, timeDate: Date, endTime: String? = nil, meta: String, isDone: Bool = false, emphasisHex: String, category: TaskCategory, dietEntries: [DietEntry], fitnessEntries: [FitnessEntry], createdAt: Date = Date(), updatedAt: Date = Date(), isAIGenerated: Bool = false, isDailyChallenge: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.timeDate = timeDate
        self.endTime = endTime
        self.meta = meta
        self.isDone = isDone
        self.emphasisHex = emphasisHex
        self.category = category
        self.dietEntries = dietEntries
        self.fitnessEntries = fitnessEntries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isAIGenerated = isAIGenerated
        self.isDailyChallenge = isDailyChallenge
    }
    
    /// Calculate total calories for this task
    /// Diet tasks add calories, fitness tasks subtract calories, others don't affect calories
    var totalCalories: Int {
        switch category {
        case .diet:
            return dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
        case .fitness:
            return -fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
        case .others:
            return 0
        }
    }
    
    // Custom Codable implementation to handle Date serialization
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, time, timeDate, endTime, meta, isDone, emphasisHex, category, dietEntries, fitnessEntries, createdAt, updatedAt, isAIGenerated, isDailyChallenge
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        time = try container.decode(String.self, forKey: .time)
        // Decode timeDate as timestamp (milliseconds)
        let timeDateTimestamp = try container.decode(Int64.self, forKey: .timeDate)
        timeDate = Date(timeIntervalSince1970: Double(timeDateTimestamp) / 1000.0)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        meta = try container.decode(String.self, forKey: .meta)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        emphasisHex = try container.decode(String.self, forKey: .emphasisHex)
        category = try container.decode(TaskCategory.self, forKey: .category)
        // Backwards compatibility: use decodeIfPresent for new fields
        dietEntries = try container.decodeIfPresent([DietEntry].self, forKey: .dietEntries) ?? []
        fitnessEntries = try container.decodeIfPresent([FitnessEntry].self, forKey: .fitnessEntries) ?? []
        // Decode timestamps
        let createdAtTimestamp = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? Int64(Date().timeIntervalSince1970 * 1000)
        createdAt = Date(timeIntervalSince1970: Double(createdAtTimestamp) / 1000.0)
        let updatedAtTimestamp = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? Int64(Date().timeIntervalSince1970 * 1000)
        updatedAt = Date(timeIntervalSince1970: Double(updatedAtTimestamp) / 1000.0)
        // Decode isAIGenerated (defaults to false for backwards compatibility)
        isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        // Decode isDailyChallenge (defaults to false for backwards compatibility)
        isDailyChallenge = try container.decodeIfPresent(Bool.self, forKey: .isDailyChallenge) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(time, forKey: .time)
        // Encode timeDate as timestamp (milliseconds)
        try container.encode(Int64(timeDate.timeIntervalSince1970 * 1000.0), forKey: .timeDate)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(meta, forKey: .meta)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(emphasisHex, forKey: .emphasisHex)
        try container.encode(category, forKey: .category)
        try container.encode(dietEntries, forKey: .dietEntries)
        try container.encode(fitnessEntries, forKey: .fitnessEntries)
        // Encode timestamps (milliseconds)
        try container.encode(Int64(createdAt.timeIntervalSince1970 * 1000.0), forKey: .createdAt)
        try container.encode(Int64(updatedAt.timeIntervalSince1970 * 1000.0), forKey: .updatedAt)
        try container.encode(isAIGenerated, forKey: .isAIGenerated)
        try container.encode(isDailyChallenge, forKey: .isDailyChallenge)
    }
}

