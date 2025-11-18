import Foundation

/// Service responsible for looking up nutrition data
/// Priority: Cache → Local foods.json → OpenAI (FirebaseAIService)
/// For manual search: Cache → Network API → Local foods.json → OpenAI
class NutritionLookupService {
    private let firebaseAIService = FirebaseAIService.shared
    
    // MARK: - Constants
    
    /// Default calories to use when lookup fails
    private let defaultCaloriesPerServing = 250
    
    /// Timeout for individual food item lookup (seconds)
    private let perItemTimeoutSeconds: TimeInterval = 30.0
    
    /// Timeout for entire batch lookup (seconds)
    private let totalBatchTimeoutSeconds: TimeInterval = 60.0
    
    // MARK: - Lookup Methods
    
    /// Look up calories for a food item
    /// - Parameters:
    ///   - foodName: Name of the food
    ///   - allowNetwork: Whether to allow network requests (default: false for AI usage)
    ///   - completion: Completion handler with calories (nil if not found)
    func lookupCalories(for foodName: String, allowNetwork: Bool = false, completion: @escaping (Int?) -> Void) {
        // Priority 1: Try cache (memory + disk)
        OffClient.searchFoodsFromCacheOnly(query: foodName) { foodItems in
            if let firstItem = foodItems.first, let calories = firstItem.calories {
                completion(calories)
                return
            }
            
            // Priority 2: If network allowed, try API
            if allowNetwork {
                OffClient.searchFoodsCached(query: foodName, limit: 1) { foodItems in
                    if let firstItem = foodItems.first, let calories = firstItem.calories {
                        completion(calories)
                        return
                    }
                    // Continue to local foods.json
                    self.checkLocalFoods(foodName: foodName, completion: completion)
                }
            } else {
                // Cache-only mode: check local foods.json, then OpenAI
                self.checkLocalFoods(foodName: foodName, completion: completion)
            }
        }
    }
    
    /// Check local foods.json file
    private func checkLocalFoods(foodName: String, completion: @escaping (Int?) -> Void) {
        let searchName = foodName.lowercased()
        let localFoods = MenuData.foods
        
        // Try exact match first
        if let food = localFoods.first(where: { $0.name.lowercased() == searchName }) {
            if let calories = food.servingCalories {
                completion(calories)
                return
            }
        }
        
        // Try contains match
        if let food = localFoods.first(where: { foodName.lowercased().contains($0.name.lowercased()) || $0.name.lowercased().contains(searchName) }) {
            if let calories = food.servingCalories {
                completion(calories)
                return
            }
        }
        
        // Not found in local data, use OpenAI to estimate
        self.estimateCaloriesWithAI(foodName: foodName, completion: completion)
    }
    
    /// Use OpenAI (FirebaseAIService) to estimate calories
    private func estimateCaloriesWithAI(foodName: String, completion: @escaping (Int?) -> Void) {
        let prompt = "Estimate the calories for a typical single serving of '\(foodName)'. Respond with ONLY a number (e.g., '\(defaultCaloriesPerServing)' for \(defaultCaloriesPerServing) calories). Do not include any other text."
        
        Task {
            do {
                let messages = [
                    ChatMessage(role: "user", content: prompt)
                ]
                
                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                if let content = response.choices.first?.message.content,
                   let calories = Int(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    await MainActor.run {
                        completion(calories)
                    }
                } else {
                    await MainActor.run {
                        completion(nil)
                    }
                }
            } catch {
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }
    
    /// Look up calories for multiple food items (cache-only mode for AI)
    /// - Parameters:
    ///   - foodNames: Array of food names
    ///   - allowNetwork: Whether to allow network requests (default: false for AI usage)
    ///   - completion: Completion handler with array of (name, calories) tuples
    func lookupCaloriesBatch(_ foodNames: [String], allowNetwork: Bool = false, completion: @escaping ([(name: String, calories: Int)]) -> Void) {
        print("🔍 NutritionLookupService: Batch lookup for \(foodNames.count) items")
        
        let dispatchGroup = DispatchGroup()
        var results: [(name: String, calories: Int)] = []
        let resultsQueue = DispatchQueue(label: "com.modo.nutrition.results")
        var completedCount = 0
        let totalCount = foodNames.count
        var overallCompleted = false
        let overallCompletedLock = NSLock()
        
        // Timeout settings
        let perItemTimeout = perItemTimeoutSeconds
        let totalTimeout = totalBatchTimeoutSeconds
        let startTime = Date()
        
        // Overall timeout timer
        let timeoutTimer = DispatchSource.makeTimerSource(queue: .main)
        timeoutTimer.schedule(deadline: .now() + totalTimeout)
        timeoutTimer.setEventHandler {
            overallCompletedLock.lock()
            defer { overallCompletedLock.unlock() }
            
            if !overallCompleted {
                overallCompleted = true
                let elapsed = Date().timeIntervalSince(startTime)
                print("⏱️ NutritionLookupService: Overall timeout (\(totalTimeout)s) reached after \(String(format: "%.2f", elapsed))s")
                print("   Completed: \(completedCount)/\(totalCount) items")
                // Complete with whatever results we have
                print("   ✅ Batch lookup completed (with timeout): \(results.count) items")
                completion(results)
            }
        }
        timeoutTimer.resume()
        
        for foodName in foodNames {
            dispatchGroup.enter()
            
            // Per-item timeout with thread-safe flag
            let itemStartTime = Date()
            let itemCompletedLock = NSLock()
            var itemCompleted = false
            
            // Create a timeout timer for this specific item
            let itemTimeoutWork = DispatchWorkItem {
                itemCompletedLock.lock()
                defer { itemCompletedLock.unlock() }
                
                if !itemCompleted {
                    itemCompleted = true
                    let elapsed = Date().timeIntervalSince(itemStartTime)
                    print("⏱️ NutritionLookupService: Timeout for '\(foodName)' after \(String(format: "%.2f", elapsed))s, using default")
                    resultsQueue.async {
                        // Use default calories if timeout
                        results.append((name: foodName, calories: self.defaultCaloriesPerServing))
                        completedCount += 1
                        dispatchGroup.leave()
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + perItemTimeout, execute: itemTimeoutWork)
            
            lookupCalories(for: foodName, allowNetwork: allowNetwork) { calories in
                itemCompletedLock.lock()
                defer { itemCompletedLock.unlock() }
                
                if !itemCompleted {
                    itemCompleted = true
                    itemTimeoutWork.cancel()  // Cancel timeout since we got a result
                    resultsQueue.async {
                        // Use default calories if lookup failed
                        results.append((name: foodName, calories: calories ?? self.defaultCaloriesPerServing))
                        completedCount += 1
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            overallCompletedLock.lock()
            defer { overallCompletedLock.unlock() }
            
            if !overallCompleted {
                overallCompleted = true
                timeoutTimer.cancel()  // Cancel overall timeout since all items completed
                let elapsed = Date().timeIntervalSince(startTime)
                print("   ✅ Batch lookup completed: \(results.count) items in \(String(format: "%.2f", elapsed))s")
                completion(results)
            }
        }
    }
    
}

