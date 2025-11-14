import Foundation

/// Represents a single diet entry within a task
/// Contains information about food items, quantities, and calories
struct DietEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var food: MenuData.FoodItem?
    var customName: String
    var quantityText: String
    var unit: String
    var caloriesText: String
    
    init(id: UUID = UUID(), food: MenuData.FoodItem? = nil, customName: String = "", quantityText: String = "", unit: String = "serving", caloriesText: String = "") {
        self.id = id
        self.food = food
        self.customName = customName
        self.quantityText = quantityText
        self.unit = unit
        self.caloriesText = caloriesText
    }
    
    static func == (lhs: DietEntry, rhs: DietEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.food?.id == rhs.food?.id &&
        lhs.customName == rhs.customName &&
        lhs.quantityText == rhs.quantityText &&
        lhs.unit == rhs.unit &&
        lhs.caloriesText == rhs.caloriesText
    }
}

