import Foundation

/// Service responsible for looking up nutrition data from external APIs
/// Priority: External API (OffClient) → AI Estimation → Hardcoded Fallback
class NutritionLookupService {
    
    // MARK: - Lookup Methods
    
    /// Look up calories for a food item
    /// - Parameters:
    ///   - foodName: Name of the food
    ///   - completion: Completion handler with calories (nil if not found)
    func lookupCalories(for foodName: String, completion: @escaping (Int?) -> Void) {
        print("🔍 NutritionLookupService: Looking up calories for '\(foodName)'")
        
        // Priority 1: Try external food API (OffClient)
        OffClient.searchFoodsCached(query: foodName, limit: 1) { foodItems in
            if let firstItem = foodItems.first, let calories = firstItem.calories {
                print("   ✅ Found in API: \(calories) cal")
                completion(calories)
            } else {
                // Priority 2: Use AI-based estimation
                print("   ⚠️ Not found in API, using estimation")
                let estimated = self.estimateCalories(for: foodName)
                completion(estimated)
            }
        }
    }
    
    /// Look up calories for multiple food items
    /// - Parameters:
    ///   - foodNames: Array of food names
    ///   - completion: Completion handler with array of (name, calories) tuples
    func lookupCaloriesBatch(_ foodNames: [String], completion: @escaping ([(name: String, calories: Int)]) -> Void) {
        print("🔍 NutritionLookupService: Batch lookup for \(foodNames.count) items")
        
        let dispatchGroup = DispatchGroup()
        var results: [(name: String, calories: Int)] = []
        let resultsQueue = DispatchQueue(label: "com.modo.nutrition.results")
        
        for foodName in foodNames {
            dispatchGroup.enter()
            
            lookupCalories(for: foodName) { calories in
                resultsQueue.async {
                    results.append((name: foodName, calories: calories ?? 250))
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("   ✅ Batch lookup completed: \(results.count) items")
            completion(results)
        }
    }
    
    // MARK: - Estimation (Fallback)
    
    /// Estimate calories when API data is not available
    /// Uses intelligent estimation based on food type and keywords
    /// - Parameter food: Food name
    /// - Returns: Estimated calories
    private func estimateCalories(for food: String) -> Int {
        let lowercased = food.lowercased()
        
        // Breakfast dishes
        if lowercased.contains("oatmeal") || lowercased.contains("oat") {
            return 300
        } else if lowercased.contains("scrambled egg") || lowercased.contains("fried egg") {
            return 200
        } else if lowercased.contains("toast") && lowercased.contains("avocado") {
            return 250
        } else if lowercased.contains("yogurt") && lowercased.contains("granola") {
            return 280
        } else if lowercased.contains("pancake") || lowercased.contains("waffle") {
            return 350
        }
        
        // Salads and bowls
        else if lowercased.contains("salad") {
            if lowercased.contains("chicken") || lowercased.contains("caesar") {
                return 350
            } else {
                return 200
            }
        } else if lowercased.contains("bowl") {
            return 400
        }
        
        // Main protein dishes
        else if lowercased.contains("chicken") || lowercased.contains("turkey") {
            if lowercased.contains("grilled") || lowercased.contains("baked") {
                return 300
            } else if lowercased.contains("fried") {
                return 450
            } else {
                return 300
            }
        } else if lowercased.contains("salmon") || lowercased.contains("fish") {
            return 350
        } else if lowercased.contains("beef") || lowercased.contains("steak") {
            return 400
        } else if lowercased.contains("pork") {
            return 350
        }
        
        // Carbs and sides
        else if lowercased.contains("rice") {
            return 250
        } else if lowercased.contains("pasta") {
            return 300
        } else if lowercased.contains("quinoa") {
            return 220
        } else if lowercased.contains("potato") {
            if lowercased.contains("sweet") {
                return 180
            } else if lowercased.contains("fried") || lowercased.contains("fries") {
                return 400
            } else {
                return 200
            }
        }
        
        // Vegetables
        else if lowercased.contains("vegetable") || lowercased.contains("broccoli") ||
                lowercased.contains("asparagus") || lowercased.contains("green bean") ||
                lowercased.contains("spinach") || lowercased.contains("kale") {
            return 100
        }
        
        // Fruits
        else if lowercased.contains("fruit") || lowercased.contains("apple") ||
                lowercased.contains("banana") || lowercased.contains("berries") ||
                lowercased.contains("orange") {
            return 100
        }
        
        // Beverages
        else if lowercased.contains("juice") {
            return 110
        } else if lowercased.contains("smoothie") {
            return 200
        } else if lowercased.contains("coffee") || lowercased.contains("tea") {
            if lowercased.contains("latte") || lowercased.contains("cappuccino") {
                return 150
            } else {
                return 50
            }
        }
        
        // Sandwiches and wraps
        else if lowercased.contains("sandwich") || lowercased.contains("burger") {
            return 450
        } else if lowercased.contains("wrap") {
            return 350
        }
        
        // Soups and stews
        else if lowercased.contains("soup") || lowercased.contains("stew") {
            return 250
        }
        
        // Snacks and desserts
        else if lowercased.contains("cookie") || lowercased.contains("brownie") {
            return 200
        } else if lowercased.contains("ice cream") {
            return 250
        } else if lowercased.contains("chips") {
            return 300
        }
        
        // Default for unknown dishes
        else {
            print("   ⚠️ Unknown food type, using default: 250 cal")
            return 250
        }
    }
    
    // MARK: - Future Extension Point
    
    /// Placeholder for future external nutrition API integration
    /// Can be expanded to use multiple APIs for better coverage
    private func lookupFromAlternativeAPI(foodName: String, completion: @escaping (Int?) -> Void) {
        // TODO: Integrate additional nutrition APIs here
        // Examples: USDA FoodData Central, Nutritionix, Edamam, etc.
        completion(nil)
    }
}

