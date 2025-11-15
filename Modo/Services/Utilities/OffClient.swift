import Foundation

// Minimal OFF client: name search → kcal mapping
enum OffClient {
    // Simple in-memory cache with thread-safe access
    private static var memoryCache: [String: [MenuData.FoodItem]] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.modo.offclient.cache", attributes: .concurrent)
    
    // Track in-flight requests to avoid duplicate network calls
    private static var inFlightRequests: [String: [([MenuData.FoodItem]) -> Void]] = [:]
    private static let requestQueue = DispatchQueue(label: "com.modo.offclient.requests")
    
    // Custom URLSession: disable system cache (we handle caching manually)
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.timeoutIntervalForResource = 15.0
        return URLSession(configuration: config)
    }()
    nonisolated struct OffSearchResponse: Decodable {
        let products: [Product]
        nonisolated struct Product: Decodable {
            let product_name: String?
            let generic_name: String?
            let nutriments: Nutriments?
            let brands: String?
            let categories_tags: [String]?
        }
        nonisolated struct Nutriments: Decodable {
            let energy_kcal_100g: Double?
            let energy_100g: Double? // sometimes kJ, we will convert if needed
            let energy_unit: String?
            let proteins_100g: Double?
            let carbohydrates_100g: Double?
            let fat_100g: Double?
            private enum CodingKeys: String, CodingKey {
                case energy_kcal_100g = "energy-kcal_100g"
                case energy_100g
                case energy_unit
                case proteins_100g
                case carbohydrates_100g
                case fat_100g
            }
        }
    }

    // Cache-only search: memory → disk (no network)
    // Used by AI to avoid network delays during task generation
    static func searchFoodsFromCacheOnly(query: String, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        let key = query.lowercased()
        
        // Check memory cache (thread-safe read)
        var cached: [MenuData.FoodItem]? = nil
        cacheQueue.sync {
            cached = memoryCache[key]
        }
        if let cached = cached, !cached.isEmpty {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        
        // Check disk cache
        if let disk = loadFromDisk(key: key), !disk.isEmpty {
            // Thread-safe write to memory cache
            cacheQueue.async(flags: .barrier) {
                memoryCache[key] = disk
            }
            DispatchQueue.main.async { completion(disk) }
            return
        }
        
        // No cache found, return empty
        DispatchQueue.main.async { completion([]) }
    }
    
    // Cached search: memory → disk → network (with retry)
    // Note: Empty results are NOT cached to allow retry on next search
    static func searchFoodsCached(query: String, limit: Int = 50, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        let key = query.lowercased()
        
        // Check memory cache (thread-safe read)
        var cached: [MenuData.FoodItem]? = nil
        cacheQueue.sync {
            cached = memoryCache[key]
        }
        if let cached = cached, !cached.isEmpty {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        
        // Check disk cache, but skip if it's empty (empty results shouldn't block network requests)
        if let disk = loadFromDisk(key: key) {
            if !disk.isEmpty {
                // Thread-safe write to memory cache
                cacheQueue.async(flags: .barrier) {
                    memoryCache[key] = disk
                }
                DispatchQueue.main.async { completion(disk) }
                return
            } else {
                // Disk cache exists but is empty - clear it and fetch from network
                clearDiskCache(key: key)
            }
        }
        
        // Check if there's already an in-flight request for this key
        var shouldStartRequest = false
        requestQueue.sync {
            if inFlightRequests[key] == nil {
                inFlightRequests[key] = []
                shouldStartRequest = true
            }
            inFlightRequests[key]?.append(completion)
        }
        
        if shouldStartRequest {
            // Start new network request
            searchFoodsNetworkWithRetry(query: query, limit: limit, retryCount: 0, maxRetries: 2) { items in
                // Get all waiting completions and clear in-flight tracking
                let completions: [([MenuData.FoodItem]) -> Void] = requestQueue.sync {
                    let result = inFlightRequests[key] ?? []
                    inFlightRequests.removeValue(forKey: key)
                    return result
                }
                
                // Only cache non-empty results to avoid blocking future searches
                if !items.isEmpty {
                    cacheQueue.async(flags: .barrier) {
                        memoryCache[key] = items
                    }
                    saveToDisk(key: key, items: items)
                }
                
                // Notify all waiting completions
                DispatchQueue.main.async {
                    for comp in completions {
                        comp(items)
                    }
                }
            }
        }
        // If shouldStartRequest is false, the completion is already added to inFlightRequests
        // and will be called when the existing request completes
    }
    
    // Network search with retry logic (only retries on network errors, not empty results)
    private static func searchFoodsNetworkWithRetry(query: String, limit: Int, retryCount: Int, maxRetries: Int, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        searchFoodsNetwork(query: query, limit: limit, onNetworkError: { error in
            // Retry on network errors (timeout, connection lost, etc.)
            if retryCount < maxRetries {
                let delay = Double(retryCount + 1) * 0.5  // Exponential backoff: 0.5s, 1.0s
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    searchFoodsNetworkWithRetry(query: query, limit: limit, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }) { items in
            completion(items)
        }
    }

    static func searchFoodsNetwork(query: String, limit: Int = 50, onNetworkError: ((Error) -> Void)? = nil, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        guard query.count >= 2 else { completion([]); return }
        
        // OFF API: https://world.openfoodfacts.org/cgi/search.pl
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        var items: [URLQueryItem] = [
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: String(limit)),
            .init(name: "fields", value: "product_name,generic_name,brands,categories_tags,nutriments.energy-kcal_100g,nutriments.energy_100g,nutriments.energy_unit,nutriments.proteins_100g,nutriments.carbohydrates_100g,nutriments.fat_100g"),
            .init(name: "search_terms", value: query.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
        // Narrowing parameters based on query
        let qLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "  ", with: " ")
        func normalize(_ s: String) -> String {
            let lowered = s.lowercased()
            let allowed = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " ".unicodeScalars.first! }
            return String(String.UnicodeScalarView(allowed)).replacingOccurrences(of: "  ", with: " ")
        }
        let brandKeywords = ["lays","cheetos","pringles","doritos","ruffles","kettle","utz","walkers"]
        let matchedBrand = brandKeywords.first(where: { qLower.contains($0) })
        if let brand = matchedBrand {
            items.append(.init(name: "tagtype_0", value: "brands"))
            items.append(.init(name: "tag_contains_0", value: "contains"))
            items.append(.init(name: "tag_0", value: brand))
        }
        let chipsKeywords = ["chips","crisps"]
        if matchedBrand == nil && chipsKeywords.contains(where: { qLower.contains($0) }) {
            items.append(.init(name: "tagtype_1", value: "categories"))
            items.append(.init(name: "tag_contains_1", value: "contains"))
            items.append(.init(name: "tag_1", value: "chips"))
        }
        components.queryItems = items
        guard let url = components.url else {
            completion([])
            return
        }
        
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 12.0)
        req.setValue("ModoApp/1.0 (iOS) OFF Lookup", forHTTPHeaderField: "User-Agent")

        urlSession.dataTask(with: req) { data, response, error in
            if let error = error {
                if let onNetworkError = onNetworkError {
                    onNetworkError(error)
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let decoded: OffSearchResponse
            do {
                decoded = try JSONDecoder().decode(OffSearchResponse.self, from: data)
            } catch {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var mapped: [MenuData.FoodItem] = []
            for p in decoded.products {
                let trimmedName = { (s: String?) -> String? in
                    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
                    return t
                }
                let name = trimmedName(p.product_name) ?? trimmedName(p.generic_name) ?? trimmedName(p.brands)
                guard let nameUnwrapped = name else {
                    continue
                }
                var kcal: Double? = p.nutriments?.energy_kcal_100g
                if kcal == nil, let e100 = p.nutriments?.energy_100g, let unit = p.nutriments?.energy_unit?.lowercased() {
                    if unit == "kcal" { kcal = e100 }
                    else if unit == "kj" { kcal = e100 / 4.184 }
                }
                guard let kcalVal = kcal else {
                    continue
                }

                // if the field is missing, should we default to 0 or make it null? 
                let protein = p.nutriments?.proteins_100g ?? 0.0
                let carbs = p.nutriments?.carbohydrates_100g ?? 0.0
                let fat = p.nutriments?.fat_100g ?? 0.0
                
                mapped.append(MenuData.FoodItem(
                    name: nameUnwrapped, 
                    calories: Int(round(kcalVal)),
                    proteinPer100g: protein,
                    carbsPer100g: carbs,
                    fatPer100g: fat
                ))
            }
            // client-side filter/sort (robust contains: ignore case & punctuation)
            let qNorm = normalize(qLower)
            mapped = mapped.filter { item in
                let nNorm = normalize(item.name)
                let matches: Bool
                if let brand = matchedBrand {
                    let brandNorm = normalize(brand)
                    matches = nNorm.contains(brandNorm) || nNorm.contains(qNorm)
                } else {
                    matches = nNorm.contains(qNorm)
                }
                return matches
            }
            mapped.sort { a, b in
                let na = a.name.lowercased(); let nb = b.name.lowercased()
                let ba = brandKeywords.contains(where: { na.contains($0) })
                let bb = brandKeywords.contains(where: { nb.contains($0) })
                if ba != bb { return ba && !bb }
                if na.contains(qNorm) != nb.contains(qNorm) { return na.contains(qNorm) && !nb.contains(qNorm) }
                // Extract numbers at end (kcal)
                if a.calories != b.calories { 
                    guard let aCal = a.calories, let bCal = b.calories else { return false }
                    return aCal > bCal 
                }
                return na < nb
            }
            DispatchQueue.main.async {
                completion(mapped)
            }
        }.resume()
    }

    // MARK: - Disk cache (very small, JSON per query)
    private static func cacheDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("OffCache", isDirectory: true)
    }
    private static func ensureCacheDir() {
        guard let dir = cacheDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    private static func pathFor(key: String) -> URL? {
        ensureCacheDir();
        return cacheDirectory()?.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_") + ".json")
    }
    private static func saveToDisk(key: String, items: [MenuData.FoodItem]) {
        guard let url = pathFor(key: key) else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) { try? data.write(to: url) }
    }
    private static func loadFromDisk(key: String) -> [MenuData.FoodItem]? {
        guard let url = pathFor(key: key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([MenuData.FoodItem].self, from: data)
    }
    
    // Clear disk cache for a specific key
    private static func clearDiskCache(key: String) {
        guard let url = pathFor(key: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    // Public method to clear cache (useful for debugging or manual refresh)
    static func clearCache(for query: String) {
        let key = query.lowercased()
        cacheQueue.async(flags: .barrier) {
            memoryCache.removeValue(forKey: key)
        }
        clearDiskCache(key: key)
    }
}


