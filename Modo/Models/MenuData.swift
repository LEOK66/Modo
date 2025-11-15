import Foundation

public enum MenuData {
    public struct FoodItem: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let calories: Int? // legacy per-serving
        public let caloriesPer100g: Double?
        public let caloriesPerServing: Int?
        public let defaultUnit: String?

        // macro fields
        public let proteinPer100g: Double?
        public let carbsPer100g: Double?
        public let fatPer100g: Double?

        public init(id: UUID = UUID(), name: String, calories: Int, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double) { self.id = id; self.name = name; self.calories = calories; self.caloriesPer100g = nil; self.caloriesPerServing = calories; self.defaultUnit = "serving"; self.proteinPer100g = proteinPer100g; self.carbsPer100g = carbsPer100g; self.fatPer100g = fatPer100g;}
        private enum CodingKeys: String, CodingKey { case name, calories, caloriesPer100g, caloriesPerServing, defaultUnit, proteinPer100g, carbsPer100g, fatPer100g }
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.calories = try? container.decode(Int.self, forKey: .calories)
            self.caloriesPer100g = try? container.decode(Double.self, forKey: .caloriesPer100g)
            self.caloriesPerServing = (try? container.decode(Int.self, forKey: .caloriesPerServing)) ?? self.calories
            self.defaultUnit = (try? container.decode(String.self, forKey: .defaultUnit)) ?? (self.caloriesPer100g != nil ? "g" : "serving")
            self.id = UUID()
            
            self.proteinPer100g = try? container.decode(Double.self, forKey: .proteinPer100g)
            self.carbsPer100g = try? container.decode(Double.self, forKey: .carbsPer100g)
            self.fatPer100g = try? container.decode(Double.self, forKey: .fatPer100g)
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(calories, forKey: .calories)
            try container.encodeIfPresent(caloriesPer100g, forKey: .caloriesPer100g)
            try container.encodeIfPresent(caloriesPerServing, forKey: .caloriesPerServing)
            try container.encodeIfPresent(defaultUnit, forKey: .defaultUnit)
            try container.encodeIfPresent(proteinPer100g, forKey: .proteinPer100g)
            try container.encodeIfPresent(carbsPer100g, forKey: .carbsPer100g)
            try container.encodeIfPresent(fatPer100g, forKey: .fatPer100g)
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


