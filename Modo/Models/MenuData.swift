import Foundation

public enum MenuData {
    public struct FoodItem: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let calories: Int? // legacy per-serving
        public let caloriesPer100g: Double?
        public let caloriesPerServing: Int?
        public let defaultUnit: String?
        
        // Macro nutrients (per 100g)
        public let proteinPer100g: Double?
        public let fatPer100g: Double?
        public let carbsPer100g: Double?
        
        // Macro nutrients (per serving)
        public let proteinPerServing: Double?
        public let fatPerServing: Double?
        public let carbsPerServing: Double?
        
        // Legacy initializer for backward compatibility
        public init(id: UUID = UUID(), name: String, calories: Int) {
            self.id = id
            self.name = name
            self.calories = calories
            self.caloriesPer100g = nil
            self.caloriesPerServing = calories
            self.defaultUnit = "serving"
            self.proteinPer100g = nil
            self.fatPer100g = nil
            self.carbsPer100g = nil
            self.proteinPerServing = nil
            self.fatPerServing = nil
            self.carbsPerServing = nil
        }
        
        // Full initializer with all parameters
        public init(id: UUID = UUID(), name: String, calories: Int?, caloriesPer100g: Double?, caloriesPerServing: Int?, defaultUnit: String?, proteinPer100g: Double? = nil, fatPer100g: Double? = nil, carbsPer100g: Double? = nil, proteinPerServing: Double? = nil, fatPerServing: Double? = nil, carbsPerServing: Double? = nil) {
            self.id = id
            self.name = name
            self.calories = calories
            self.caloriesPer100g = caloriesPer100g
            self.caloriesPerServing = caloriesPerServing
            self.defaultUnit = defaultUnit
            self.proteinPer100g = proteinPer100g
            self.fatPer100g = fatPer100g
            self.carbsPer100g = carbsPer100g
            self.proteinPerServing = proteinPerServing
            self.fatPerServing = fatPerServing
            self.carbsPerServing = carbsPerServing
        }
        private enum CodingKeys: String, CodingKey { 
            case name, calories, caloriesPer100g, caloriesPerServing, defaultUnit
            case proteinPer100g, fatPer100g, carbsPer100g
            case proteinPerServing, fatPerServing, carbsPerServing
        }
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.calories = try? container.decode(Int.self, forKey: .calories)
            self.caloriesPer100g = try? container.decode(Double.self, forKey: .caloriesPer100g)
            self.caloriesPerServing = (try? container.decode(Int.self, forKey: .caloriesPerServing)) ?? self.calories
            self.defaultUnit = (try? container.decode(String.self, forKey: .defaultUnit)) ?? (self.caloriesPer100g != nil ? "g" : "serving")
            self.proteinPer100g = try? container.decode(Double.self, forKey: .proteinPer100g)
            self.fatPer100g = try? container.decode(Double.self, forKey: .fatPer100g)
            self.carbsPer100g = try? container.decode(Double.self, forKey: .carbsPer100g)
            self.proteinPerServing = try? container.decode(Double.self, forKey: .proteinPerServing)
            self.fatPerServing = try? container.decode(Double.self, forKey: .fatPerServing)
            self.carbsPerServing = try? container.decode(Double.self, forKey: .carbsPerServing)
            self.id = UUID()
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(calories, forKey: .calories)
            try container.encodeIfPresent(caloriesPer100g, forKey: .caloriesPer100g)
            try container.encodeIfPresent(caloriesPerServing, forKey: .caloriesPerServing)
            try container.encodeIfPresent(defaultUnit, forKey: .defaultUnit)
            try container.encodeIfPresent(proteinPer100g, forKey: .proteinPer100g)
            try container.encodeIfPresent(fatPer100g, forKey: .fatPer100g)
            try container.encodeIfPresent(carbsPer100g, forKey: .carbsPer100g)
            try container.encodeIfPresent(proteinPerServing, forKey: .proteinPerServing)
            try container.encodeIfPresent(fatPerServing, forKey: .fatPerServing)
            try container.encodeIfPresent(carbsPerServing, forKey: .carbsPerServing)
        }
        // Helpers
        public var hasPer100g: Bool { caloriesPer100g != nil }
        public var servingCalories: Int? { caloriesPerServing ?? calories }
    }

    public struct ExerciseItem: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let calPer30Min: Int
        public init(id: UUID = UUID(), name: String, calPer30Min: Int) { self.id = id; self.name = name; self.calPer30Min = calPer30Min }
        private enum CodingKeys: String, CodingKey { case name, calPer30Min }
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.calPer30Min = try container.decode(Int.self, forKey: .calPer30Min)
            self.id = UUID()
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(calPer30Min, forKey: .calPer30Min)
        }
    }

    // Public data accessors — load from bundled JSON
    public static var foods: [FoodItem] {
        loadJSON("foods", as: [FoodItem].self) ?? []
    }

    public static var exercises: [ExerciseItem] {
        loadJSON("exercises", as: [ExerciseItem].self) ?? []
    }

    private static func loadJSON<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        // Look up resource in the main bundle. If not found (e.g., not added to target yet), return nil.
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            // Fail soft
            return nil
        }
    }
}


