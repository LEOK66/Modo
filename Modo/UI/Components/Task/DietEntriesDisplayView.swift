import SwiftUI

/// Display view for diet entries (read-only)
struct DietEntriesDisplayView: View {
    let entries: [DietEntry]
    
    private var totalCalories: Int {
        entries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private var totalProtein: Double {
        entries.map { macroValueDouble(for: $0, type: .protein) }.reduce(0, +)
    }
    
    private var totalFat: Double {
        entries.map { macroValueDouble(for: $0, type: .fat) }.reduce(0, +)
    }
    
    private var totalCarbs: Double {
        entries.map { macroValueDouble(for: $0, type: .carbs) }.reduce(0, +)
    }
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Food Items")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(entry.food?.name ?? entry.customName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Text("\(entry.quantityText) \(entry.unit)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(entry.caloriesText) cal")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "16A34A"))
                        }
                        
                        // Macro nutrients display (only if available)
                        if hasMacroNutrients(for: entry) {
                            HStack(spacing: 8) {
                                macroNutrientView(label: "Protein", value: macroValue(for: entry, type: .protein))
                                macroNutrientView(label: "Fat", value: macroValue(for: entry, type: .fat))
                                macroNutrientView(label: "Carbs", value: macroValue(for: entry, type: .carbs))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Divider()
                    .background(Color(UIColor.separator))
                
                // Total calories
                HStack {
                    Text("Total Calories")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(totalCalories) cal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "16A34A"))
                }
                
                // Total macro nutrients (only if any entry has macro data and totals > 0)
                if hasAnyMacroNutrients && (totalProtein > 0 || totalFat > 0 || totalCarbs > 0) {
                    Divider()
                        .background(Color(UIColor.separator))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total Macros")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            macroNutrientView(label: "Protein", value: totalProtein > 0 ? String(format: "%.1f", totalProtein) : "-")
                            macroNutrientView(label: "Fat", value: totalFat > 0 ? String(format: "%.1f", totalFat) : "-")
                            macroNutrientView(label: "Carbs", value: totalCarbs > 0 ? String(format: "%.1f", totalCarbs) : "-")
                        }
                    }
                }
            }
        }
    }
    
    private var hasAnyMacroNutrients: Bool {
        entries.contains { hasMacroNutrients(for: $0) }
    }
    
    private func hasMacroNutrients(for entry: DietEntry) -> Bool {
        guard let food = entry.food else { return false }
        return food.proteinPer100g != nil || food.fatPer100g != nil || food.carbsPer100g != nil ||
               food.proteinPerServing != nil || food.fatPerServing != nil || food.carbsPerServing != nil
    }
    
    private enum MacroType {
        case protein
        case fat
        case carbs
    }
    
    private func macroValueDouble(for entry: DietEntry, type: MacroType) -> Double {
        guard let food = entry.food else { return 0.0 }
        
        // Parse quantity from text
        let quantity = Double(entry.quantityText) ?? 0.0
        guard quantity > 0 else { return 0.0 }
        
        // Get base nutrient value based on type
        let per100g: Double?
        let perServing: Double?
        
        switch type {
        case .protein:
            per100g = food.proteinPer100g
            perServing = food.proteinPerServing
        case .fat:
            per100g = food.fatPer100g
            perServing = food.fatPerServing
        case .carbs:
            per100g = food.carbsPer100g
            perServing = food.carbsPerServing
        }
        
        // Calculate actual value based on unit and quantity
        let calculatedValue: Double?
        
        if entry.unit == "g" {
            // User entered grams
            if let per100g = per100g {
                // Use per-100g data: (per-100g value / 100) * quantity
                calculatedValue = (per100g / 100.0) * quantity
            } else if let perServing = perServing {
                // Fallback to per-serving if per-100g not available
                // This is approximate - we assume 1 serving = 100g if not specified
                calculatedValue = (perServing / 100.0) * quantity
            } else {
                calculatedValue = nil
            }
        } else {
            // User entered servings (or other units)
            if let perServing = perServing {
                // Use per-serving data: per-serving value * quantity
                calculatedValue = perServing * quantity
            } else if let per100g = per100g {
                // Fallback to per-100g if per-serving not available
                // Assume 1 serving = 100g (standard assumption)
                calculatedValue = per100g * quantity
            } else {
                calculatedValue = nil
            }
        }
        
        return calculatedValue ?? 0.0
    }
    
    private func macroValue(for entry: DietEntry, type: MacroType) -> String {
        let value = macroValueDouble(for: entry, type: type)
        if value > 0 {
            return String(format: "%.1f", value)
        }
        return "-"
    }
    
    private func macroNutrientView(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label)(g)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 3, x: 0, y: 1)
        .shadow(color: Color.primary.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

