import Foundation

/// Open Food Facts API client with improved error handling and rate limiting
/// Based on Open Food Facts API best practices
/// Note: No caching - always performs network requests
enum OffClient {
    // MARK: - Constants
    
    /// Open Food Facts API base URL
    private static let apiBaseURL = "https://world.openfoodfacts.org"
    
    /// User-Agent following Open Food Facts guidelines
    /// Format: AppName/Version (Platform; Contact)
    private static let userAgent = "ModoApp/1.0 (iOS; https://github.com/LEOK66/Modo)"
    
    /// Maximum retry attempts for network requests
    private static let maxRetries = 2
    
    /// Base delay for exponential backoff (seconds)
    private static let baseRetryDelay: TimeInterval = 0.5
    
    /// Request timeout (seconds) - increased for slow API responses
    private static let requestTimeout: TimeInterval = 30.0
    
    /// Rate limit delay when receiving 429 (seconds)
    private static let rateLimitDelay: TimeInterval = 2.0
    
    // MARK: - Request Management
    
    // Track in-flight requests to avoid duplicate network calls for the same query
    private static var inFlightRequests: [String: [([MenuData.FoodItem]) -> Void]] = [:]
    private static let requestQueue = DispatchQueue(label: "com.modo.offclient.requests")
    
    // Track rate limiting state
    private static var rateLimitedUntil: Date?
    private static let rateLimitQueue = DispatchQueue(label: "com.modo.offclient.ratelimit")
    
    // MARK: - URLSession Configuration
    
    /// Custom URLSession: disable system cache (always fetch fresh data)
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForResource = requestTimeout
        config.timeoutIntervalForRequest = requestTimeout
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }()
    
    // MARK: - API Response Models
    
    nonisolated struct OffSearchResponse: Decodable {
        let products: [Product]
        
        nonisolated struct Product: Decodable {
            let product_name: String?
            let generic_name: String?
            let nutriments: Nutriments?
            let brands: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                product_name = try? container.decode(String.self, forKey: .product_name)
                generic_name = try? container.decode(String.self, forKey: .generic_name)
                nutriments = try? container.decode(Nutriments.self, forKey: .nutriments)
                brands = try? container.decode(String.self, forKey: .brands)
            }
            
            private enum CodingKeys: String, CodingKey {
                case product_name
                case generic_name
                case nutriments
                case brands
            }
            
            nonisolated struct Nutriments: Decodable {
                let energy_kcal_100g: Double?
                let energy_kcal_serving: Double?
                
                private enum CodingKeys: String, CodingKey {
                    case energy_kcal_100g = "energy-kcal_100g"
                    case energy_kcal_serving = "energy-kcal_serving"
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    // Handle energy_kcal_100g - can be Double or String
                    if let doubleValue = try? container.decode(Double.self, forKey: .energy_kcal_100g) {
                        energy_kcal_100g = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .energy_kcal_100g),
                              let doubleValue = Double(stringValue) {
                        energy_kcal_100g = doubleValue
                    } else {
                        energy_kcal_100g = nil
                    }
                    
                    // Handle energy_kcal_serving - can be Double or String
                    if let doubleValue = try? container.decode(Double.self, forKey: .energy_kcal_serving) {
                        energy_kcal_serving = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .energy_kcal_serving),
                              let doubleValue = Double(stringValue) {
                        energy_kcal_serving = doubleValue
                    } else {
                        energy_kcal_serving = nil
                    }
                }
            }
        }
    }
    
    // MARK: - API Errors
    
    enum OffError: Error, LocalizedError {
        case invalidResponse
        case rateLimited(retryAfter: TimeInterval?)
        case serverError(statusCode: Int)
        case networkError(Error)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid API response"
            case .rateLimited(let retryAfter):
                if let retryAfter = retryAfter {
                    return "Rate limited. Please try again in \(Int(retryAfter)) seconds"
                }
                return "Rate limited. Please try again later"
            case .serverError(let statusCode):
                return "Server error (\(statusCode))"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public Search Methods
    
    /// Search foods from cache only (no network)
    /// Returns empty array since caching is disabled
    static func searchFoodsFromCacheOnly(query: String, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        // No cache - always return empty
        DispatchQueue.main.async { completion([]) }
    }
    
    /// Search foods from network (always performs network request, no caching)
    /// Uses request deduplication to avoid multiple simultaneous requests for the same query
    static func searchFoodsCached(query: String, limit: Int = 50, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        let key = query.lowercased()
        
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
            searchFoodsNetworkWithRetry(query: query, limit: limit, retryCount: 0, maxRetries: maxRetries) { items in
                // Get all waiting completions and clear in-flight tracking
                let completions: [([MenuData.FoodItem]) -> Void] = requestQueue.sync {
                    let result = inFlightRequests[key] ?? []
                    inFlightRequests.removeValue(forKey: key)
                    return result
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
    
    // MARK: - Retry Logic
    
    /// Network search with improved retry logic
    /// Retries on: network errors, rate limiting, and server errors (5xx)
    /// Does not retry on: client errors (4xx except 429), invalid queries
    private static func searchFoodsNetworkWithRetry(query: String, limit: Int, retryCount: Int, maxRetries: Int, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        searchFoodsNetwork(query: query, limit: limit, onNetworkError: { error in
            // Determine if we should retry based on error type
            let shouldRetry: Bool
            let retryDelay: TimeInterval
            
            if let offError = error as? OffError {
                switch offError {
                case .rateLimited(let retryAfter):
                    // Always retry rate limiting, use provided delay or default
                    shouldRetry = retryCount < maxRetries
                    retryDelay = retryAfter ?? rateLimitDelay
                case .serverError(let statusCode):
                    // Retry server errors (5xx), but not client errors (4xx except 429)
                    shouldRetry = retryCount < maxRetries && statusCode >= 500
                    retryDelay = Double(retryCount + 1) * baseRetryDelay
                case .networkError:
                    // Retry network errors
                    shouldRetry = retryCount < maxRetries
                    retryDelay = Double(retryCount + 1) * baseRetryDelay
                case .invalidResponse, .decodingError:
                    // Don't retry invalid requests or decoding errors
                    shouldRetry = false
                    retryDelay = 0
                }
            } else {
                // Unknown error - treat as network error and retry
                shouldRetry = retryCount < maxRetries
                retryDelay = Double(retryCount + 1) * baseRetryDelay
            }
            
            if shouldRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    searchFoodsNetworkWithRetry(query: query, limit: limit, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }) { items in
            completion(items)
        }
    }

    // MARK: - Network Search
    
    /// Search foods from network with improved error handling
    static func searchFoodsNetwork(query: String, limit: Int = 50, onNetworkError: ((Error) -> Void)? = nil, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        guard query.count >= 2 else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        
        // Check rate limiting
        rateLimitQueue.sync {
            if let rateLimitedUntil = rateLimitedUntil, rateLimitedUntil > Date() {
                let retryAfter = rateLimitedUntil.timeIntervalSinceNow
                let error = OffError.rateLimited(retryAfter: retryAfter)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(error) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
        }
        
        // Build API URL
        // Using the search endpoint: /cgi/search.pl
        var components = URLComponents(string: "\(apiBaseURL)/cgi/search.pl")!
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        components.queryItems = [
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: String(min(limit, 100))), // Cap at 100
            // Request only essential fields: name and calories
            .init(name: "fields", value: "product_name,generic_name,brands,nutriments.energy-kcal_100g,nutriments.energy-kcal_serving"),
            .init(name: "search_terms", value: trimmedQuery)
        ]
        
        guard let url = components.url else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: requestTimeout)

        urlSession.dataTask(with: req) { data, response, error in
            // Handle network errors
            if let error = error {
                print("❌ OffClient: Network error for '\(query)': \(error.localizedDescription)")
                let networkError = NetworkError.from(error) ?? NetworkError.unknown(message: error.localizedDescription)
                let offError = OffError.networkError(networkError)
                
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OffClient: Invalid HTTP response for '\(query)'")
                let offError = OffError.invalidResponse
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - continue processing
                break
            case 429:
                // Rate limited
                print("⚠️ OffClient: Rate limited (429) for '\(query)'")
                let retryAfter = extractRetryAfter(from: httpResponse)
                rateLimitQueue.async {
                    rateLimitedUntil = Date().addingTimeInterval(retryAfter ?? rateLimitDelay)
                }
                let offError = OffError.rateLimited(retryAfter: retryAfter)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            case 400...499:
                // Client error
                print("❌ OffClient: Client error (\(httpResponse.statusCode)) for '\(query)'")
                let offError = OffError.serverError(statusCode: httpResponse.statusCode)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            case 500...599:
                // Server error
                print("❌ OffClient: Server error (\(httpResponse.statusCode)) for '\(query)'")
                let offError = OffError.serverError(statusCode: httpResponse.statusCode)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            default:
                print("⚠️ OffClient: Unexpected status code (\(httpResponse.statusCode)) for '\(query)'")
                let offError = OffError.serverError(statusCode: httpResponse.statusCode)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Decode response
            let decoded: OffSearchResponse
            do {
                let decoder = JSONDecoder()
                decoded = try decoder.decode(OffSearchResponse.self, from: data)
            } catch {
                print("❌ OffClient: Decoding error for '\(query)': \(error.localizedDescription)")
                let offError = OffError.decodingError(error)
                if let onNetworkError = onNetworkError {
                    DispatchQueue.main.async { onNetworkError(offError) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            
            // Map products to FoodItems - only extract name and calories
            var mapped: [MenuData.FoodItem] = []
            
            // Store product data with brands for filtering
            struct ProductWithBrand {
                let item: MenuData.FoodItem
                let brand: String?
            }
            var productsWithBrands: [ProductWithBrand] = []
            
            for p in decoded.products {
                // Extract name: prioritize product_name, then generic_name
                // Do NOT use brands as name - skip products without product_name or generic_name
                let trimmedName = { (s: String?) -> String? in
                    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
                    return t
                }
                
                // Only use product_name or generic_name, never brands as the product name
                let name: String? = trimmedName(p.product_name) ?? trimmedName(p.generic_name)
                
                // Skip products without a real product name (product_name or generic_name)
                // We don't want to show just brand names like "McDonald's"
                guard let nameUnwrapped = name, !nameUnwrapped.isEmpty else {
                    continue
                }
                
                // Extract calories: prefer per-serving, then per-100g
                let kcalServing = p.nutriments?.energy_kcal_serving
                let kcal100g = p.nutriments?.energy_kcal_100g
                let calories: Int? = {
                    if let kcalServing = kcalServing {
                        return Int(round(kcalServing))
                    }
                    if let kcal100g = kcal100g {
                        return Int(round(kcal100g))
                    }
                    return nil
                }()
                
                // Store brand for filtering
                let brand = trimmedName(p.brands)
                
                // Determine caloriesPerServing and defaultUnit
                let caloriesPerServing: Int? = kcalServing != nil ? Int(round(kcalServing!)) : nil
                let defaultUnit = kcal100g != nil ? "g" : "serving"
                
                // Create FoodItem with only name and calories
                let item = MenuData.FoodItem(
                    id: UUID(),
                    name: nameUnwrapped,
                    calories: calories,
                    caloriesPer100g: kcal100g,
                    caloriesPerServing: caloriesPerServing,
                    defaultUnit: defaultUnit
                )
                productsWithBrands.append(ProductWithBrand(item: item, brand: brand))
            }
            
            // Filter: match query in product name or brand (case-insensitive)
            let queryLower = query.lowercased()
            productsWithBrands = productsWithBrands.filter { productWithBrand in
                let itemNameLower = productWithBrand.item.name.lowercased()
                var matches = itemNameLower.contains(queryLower)
                
                if !matches, let brand = productWithBrand.brand {
                    matches = brand.lowercased().contains(queryLower)
                }
                
                return matches
            }
            
            // Extract items from filtered products
            mapped = productsWithBrands.map { $0.item }
            
            // Simple sorting: prioritize items with calories, then alphabetical
            mapped.sort { a, b in
                // Prefer items with calories
                let aHasCalories = a.calories != nil
                let bHasCalories = b.calories != nil
                if aHasCalories != bHasCalories {
                    return aHasCalories && !bHasCalories
                }
                
                // Then alphabetical
                return a.name.lowercased() < b.name.lowercased()
            }
            
            // Count products with/without calories
            let withoutCalories = mapped.filter { $0.calories == nil }.count
            print("🔍 OffClient: Found \(mapped.count) products, \(withoutCalories) without calories")
            
            DispatchQueue.main.async {
                completion(mapped)
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Extract Retry-After header value from HTTP response
    private static func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfterString = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfter = TimeInterval(retryAfterString) {
            return retryAfter
        }
        return nil
    }
}


