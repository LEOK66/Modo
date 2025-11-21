import SwiftUI

/// Diet entries card component for task form
struct DietEntriesCardView: View {
    @Binding var dietEntries: [DietEntry]
    @Binding var editingDietEntryIndex: Int?
    @Binding var titleText: String
    @FocusState.Binding var dietNameFocusIndex: Int?
    @Binding var pendingScrollId: String?
    
    let onAddFoodItem: () -> Void
    let onEditFoodItem: (Int) -> Void
    let onDeleteFoodItem: (Int) -> Void
    let onClearAll: () -> Void
    let onRecalcCalories: (Int) -> Void
    let onTriggerHaptic: () -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Diet Items")
                    Spacer()
                    if !dietEntries.isEmpty {
                        Button("Clear all") {
                            onClearAll()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dietEntries.indices, id: \.self) { idx in
                        dietEntryRow(at: idx)
                            .id("diet-\(idx)")
                    }
                    
                    Button(action: onAddFoodItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hexString: "16A34A"))
                            Text("Add Food Item")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "16A34A"))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(hexString: "16A34A").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hexString: "16A34A"), lineWidth: 1)
                                .opacity(0.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                if !dietEntries.isEmpty {
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            Text("Total Calories")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(totalDietCalories) cal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "16A34A"))
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No food items added yet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Tap 'Add Food Item' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
    }
    
    private var totalDietCalories: Int {
        dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private func dietEntryRow(at index: Int) -> some View {
        let entry = dietEntries[index]
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    onEditFoodItem(index)
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(entry.food?.name ?? (entry.customName.isEmpty ? "Choose Food" : entry.customName))
                            .foregroundColor(entry.food != nil ? .primary : .secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onDeleteFoodItem(index)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hexString: "EF4444"))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField(placeholderForUnit(entry.unit), text: Binding(
                        get: { dietEntries[index].quantityText },
                        set: { newValue in
                            // Allow decimal point
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            // Ensure only one decimal point
                            let components = filtered.components(separatedBy: ".")
                            if components.count <= 2 {
                                dietEntries[index].quantityText = filtered
                                onRecalcCalories(index)
                            }
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                }
                
                // Dynamically show unit options based on food data
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    let hasGrams = entry.food?.hasPer100g == true
                    let hasServing = entry.food?.servingCalories != nil
                    
                    Picker(selection: Binding(
                        get: { dietEntries[index].unit },
                        set: { newValue in
                            let oldUnit = dietEntries[index].unit
                            dietEntries[index].unit = newValue
                            
                            // Smart quantity adjustment
                            if oldUnit != newValue {
                                if newValue == "g" && (dietEntries[index].quantityText == "1" || dietEntries[index].quantityText.isEmpty) {
                                    dietEntries[index].quantityText = "100"
                                } else if newValue == "lbs" && (dietEntries[index].quantityText == "100" || dietEntries[index].quantityText.isEmpty) {
                                    dietEntries[index].quantityText = "1"
                                } else if newValue == "kg" && (dietEntries[index].quantityText == "100" || dietEntries[index].quantityText.isEmpty) {
                                    dietEntries[index].quantityText = "1"
                                } else if newValue == "serving" && (dietEntries[index].quantityText == "100" || dietEntries[index].quantityText.isEmpty) {
                                    dietEntries[index].quantityText = "1"
                                }
                            }
                            
                            onRecalcCalories(index)
                        }
                    )) {
                        if entry.food == nil {
                            Text("serving").tag("serving")
                            Text("kg").tag("kg")
                            Text("lbs").tag("lbs")
                        } else {
                            if hasServing && hasGrams {
                                Text("serving").tag("serving")
                                Text("grams").tag("g")
                                Text("lbs").tag("lbs")
                            } else if hasGrams {
                                Text("grams").tag("g")
                                Text("lbs").tag("lbs")
                            } else {
                                Text("serving").tag("serving")
                            }
                        }
                    } label: {
                        Text(unitLabel(dietEntries[index].unit))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { dietEntries[index].caloriesText },
                            set: { newValue in
                                dietEntries[index].caloriesText = newValue.filter { $0.isNumber }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                        Text("cal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Macro nutrients display (read-only)
            HStack(spacing: 8) {
                macroNutrientView(label: "Protein", value: macroValue(for: entry, type: .protein))
                macroNutrientView(label: "Fat", value: macroValue(for: entry, type: .fat))
                macroNutrientView(label: "Carbs", value: macroValue(for: entry, type: .carbs))
            }
            
            if entry.food == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Diet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("e.g., Homemade smoothie", text: Binding(
                        get: { dietEntries[index].customName },
                        set: { newValue in dietEntries[index].customName = newValue }
                    ))
                    .focused($dietNameFocusIndex, equals: index)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
    
    private func placeholderForUnit(_ unit: String) -> String {
        switch unit {
        case "g": return "100"
        case "lbs": return "1"
        case "kg": return "1"
        default: return "1"
        }
    }
    
    private func unitLabel(_ unit: String) -> String {
        switch unit {
        case "g": return "grams"
        case "lbs": return "lbs"
        case "kg": return "kg"
        default: return "serving"
        }
    }
    
    private enum MacroType {
        case protein
        case fat
        case carbs
    }
    
    private func macroValue(for entry: DietEntry, type: MacroType) -> String {
        // TODO: Replace with actual macro data from food item when available
        // For now, return placeholder or empty string
        guard let food = entry.food else { return "-" }
        
        // This will be populated when macro data is added to FoodItem
        // Example: return food.proteinPer100g, food.fatPer100g, food.carbsPer100g
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
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var dietEntries: [DietEntry] = [
            DietEntry(quantityText: "1", unit: "serving", caloriesText: "200")
        ]
        @State private var editingDietEntryIndex: Int? = nil
        @State private var titleText = ""
        @FocusState private var dietNameFocusIndex: Int?
        @State private var pendingScrollId: String? = nil
        
        var body: some View {
            DietEntriesCardView(
                dietEntries: $dietEntries,
                editingDietEntryIndex: $editingDietEntryIndex,
                titleText: $titleText,
                dietNameFocusIndex: $dietNameFocusIndex,
                pendingScrollId: $pendingScrollId,
                onAddFoodItem: {
                    dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
                },
                onEditFoodItem: { index in
                    editingDietEntryIndex = index
                },
                onDeleteFoodItem: { index in
                    dietEntries.remove(at: index)
                },
                onClearAll: {
                    dietEntries.removeAll()
                },
                onRecalcCalories: { _ in },
                onTriggerHaptic: {}
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

