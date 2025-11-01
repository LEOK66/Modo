import Foundation

// Minimal OFF client: name search → kcal mapping
enum OffClient {
    // Simple in-memory cache
    private static var memoryCache: [String: [MenuData.FoodItem]] = [:]
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
            private enum CodingKeys: String, CodingKey {
                case energy_kcal_100g = "energy-kcal_100g"
                case energy_100g
                case energy_unit
            }
        }
    }

    // Cached search: memory → disk → network
    static func searchFoodsCached(query: String, limit: Int = 50, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        let key = query.lowercased()
        if let cached = memoryCache[key] { completion(cached); return }
        if let disk = loadFromDisk(key: key) { memoryCache[key] = disk; completion(disk); return }
        searchFoodsNetwork(query: query, limit: limit) { items in
            memoryCache[key] = items
            saveToDisk(key: key, items: items)
            completion(items)
        }
    }

    static func searchFoodsNetwork(query: String, limit: Int = 50, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        guard query.count >= 2 else { completion([]); return }
        // OFF API: https://world.openfoodfacts.org/cgi/search.pl
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        var items: [URLQueryItem] = [
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: String(limit)),
            .init(name: "fields", value: "product_name,generic_name,brands,categories_tags,nutriments.energy-kcal_100g,nutriments.energy_100g,nutriments.energy_unit"),
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
        guard let url = components.url else { completion([]); return }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 8)
        req.setValue("ModoApp/1.0 (iOS) OFF Lookup", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let decoded = try? JSONDecoder().decode(OffSearchResponse.self, from: data) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            var mapped: [MenuData.FoodItem] = decoded.products.compactMap { p in
                let trimmedName = { (s: String?) -> String? in
                    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
                    return t
                }
                let name = trimmedName(p.product_name) ?? trimmedName(p.generic_name) ?? trimmedName(p.brands)
                guard let nameUnwrapped = name else { return nil }
                var kcal: Double? = p.nutriments?.energy_kcal_100g
                if kcal == nil, let e100 = p.nutriments?.energy_100g, let unit = p.nutriments?.energy_unit?.lowercased() {
                    if unit == "kcal" { kcal = e100 }
                    else if unit == "kj" { kcal = e100 / 4.184 }
                }
                guard let kcalVal = kcal else { return nil }
                return MenuData.FoodItem(name: nameUnwrapped, calories: Int(round(kcalVal)))
            }
            // client-side filter/sort (robust contains: ignore case & punctuation)
            let qNorm = normalize(qLower)
            mapped = mapped.filter { item in
                let nNorm = normalize(item.name)
                if let brand = matchedBrand { return nNorm.contains(normalize(brand)) || nNorm.contains(qNorm) }
                return nNorm.contains(qNorm)
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
}


