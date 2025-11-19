import SwiftUI

/// Quick pick sheet for selecting food items or exercises
struct QuickPickSheetView: View {
    enum QuickPickMode {
        case food
        case exercise
    }
    
    @Binding var isPresented: Bool
    var mode: QuickPickMode?
    @Binding var searchText: String
    @FocusState private var searchFieldFocused: Bool
    
    // Diet entries
    @Binding var dietEntries: [DietEntry]
    @Binding var editingDietEntryIndex: Int?
    
    // Fitness entries
    @Binding var fitnessEntries: [FitnessEntry]
    @Binding var editingFitnessEntryIndex: Int?
    
    // Title text (for auto-fill)
    @Binding var titleText: String
    
    // Recent items (in-memory)
    @Binding var recentFoods: [MenuData.FoodItem]
    @Binding var recentExercises: [MenuData.ExerciseItem]
    
    // Online search
    @Binding var onlineFoods: [MenuData.FoodItem]
    @Binding var isOnlineLoading: Bool
    
    // Callbacks
    let onRecalcDietCalories: (Int) -> Void
    let onPendingScrollId: (String?) -> Void
    let onSetDietFocusIndex: (Int?) -> Void
    let onSetFitnessFocusIndex: (Int?) -> Void
    let onSearchFoods: (String, @escaping ([MenuData.FoodItem]) -> Void) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchFieldFocused)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if mode == .food {
                        foodContent
                    } else if mode == .exercise {
                        exerciseContent
                    }
                }
            }
            Button("Close") {
                isPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .presentationDetents([.fraction(0.6)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Auto-focus search field when sheet appears
            searchFieldFocused = true
        }
        .onChange(of: isPresented) { _, isPresented in
            if !isPresented {
                // Clear focus when sheet is dismissed
                searchFieldFocused = false
            }
        }
        .onChange(of: searchText) { _, newValue in
            guard mode == .food else { return }
            handleFoodSearch(query: newValue)
        }
    }
    
    @ViewBuilder
    private var foodContent: some View {
        // Custom option
        Button(action: {
            if let pickIndex = editingDietEntryIndex, pickIndex < dietEntries.count {
                dietEntries[pickIndex].food = nil
                // keep user's customName if any; ensure defaults
                if dietEntries[pickIndex].unit.isEmpty { dietEntries[pickIndex].unit = "serving" }
                if dietEntries[pickIndex].quantityText.isEmpty { dietEntries[pickIndex].quantityText = "1" }
                editingDietEntryIndex = nil
                onSetDietFocusIndex(pickIndex)
                onPendingScrollId("diet-\(pickIndex)")
            }
            isPresented = false
        }) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.secondary)
                Text("Customize Diet")
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)

        let local = MenuData.foods.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }
        if !recentFoods.isEmpty {
            Text("Recent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(recentFoods) { item in
                foodItemRow(item: item)
            }
        }
        
        if !local.isEmpty {
            Text("Local results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(local) { item in
                foodItemRow(item: item)
            }
        }
        
        if isOnlineLoading {
            Text("Searching online")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        
        if !onlineFoods.isEmpty {
            Text("Online results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(onlineFoods) { item in
                foodItemRow(item: item)
            }
        }
    }
    
    @ViewBuilder
    private var exerciseContent: some View {
        // Custom option
        Button(action: {
            if let idx = editingFitnessEntryIndex, idx < fitnessEntries.count {
                fitnessEntries[idx].exercise = nil
                if fitnessEntries[idx].minutesInt == 0 { /* keep 0, user can set */ }
                editingFitnessEntryIndex = nil
                onSetFitnessFocusIndex(idx)
                onPendingScrollId("fit-\(idx)")
            }
            isPresented = false
        }) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.secondary)
                Text("Customize Exercise")
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)

        let filteredExercises = MenuData.exercises.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }
        if !recentExercises.isEmpty {
            Text("Recent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(recentExercises) { item in
                exerciseItemRow(item: item)
            }
        }
        
        if !filteredExercises.isEmpty {
            Text("Local results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            ForEach(filteredExercises) { item in
                exerciseItemRow(item: item)
            }
        } else {
            if !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 24))
                        .foregroundColor(Color.secondary.opacity(0.6))
                    Text("No exercises found")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.system(size: 12))
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }
    
    private func foodItemRow(item: MenuData.FoodItem) -> some View {
        Button(action: {
            if let pickIndex = editingDietEntryIndex {
                dietEntries[pickIndex].food = item
                dietEntries[pickIndex].customName = ""
                let u = item.defaultUnit ?? (item.hasPer100g ? "g" : "serving")
                dietEntries[pickIndex].unit = u
                if u == "g" {
                    dietEntries[pickIndex].quantityText = "100"
                } else if u == "lbs" {
                    dietEntries[pickIndex].quantityText = "1"
                } else {
                    dietEntries[pickIndex].quantityText = "1"
                }
                
                onRecalcDietCalories(pickIndex)
                editingDietEntryIndex = nil
            }
            // recents: move to top if exists, otherwise add at top (use name as unique key since UUID regenerates)
            recentFoods.removeAll(where: { $0.name == item.name })
            recentFoods.insert(item, at: 0)
            if recentFoods.count > 5 { recentFoods.removeLast() }
            
            if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                titleText = item.name
            }
            isPresented = false
        }) {
            HStack {
                Text(item.name)
                Spacer()
                Text(quickPickCaloriesLabel(food: item))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func exerciseItemRow(item: MenuData.ExerciseItem) -> some View {
        Button(action: {
            if let idx = editingFitnessEntryIndex {
                fitnessEntries[idx].exercise = item
                fitnessEntries[idx].customName = ""
                if fitnessEntries[idx].minutesInt == 0 { fitnessEntries[idx].minutesInt = 30 }
                let per30 = item.calPer30Min
                let est = Int(round(Double(per30) * Double(fitnessEntries[idx].minutesInt) / 30.0))
                fitnessEntries[idx].caloriesText = String(est)
                editingFitnessEntryIndex = nil
            }
            // recents: move to top if exists, otherwise add at top (use name as unique key since UUID regenerates)
            recentExercises.removeAll(where: { $0.name == item.name })
            recentExercises.insert(item, at: 0)
            if recentExercises.count > 5 { recentExercises.removeLast() }
            if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleText = item.name }
            isPresented = false
        }) {
            HStack {
                Text(item.name)
                Spacer()
                Text("~\(item.calPer30Min) cal / 30m")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func quickPickCaloriesLabel(food: MenuData.FoodItem) -> String {
        if food.defaultUnit == "g" || (food.caloriesPer100g != nil && food.servingCalories == nil) {
            if let per100 = food.caloriesPer100g {
                return "\(Int(round(per100))) cal/100g"
            }
        } else {
            if let per = food.servingCalories {
                return "\(per) cal"
            }
        }
        return "–"
    }
    
    private func handleFoodSearch(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            onlineFoods = []
            return
        }
        isOnlineLoading = true
        onSearchFoods(q) { results in
            isOnlineLoading = false
            onlineFoods = results
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var searchText = ""
        @State private var dietEntries: [DietEntry] = []
        @State private var editingDietEntryIndex: Int? = nil
        @State private var fitnessEntries: [FitnessEntry] = []
        @State private var editingFitnessEntryIndex: Int? = nil
        @State private var titleText = ""
        @State private var recentFoods: [MenuData.FoodItem] = []
        @State private var recentExercises: [MenuData.ExerciseItem] = []
        @State private var onlineFoods: [MenuData.FoodItem] = []
        @State private var isOnlineLoading = false
        
        var body: some View {
            QuickPickSheetView(
                isPresented: $isPresented,
                mode: .food,
                searchText: $searchText,
                dietEntries: $dietEntries,
                editingDietEntryIndex: $editingDietEntryIndex,
                fitnessEntries: $fitnessEntries,
                editingFitnessEntryIndex: $editingFitnessEntryIndex,
                titleText: $titleText,
                recentFoods: $recentFoods,
                recentExercises: $recentExercises,
                onlineFoods: $onlineFoods,
                isOnlineLoading: $isOnlineLoading,
                onRecalcDietCalories: { _ in },
                onPendingScrollId: { _ in },
                onSetDietFocusIndex: { _ in },
                onSetFitnessFocusIndex: { _ in },
                onSearchFoods: { _, completion in
                    completion([])
                }
            )
        }
    }
    
    return PreviewWrapper()
}

