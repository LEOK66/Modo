import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [MainPageView.TaskItem]
    @Binding var newlyAddedTaskId: UUID?
    // Form state
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var timeDate: Date = Date()
    @State private var isTimeSheetPresented: Bool = false
    @State private var selectedCategory: Category? = nil
    @State private var isDurationSheetPresented: Bool = false
    @State private var durationHoursInt: Int = 0
    @State private var durationMinutesInt: Int = 0
    @State private var isQuickPickPresented: Bool = false
    @State private var quickPickMode: QuickPickMode? = nil
    @State private var quickPickSearch: String = ""
    @State private var onlineFoods: [MenuData.FoodItem] = []
    @State private var isOnlineLoading: Bool = false
    @State private var searchDebounceWork: DispatchWorkItem? = nil
    
    // Lightweight Recents (in-memory per session)
    @State private var recentFoods: [MenuData.FoodItem] = []
    @State private var recentExercises: [MenuData.ExerciseItem] = []
    
    // Undo delete snackbars
    @State private var showUndoBanner: Bool = false
    @State private var undoMessage: String = ""
    private struct DeletedDietContext { let entry: DietEntry; let index: Int }
    private struct DeletedFitnessContext { let entry: FitnessEntry; let index: Int }
    @State private var lastDeletedDiet: DeletedDietContext? = nil
    @State private var lastDeletedFitness: DeletedFitnessContext? = nil
    @State private var lastClearedDiet: [DietEntry]? = nil
    @State private var lastClearedFitness: [FitnessEntry]? = nil
    
    // Focus and scroll
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    @FocusState private var searchFieldFocused: Bool
    @State private var pendingScrollId: String? = nil
    
    // AI UI placeholders
    @State private var isAIGenerateSheetPresented: Bool = false
    @State private var isAskAISheetPresented: Bool = false
    @State private var aiPromptText: String = ""

    struct DietEntry: Identifiable, Equatable {
        let id = UUID()
        var food: MenuData.FoodItem?
        var customName: String = ""
        var quantityText: String = ""
        var unit: String = "serving"
        var caloriesText: String = ""
        
        init(food: MenuData.FoodItem? = nil, customName: String = "", quantityText: String = "", unit: String = "serving", caloriesText: String = "") {
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
    
    @State private var dietEntries: [DietEntry] = []
    @State private var editingDietEntryIndex: Int? = nil
    
    struct FitnessEntry: Identifiable, Equatable {
        let id = UUID()
        var exercise: MenuData.ExerciseItem?
        var customName: String = ""
        var minutesInt: Int = 0
        var caloriesText: String = ""
        
        static func == (lhs: FitnessEntry, rhs: FitnessEntry) -> Bool {
            lhs.id == rhs.id && lhs.exercise?.id == rhs.exercise?.id && lhs.customName == rhs.customName && lhs.minutesInt == rhs.minutesInt && lhs.caloriesText == rhs.caloriesText
        }
    }
    
    @State private var fitnessEntries: [FitnessEntry] = []
    @State private var editingFitnessEntryIndex: Int? = nil
    
    var totalDietCalories: Int {
        dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }

    enum QuickPickMode { case food, exercise }
    
    enum Category: String, CaseIterable, Identifiable {
        case diet = "🥗 Diet"
        case fitness = "🏃 Fitness"
        case others = "📌 Others"
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            VStack(spacing: 0) {
                PageHeader(title: "Add New Task")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                Spacer().frame(height: 12)
                // AI Toolbar
                HStack(spacing: 12) {
                    Spacer()
                    Button(action: { isAskAISheetPresented = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.white)
                            Text("Ask AI")
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(Color(hexString: "9810FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Button(action: { isAIGenerateSheetPresented = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .foregroundColor(.white)
                            Text("AI Generate")
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                        titleCard
                        descriptionCard
                        timeCard
                        categoryCard
                        if selectedCategory == .diet {
                            caloriesCard
                        }
                        if selectedCategory == .fitness {
                            fitnessEntriesCard
                        }
                        Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: pendingScrollId) { _, newValue in
                        guard let id = newValue else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                        pendingScrollId = nil
                    }
                }
                .background(Color(hexString: "F3F4F6"))
                .padding(.top, 8)
                bottomActionBar
            }
            // Undo banner
            if showUndoBanner {
                HStack(spacing: 12) {
                    Text(undoMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "101828"))
                    Spacer()
                    Button("Undo") {
                        if let snapshot = lastClearedDiet {
                            dietEntries = snapshot
                            lastClearedDiet = nil
                        } else if let snapshotF = lastClearedFitness {
                            fitnessEntries = snapshotF
                            lastClearedFitness = nil
                        } else if let ctx = lastDeletedDiet {
                            dietEntries.insert(ctx.entry, at: min(ctx.index, dietEntries.count))
                            lastDeletedDiet = nil
                        } else if let ctx = lastDeletedFitness {
                            fitnessEntries.insert(ctx.entry, at: min(ctx.index, fitnessEntries.count))
                            lastDeletedFitness = nil
                        }
                        withAnimation { showUndoBanner = false }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isQuickPickPresented) {
            quickPickSheet
        }
        .sheet(isPresented: $isAIGenerateSheetPresented) {
            aiSheetView(title: "Describe your plan", buttonText: "Generate (coming soon)")
        }
        .sheet(isPresented: $isAskAISheetPresented) {
            aiSheetView(title: "Ask AI about this task", buttonText: "Send (coming soon)")
        }
        .sheet(isPresented: $isDurationSheetPresented) {
            VStack(spacing: 8) {
                HStack {
                    VStack {
                        Text("Hours")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6A7282"))
                        Picker("Hours", selection: $durationHoursInt) {
                            ForEach(0...5, id: \.self) { Text("\($0)") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: durationHoursInt) { _, _ in
                            recalcCaloriesFromDurationIfNeeded()
                        }
                    }
                    VStack {
                        Text("Minutes")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6A7282"))
                        Picker("Minutes", selection: $durationMinutesInt) {
                            ForEach(0...59, id: \.self) { Text("\($0)") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: durationMinutesInt) { _, _ in
                            recalcCaloriesFromDurationIfNeeded()
                        }
                    }
                }
                Button("Done") {
                    recalcCaloriesFromDurationIfNeeded()
                    isDurationSheetPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(16)
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: isQuickPickPresented) { _, isPresented in
            if !isPresented {
                // Dismiss search field focus to prevent keyboard from causing scroll
                searchFieldFocused = false
                // Only clear editing indices, don't trigger any scrolling
                if editingDietEntryIndex != nil {
                    editingDietEntryIndex = nil
                }
                if editingFitnessEntryIndex != nil {
                    editingFitnessEntryIndex = nil
                }
            }
        }
        
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - View Components
    private var titleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    label("Task Title")
                    Spacer()
                    Button(action: {
                        aiPromptText = titleText.isEmpty ? "Generate a concise, clear task title" : "Improve this title: \(titleText)"
                        isAskAISheetPresented = true
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color(hexString: "9810FA"))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    TextField("e.g., Morning Run", text: $titleText)
                        .textInputAutocapitalization(.words)
                        .onChange(of: titleText) { _, newValue in
                            if newValue.count > 40 { titleText = String(newValue.prefix(40)) }
                        }
                        .textFieldStyle(.plain)
                    if !titleText.isEmpty {
                        Button(action: { titleText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hexString: "9CA3AF"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(hexString: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                }
            }
        }
    }

    private var descriptionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    label("Description")
                    Spacer()
                    Button(action: {
                        aiPromptText = descriptionText.isEmpty ? "Write a brief, helpful task description" : "Improve this description: \(descriptionText)"
                        isAskAISheetPresented = true
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color(hexString: "9810FA"))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                ZStack(alignment: .topTrailing) {
                    TextField("e.g., 5km jog in the park", text: $descriptionText, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    if !descriptionText.isEmpty {
                        Button(action: { descriptionText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hexString: "9CA3AF"))
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(hexString: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var timeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Time")
                Button(action: { isTimeSheetPresented = true }) {
                    HStack {
                        Text(formattedTime)
                            .foregroundColor(Color(hexString: "0A0A0A"))
                        Spacer()
                        Image(systemName: "clock")
                            .foregroundColor(Color(hexString: "6A7282"))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isTimeSheetPresented) {
                    VStack(spacing: 12) {
                        DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        Button("Done") { isTimeSheetPresented = false }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(16)
                    .presentationDetents([.fraction(0.35)])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var categoryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Category")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    categoryChip(.diet)
                    categoryChip(.fitness)
                    categoryChip(.others)
                }
                if selectedCategory == nil {
                    Text("Required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                }
                // AI suggestions row (placeholder)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        aiSuggestionChip("Low-fat lunch â€¢ 600 cal")
                        aiSuggestionChip("30m run after 7pm")
                        aiSuggestionChip("High-protein dinner")
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var caloriesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Diet Items")
                    Spacer()
                    if !dietEntries.isEmpty {
                        Button("Clear all") {
                            let count = dietEntries.count
                            lastClearedDiet = dietEntries
                            dietEntries.removeAll()
                            undoMessage = count > 1 ? "Diet items cleared" : "Diet item cleared"
                            withAnimation { showUndoBanner = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showUndoBanner = false }
                                lastClearedDiet = nil
                            }
                            triggerHapticLight()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dietEntries.indices, id: \.self) { idx in
                        dietEntryRow(at: idx)
                            .id("diet-\(idx)")
                    }
                    
                    Button(action: {
                        dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
                        editingDietEntryIndex = dietEntries.count - 1
                        quickPickMode = .food
                        quickPickSearch = ""
                        isQuickPickPresented = true
                        triggerHapticLight()
                    }) {
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
                        .background(Color(hexString: "F0FDF4"))
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
                                .foregroundColor(Color(hexString: "0A0A0A"))
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
                            .foregroundColor(Color(hexString: "D1D5DB"))
                        Text("No food items added yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text("Tap 'Add Food Item' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
    }
    
    private func dietEntryRow(at index: Int) -> some View {
        let entry = dietEntries[index]
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    editingDietEntryIndex = index
                    quickPickMode = .food
                    quickPickSearch = ""
                    isQuickPickPresented = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text(entry.food?.name ?? (entry.customName.isEmpty ? "Choose Food" : entry.customName))
                            .foregroundColor(entry.food != nil ? Color(hexString: "0A0A0A") : Color(hexString: "6B7280"))
                            .lineLimit(1)
                        
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hexString: "9CA3AF"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let removed = dietEntries.remove(at: index)
                    lastDeletedDiet = DeletedDietContext(entry: removed, index: index)
                    undoMessage = "Diet item deleted"
                    withAnimation { showUndoBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showUndoBanner = false }
                        lastDeletedDiet = nil
                    }
                    triggerHapticMedium()
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
                        .foregroundColor(Color(hexString: "6B7280"))
                    TextField(placeholderForUnit(entry.unit), text: Binding(
                        get: { dietEntries[index].quantityText },
                        set: { newValue in
                            // å…è®¸å°æ•°ç‚¹
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            // ç¡®ä¿åªæœ‰ä¸€ä¸ªå°æ•°ç‚¹
                            let components = filtered.components(separatedBy: ".")
                            if components.count <= 2 {
                                dietEntries[index].quantityText = filtered
                                recalcEntryCalories(index)
                            }
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                // éœ€æ±‚2: æ ¹æ®é£Ÿç‰©æ•°æ®åŠ¨æ€æ˜¾ç¤ºå•ä½é€‰é¡¹
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    
                    let hasGrams = entry.food?.hasPer100g == true
                    let hasServing = entry.food?.servingCalories != nil
                    
                    Picker(selection: Binding(
                        get: { dietEntries[index].unit },
                        set: { newValue in
                            let oldUnit = dietEntries[index].unit
                            dietEntries[index].unit = newValue
                            
                            // æ™ºèƒ½è°ƒæ•´æ•°é‡
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
                            
                            recalcEntryCalories(index)
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
                        .foregroundColor(Color(hexString: "6B7280"))
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
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text("cal")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "6B7280"))
                    }
                }
            }
            
            if entry.food == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Diet")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    TextField("e.g., Homemade smoothie", text: Binding(
                        get: { dietEntries[index].customName },
                        set: { newValue in dietEntries[index].customName = newValue }
                    ))
                    .focused($dietNameFocusIndex, equals: index)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(12)
        .background(Color(hexString: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private var fitnessEntriesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Exercises")
                    Spacer()
                    if !fitnessEntries.isEmpty {
                        Button("Clear all") {
                            lastClearedFitness = fitnessEntries
                            fitnessEntries.removeAll()
                            undoMessage = "Exercises cleared"
                            withAnimation { showUndoBanner = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showUndoBanner = false }
                                lastClearedFitness = nil
                            }
                            triggerHapticLight()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fitnessEntries.indices, id: \.self) { idx in
                        fitnessEntryRow(at: idx)
                            .id("fit-\(idx)")
                    }
                    
                    Button(action: {
                        fitnessEntries.append(FitnessEntry())
                        editingFitnessEntryIndex = fitnessEntries.count - 1
                        quickPickMode = .exercise
                        quickPickSearch = ""
                        isQuickPickPresented = true
                        triggerHapticLight()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hexString: "364153"))
                            Text("Add Exercise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "364153"))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hexString: "364153"), lineWidth: 1)
                                .opacity(0.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                if !fitnessEntries.isEmpty {
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            Text("Total Calories")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "0A0A0A"))
                            Spacer()
                            Text("\(totalFitnessCalories) cal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hexString: "D1D5DB"))
                        Text("No exercise added yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text("Tap 'Add Exercise' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
    }

    private func fitnessEntryRow(at index: Int) -> some View {
        let entry = fitnessEntries[index]
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    editingFitnessEntryIndex = index
                    quickPickMode = .exercise
                    quickPickSearch = ""
                    isQuickPickPresented = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text(entry.exercise?.name ?? (entry.customName.isEmpty ? "Choose Exercise" : entry.customName))
                            .foregroundColor(entry.exercise != nil ? Color(hexString: "0A0A0A") : Color(hexString: "6B7280"))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hexString: "9CA3AF"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let removed = fitnessEntries.remove(at: index)
                    lastDeletedFitness = DeletedFitnessContext(entry: removed, index: index)
                    undoMessage = "Exercise deleted"
                    withAnimation { showUndoBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showUndoBanner = false }
                        lastDeletedFitness = nil
                    }
                    triggerHapticMedium()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hexString: "EF4444"))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    Button(action: {
                        let total = max(0, entry.minutesInt)
                        durationHoursInt = total / 60
                        durationMinutesInt = total % 60
                        isDurationSheetPresented = true
                        // tie the wheel to this entry index via editingFitnessEntryIndex
                        editingFitnessEntryIndex = index
                    }) {
                        HStack {
                            Text(entry.minutesInt > 0 ? formattedDuration(h: entry.minutesInt / 60, m: entry.minutesInt % 60) : "-")
                                .foregroundColor(Color(hexString: "0A0A0A"))
                            Spacer()
                            Image(systemName: "timer")
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { fitnessEntries[index].caloriesText },
                            set: { newValue in
                                fitnessEntries[index].caloriesText = newValue.filter { $0.isNumber }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text("cal")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "6B7280"))
                    }
                }
            }
            
            if entry.exercise == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Exercise")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    TextField("e.g., Stretching", text: Binding(
                        get: { fitnessEntries[index].customName },
                        set: { newValue in fitnessEntries[index].customName = newValue }
                    ))
                    .focused($fitnessNameFocusIndex, equals: index)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .contextMenu {
            Button("Duplicate") {
                let copy = entry
                fitnessEntries.insert(copy, at: min(index + 1, fitnessEntries.count))
                pendingScrollId = "fit-\(min(index + 1, fitnessEntries.count - 1))"
                triggerHapticLight()
            }
        }
        .padding(12)
        .background(Color(hexString: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Helper Methods
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
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

    private func aiSuggestionChip(_ title: String) -> some View {
        Button(action: { /* placeholder */ }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hexString: "101828"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hexString: "F3F4F6"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var formattedTime: String {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: timeDate)
    }

    private func formattedDuration(h: Int, m: Int) -> String {
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func recalcCaloriesFromDurationIfNeeded() {
        guard selectedCategory == .fitness else { return }
        guard let idx = editingFitnessEntryIndex, idx < fitnessEntries.count else { return }
        let h = durationHoursInt
        let m = durationMinutesInt
        let totalMinutes = max(0, h * 60 + m)
        // Always persist duration, even for custom exercises (no per30)
        fitnessEntries[idx].minutesInt = totalMinutes
        if let per30 = fitnessEntries[idx].exercise?.calPer30Min {
            let estimated = Int(round(Double(per30) * Double(totalMinutes) / 30.0))
            fitnessEntries[idx].caloriesText = String(estimated)
        }
    }

    private func aiSheetView(title: String, buttonText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            TextEditor(text: $aiPromptText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(hexString: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button(buttonText) {
                isAIGenerateSheetPresented = false
                isAskAISheetPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .presentationDetents([.fraction(0.45), .medium])
        .presentationDragIndicator(.visible)
    }
    
    private var quickPickSheet: some View {
        VStack(spacing: 12) {
            TextField("Search", text: $quickPickSearch)
                .textFieldStyle(.roundedBorder)
                .focused($searchFieldFocused)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if quickPickMode == .food {
                        // Custom option
                        Button(action: {
                            if let pickIndex = editingDietEntryIndex, pickIndex < dietEntries.count {
                                dietEntries[pickIndex].food = nil
                                // keep user's customName if any; ensure defaults
                                if dietEntries[pickIndex].unit.isEmpty { dietEntries[pickIndex].unit = "serving" }
                                if dietEntries[pickIndex].quantityText.isEmpty { dietEntries[pickIndex].quantityText = "1" }
                                editingDietEntryIndex = nil
                                dietNameFocusIndex = pickIndex
                                pendingScrollId = "diet-\(pickIndex)"
                            }
                            isQuickPickPresented = false
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(Color(hexString: "6B7280"))
                                Text("Customize Diet")
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hexString: "F9FAFB"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        let local = MenuData.foods.filter { quickPickSearch.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(quickPickSearch) }
                        if !recentFoods.isEmpty {
                            Text("Recent")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(recentFoods) { item in
                                Button(action: {
                                    if let pickIndex = editingDietEntryIndex {
                                        dietEntries[pickIndex].food = item
                                        dietEntries[pickIndex].customName = ""
                                        let u = item.defaultUnit ?? (item.hasPer100g ? "g" : "serving")
                                        dietEntries[pickIndex].unit = u
                                        if u == "g" { dietEntries[pickIndex].quantityText = "100" } else { dietEntries[pickIndex].quantityText = "1" }
                                        recalcEntryCalories(pickIndex)
                                        editingDietEntryIndex = nil
                                    }
                                    if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleText = item.name }
                                    isQuickPickPresented = false
                                }) {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text(quickPickCaloriesLabel(food: item))
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if !local.isEmpty {
                            Text("Local results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(local) { item in
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
                                        
                                        recalcEntryCalories(pickIndex)
                                        editingDietEntryIndex = nil
                                    }
                                    // recents: move to top if exists, otherwise add at top (use name as unique key since UUID regenerates)
                                    recentFoods.removeAll(where: { $0.name == item.name })
                                    recentFoods.insert(item, at: 0)
                                    if recentFoods.count > 5 { recentFoods.removeLast() }
                                    
                                    if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        titleText = item.name
                                    }
                                    isQuickPickPresented = false
                                }) {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text(quickPickCaloriesLabel(food: item))
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if isOnlineLoading {
                            Text("Searching onlineâ€¦")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                        
                        if !onlineFoods.isEmpty {
                            Text("Online results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(onlineFoods) { item in
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
                                        
                                        recalcEntryCalories(pickIndex)
                                        editingDietEntryIndex = nil
                                    }
                                    // recents: move to top if exists, otherwise add at top (use name as unique key since UUID regenerates)
                                    recentFoods.removeAll(where: { $0.name == item.name })
                                    recentFoods.insert(item, at: 0)
                                    if recentFoods.count > 5 { recentFoods.removeLast() }
                                    
                                    if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        titleText = item.name
                                    }
                                    isQuickPickPresented = false
                                }) {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text(quickPickCaloriesLabel(food: item))
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if quickPickMode == .exercise {
                        // Custom option
                        Button(action: {
                            if let idx = editingFitnessEntryIndex, idx < fitnessEntries.count {
                                fitnessEntries[idx].exercise = nil
                                if fitnessEntries[idx].minutesInt == 0 { /* keep 0, user can set */ }
                                editingFitnessEntryIndex = nil
                                fitnessNameFocusIndex = idx
                                pendingScrollId = "fit-\(idx)"
                            }
                            isQuickPickPresented = false
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(Color(hexString: "6B7280"))
                                Text("Customize Exercise")
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hexString: "F9FAFB"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        let filteredExercises = MenuData.exercises.filter { quickPickSearch.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(quickPickSearch) }
                        if !recentExercises.isEmpty {
                            Text("Recent")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(recentExercises) { item in
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
                                    if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { titleText = item.name }
                                    isQuickPickPresented = false
                                }) {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text("~\(item.calPer30Min) cal / 30m")
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if !filteredExercises.isEmpty {
                            Text("Local results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(filteredExercises) { item in
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
                                    isQuickPickPresented = false
                                }) {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text("~\(item.calPer30Min) cal / 30m")
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            if !quickPickSearch.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hexString: "D1D5DB"))
                                    Text("No exercises found")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hexString: "6B7280"))
                                    Text("Try a different search term")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hexString: "9CA3AF"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            }
                        }
                    }
                }
            }
            Button("Close") { isQuickPickPresented = false }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .presentationDetents([.fraction(0.6)])
        .presentationDragIndicator(.visible)
        .onChange(of: quickPickSearch) { _, newValue in
            guard quickPickMode == .food else { return }
            searchDebounceWork?.cancel()
            let work = DispatchWorkItem { [newValue] in
                let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard q.count >= 2 else { onlineFoods = []; return }
                isOnlineLoading = true
                OffClient.searchFoodsCached(query: q, limit: 50) { results in
                    isOnlineLoading = false
                    onlineFoods = results
                }
            }
            searchDebounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    private var canSave: Bool {
        let hasTitle = !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard let category = selectedCategory else { return false }
        switch category {
        case .diet:
            return hasTitle
        case .fitness:
            return hasTitle && !fitnessEntries.isEmpty
        case .others:
            return hasTitle
        }
    }

    private var emphasisHexForCategory: String {
        switch selectedCategory {
        case .diet: return "16A34A"
        case .fitness: return "364153"
        case .others: return "364153"
        case .none: return "364153"
        }
    }

    // Truncate subtitle to first sentence with "..." suffix if too long
    private func truncatedSubtitle(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        // Get first sentence (end at period, question mark, or exclamation)
        let firstSentence = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        
        // If still too long (>50 chars), truncate with "..."
        if firstSentence.count > 50 {
            let truncated = String(firstSentence.prefix(47))
            return truncated + "..."
        }
        
        return firstSentence
    }
    
    // Calculate end time for fitness tasks
    private func calculateEndTime(startTime: Date, durationMinutes: Int) -> String? {
        guard durationMinutes > 0 else { return nil }
        let endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime) ?? startTime
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: endDate)
    }

    private func categoryChip(_ category: Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            
            if category == .diet && dietEntries.isEmpty {
                dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
            } else if category == .fitness && fitnessEntries.isEmpty {
                fitnessEntries.append(FitnessEntry())
            }
        } label: {
            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "0A0A0A"))
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(hexString: "F3E8FF") : Color(hexString: "F9FAFB"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "C27AFF") : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
    }
    
    private func dietEntryCalories(_ entry: DietEntry) -> Int {
        guard let food = entry.food else { return 0 }
        guard let qtyDouble = Double(entry.quantityText), qtyDouble > 0 else { return 0 }
        
        if entry.unit == "g" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            return Int(round(per100 * qtyDouble / 100.0))
        } else if entry.unit == "lbs" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            let grams = qtyDouble * 453.592
            return Int(round(per100 * grams / 100.0))
        } else if entry.unit == "kg" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            let grams = qtyDouble * 1000.0
            return Int(round(per100 * grams / 100.0))
        } else {
            guard let per = food.servingCalories else { return 0 }
            return Int(round(Double(per) * qtyDouble))
        }
    }
    
    private func recalcEntryCalories(_ index: Int) {
        guard index < dietEntries.count else { return }
        guard dietEntries[index].food != nil else { return }
        let calculatedCalories = dietEntryCalories(dietEntries[index])
        dietEntries[index].caloriesText = String(calculatedCalories)
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
        return "â€“"
    }
    
    private var totalFitnessCalories: Int {
        fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private var totalFitnessDurationMinutes: Int {
        fitnessEntries.map { $0.minutesInt }.reduce(0, +)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func triggerHapticLight() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    
    private func triggerHapticMedium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color(hexString: "E5E7EB"))
            
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "364153"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button(action: {
                    // Calculate end time for fitness tasks
                    let endTimeValue: String?
                    if selectedCategory == .fitness && totalFitnessDurationMinutes > 0 {
                        endTimeValue = calculateEndTime(startTime: timeDate, durationMinutes: totalFitnessDurationMinutes)
                    } else {
                        endTimeValue = nil
                    }
                    
                    // Build calories meta text
                    let metaText: String = {
                        switch selectedCategory {
                        case .diet:
                            return "+\(totalDietCalories) cal"
                        case .fitness:
                            return "-\(totalFitnessCalories) cal"
                        default:
                            return ""
                        }
                    }()
                    
                    // Create the task with all necessary data
                    let task = MainPageView.TaskItem(
                        title: titleText.isEmpty ? "New Task" : titleText,
                        subtitle: truncatedSubtitle(descriptionText),
                        time: formattedTime,
                        timeDate: timeDate,
                        endTime: endTimeValue,
                        meta: metaText,
                        isDone: false,
                        emphasisHex: emphasisHexForCategory,
                        category: selectedCategory ?? .others,
                        dietEntries: dietEntries,
                        fitnessEntries: fitnessEntries
                    )
                    
                    tasks.append(task)
                    newlyAddedTaskId = task.id // Trigger animation for newly added task
                    triggerHapticMedium()
                    dismiss()
                }) {
                    Text("Save Task")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(canSave ? Color.black : Color(hexString: "D1D5DB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper([MainPageView.TaskItem]()) { tasks in
        NavigationStack {
            AddTaskView(tasks: tasks, newlyAddedTaskId: .constant(nil))
        }
    }
}
