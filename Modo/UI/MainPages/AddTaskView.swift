import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let selectedDate: Date
    @Binding var newlyAddedTaskId: UUID?
    let onTaskCreated: (MainPageView.TaskItem) -> Void
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
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    @FocusState private var searchFieldFocused: Bool
    @State private var pendingScrollId: String? = nil
    
    // Helper function to dismiss keyboard
    private func dismissKeyboard() {
        titleFocused = false
        descriptionFocused = false
        dietNameFocusIndex = nil
        fitnessNameFocusIndex = nil
        searchFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // AI UI placeholders
    @State private var isAIGenerateSheetPresented: Bool = false
    @State private var isAskAISheetPresented: Bool = false
    @State private var aiPromptText: String = ""
    @State private var askAIMessages: [AskAIChatView.SimpleMessage] = [] // Persist Ask AI chat history
    
    // AI Generation state
    @State private var isAIGenerating: Bool = false
    @State private var aiGenerateError: String? = nil
    @State private var isTitleGenerating: Bool = false
    @State private var isDescriptionGenerating: Bool = false
    private let firebaseAIService = FirebaseAIService.shared
    
    // ✅ Use AIPromptBuilder for unified prompt construction
    private let promptBuilder = AIPromptBuilder()

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
    
    @State private var dietEntries: [DietEntry] = []
    @State private var editingDietEntryIndex: Int? = nil
    
    struct FitnessEntry: Identifiable, Equatable, Codable {
        let id: UUID
        var exercise: MenuData.ExerciseItem?
        var customName: String
        var minutesInt: Int
        var caloriesText: String
        
        init(id: UUID = UUID(), exercise: MenuData.ExerciseItem? = nil, customName: String = "", minutesInt: Int = 0, caloriesText: String = "") {
            self.id = id
            self.exercise = exercise
            self.customName = customName
            self.minutesInt = minutesInt
            self.caloriesText = caloriesText
        }
        
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
    
    enum Category: String, CaseIterable, Identifiable, Codable {
        case diet = "🥗 Diet"
        case fitness = "🏃 Fitness"
        case others = "📌 Others"
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            VStack(spacing: 0) {
                PageHeader(title: "Add New Task")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                Spacer().frame(height: 12)
                // AI Toolbar
                HStack(spacing: 12) {
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
                    Spacer()
                    Button(action: {
                        generateTaskAutomatically()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .foregroundColor(.white)
                            Text(isAIGenerating ? "..." : "AI Generate")
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(isAIGenerating ? Color.gray : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isAIGenerating)
                }
                .padding(.horizontal, 24)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            titleCard
                                .id("title")
                            Color.clear
                                .frame(height: 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissKeyboard()
                                }
                            descriptionCard
                                .id("description")
                            Color.clear
                                .frame(height: 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissKeyboard()
                                }
                            timeCard
                            Color.clear
                                .frame(height: 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissKeyboard()
                                }
                            categoryCard
                            if selectedCategory == .diet {
                                Color.clear
                                    .frame(height: 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        dismissKeyboard()
                                    }
                                caloriesCard
                            }
                            if selectedCategory == .fitness {
                                Color.clear
                                    .frame(height: 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        dismissKeyboard()
                                    }
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
                    .onChange(of: titleFocused) { _, isFocused in
                        if isFocused {
                            // Wait for keyboard to appear, then scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("title", anchor: .center) }
                            }
                        }
                    }
                    .onChange(of: descriptionFocused) { _, isFocused in
                        if isFocused {
                            // Wait for keyboard to appear, then scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("description", anchor: .center) }
                            }
                        }
                    }
                    .onChange(of: dietNameFocusIndex) { _, index in
                        if let index = index {
                            // Wait for keyboard to appear, then scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("diet-\(index)", anchor: .center) }
                            }
                        }
                    }
                    .onChange(of: fitnessNameFocusIndex) { _, index in
                        if let index = index {
                            // Wait for keyboard to appear, then scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("fit-\(index)", anchor: .center) }
                            }
                        }
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
        .sheet(isPresented: $isAskAISheetPresented) {
            AskAIChatView(messages: $askAIMessages)
        }
        .sheet(isPresented: $isDurationSheetPresented, onDismiss: {
            // Ensure focus stays cleared after sheet dismisses
            dismissKeyboard()
        }) {
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
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Only handle horizontal swipes (ignore vertical)
                    // Swipe from left to right: dismiss view (return to main page)
                    if abs(horizontalAmount) > abs(verticalAmount) && horizontalAmount > 0 {
                        // Swipe from left to right: dismiss
                        dismiss()
                    }
                }
        )
        
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
                        generateOrRefineTitle()
                    }) {
                        Group {
                            if isTitleGenerating {
                                SwiftUI.ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .padding(6)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                        }
                        .background(Color(hexString: "9810FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTitleGenerating)
                }
                HStack(spacing: 8) {
                    TextField("e.g., Morning Run", text: $titleText)
                        .textInputAutocapitalization(.words)
                        .focused($titleFocused)
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
                        generateDescription()
                    }) {
                        Group {
                            if isDescriptionGenerating {
                                SwiftUI.ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .padding(6)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                        }
                        .background(Color(hexString: "9810FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDescriptionGenerating)
                }
                ZStack(alignment: .topTrailing) {
                    TextField("e.g., 5km jog in the park", text: $descriptionText, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .focused($descriptionFocused)
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
                Button(action: {
                    // Clear focus immediately when opening time sheet
                    dismissKeyboard()
                    isTimeSheetPresented = true
                }) {
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
                .sheet(isPresented: $isTimeSheetPresented, onDismiss: {
                    // Ensure focus stays cleared after sheet dismisses
                    dismissKeyboard()
                }) {
                    VStack(spacing: 12) {
                        DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        Button("Done") {
                            isTimeSheetPresented = false
                        }
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
                        aiSuggestionChip("Low-fat lunch 600 cal")
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
                        // Clear focus immediately when opening duration sheet
                        dismissKeyboard()
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
        let isGenerateMode = buttonText.contains("Generate")
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            TextEditor(text: $aiPromptText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(hexString: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Error message
            if let error = aiGenerateError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
            
            // Generate button
            Button(action: {
                print("🔘 Button tapped - buttonText: \(buttonText), isGenerateMode: \(isGenerateMode)")
                if isGenerateMode {
                    print("🚀 Calling generateTaskWithAI()")
                    generateTaskWithAI()
                } else {
                    print("ℹ️ Ask AI (coming soon)")
                    // "Ask AI" functionality (coming soon)
                    isAskAISheetPresented = false
                }
            }) {
                Text(isAIGenerating ? "Generating..." : buttonText)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.system(size: 16, weight: .semibold))
            .background(isAIGenerating ? Color.gray : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(isAIGenerating)
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
                            Text("Searching online")
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
            guard quickPickMode == .food else {
                return
            }
            searchDebounceWork?.cancel()
            let work = DispatchWorkItem { [newValue] in
                let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard q.count >= 2 else {
                    onlineFoods = []
                    return
                }
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
                    // Merge time from timeDate (hour:minute) with selectedDate's date
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                    let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0,
                                                 of: selectedDate) ?? selectedDate
                    
                    // Calculate end time for fitness tasks
                    let endTimeValue: String?
                    if selectedCategory == .fitness && totalFitnessDurationMinutes > 0 {
                        endTimeValue = calculateEndTime(startTime: finalDate, durationMinutes: totalFitnessDurationMinutes)
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
                    // Only save entries from the selected category
                    let finalDietEntries: [DietEntry]
                    let finalFitnessEntries: [FitnessEntry]
                    
                    switch selectedCategory {
                    case .diet:
                        finalDietEntries = dietEntries
                        finalFitnessEntries = []
                    case .fitness:
                        finalDietEntries = []
                        finalFitnessEntries = fitnessEntries
                    case .others, .none:
                        finalDietEntries = []
                        finalFitnessEntries = []
                    }
                    
                    let task = MainPageView.TaskItem(
                        title: titleText.isEmpty ? "New Task" : titleText,
                        subtitle: truncatedSubtitle(descriptionText),
                        time: formattedTime,
                        timeDate: finalDate,  // Use merged date+time
                        endTime: endTimeValue,
                        meta: metaText,
                        isDone: false,
                        emphasisHex: emphasisHexForCategory,
                        category: selectedCategory ?? .others,
                        dietEntries: finalDietEntries,
                        fitnessEntries: finalFitnessEntries
                    )
                    
                    onTaskCreated(task)
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
    
    // MARK: - AI Generation
    
    /// Automatically generate a task based on existing tasks for the day
    private func generateTaskAutomatically() {
        print("🎬 Automatic AI Generation started...")
        
        isAIGenerating = true
        aiGenerateError = nil
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Analyze existing tasks for the selected date
        let existingTasks = getExistingTasksForDate(selectedDate)
        let taskAnalysis = analyzeExistingTasks(existingTasks)
        
        print("📊 Task analysis: \(taskAnalysis)")
        
        // ✅ Build AI prompt using AIPromptBuilder
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userMessage = buildSmartPrompt(based: taskAnalysis, userProfile: userProfile)
        
        print("📝 Auto-generated prompt: \(userMessage.prefix(200))...")
        
        // Call OpenAI
        Task {
            do {
                print("📡 Sending request to OpenAI...")
                let FirebaseChatMessages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userMessage)
                ]

                let response = try await firebaseAIService.sendChatRequest(
                    messages: FirebaseChatMessages
                )
                
                print("✅ Received response from OpenAI")
                
                // Extract content from response
                let content = response.choices.first?.message.content ?? ""
                print("📄 Response content: \(content.prefix(200))...")
                
                await MainActor.run {
                    self.isAIGenerating = false
                    print("🔄 Parsing and filling content...")
                    self.parseAndFillTaskContent(content)
                    print("✅ Generation completed!")
                }
            } catch {
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isAIGenerating = false
                    self.aiGenerateError = "Failed to generate: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Get existing tasks for the selected date from cache
    private func getExistingTasksForDate(_ date: Date) -> [TaskInfo] {
        // Get tasks from cache service
        let cacheService = TaskCacheService.shared
        let tasks = cacheService.getTasks(for: date)
        
        print("📊 Found \(tasks.count) existing tasks for \(date)")
        
        // Convert TaskItem to TaskInfo
        return tasks.map { task in
            let categoryString: String
            switch task.category {
            case .fitness:
                categoryString = "fitness"
            case .diet:
                categoryString = "diet"
            case .others:
                categoryString = "others"
            }
            
            return TaskInfo(
                category: categoryString,
                time: task.time,
                title: task.title
            )
        }
    }
    
    struct TaskInfo {
        let category: String // "fitness", "diet", "others"
        let time: String
        let title: String
    }
    
    struct TaskAnalysis {
        let hasFitness: Bool
        let hasBreakfast: Bool
        let hasLunch: Bool
        let hasDinner: Bool
        let totalTasks: Int
        let suggestion: String // What to generate
    }
    
    /// Analyze existing tasks to determine what's missing
    private func analyzeExistingTasks(_ tasks: [TaskInfo]) -> TaskAnalysis {
        print("🔍 Analyzing \(tasks.count) existing tasks:")
        for (index, task) in tasks.enumerated() {
            print("   \(index + 1). [\(task.category)] \(task.title) at \(task.time)")
        }
        
        let hasFitness = tasks.contains { $0.category == "fitness" }
        
        // Check for meals by time or keywords
        let hasBreakfast = tasks.contains { task in
            task.category == "diet" && (
                task.time.contains("AM") && !task.time.contains("12:") ||
                task.title.lowercased().contains("breakfast")
            )
        }
        
        let hasLunch = tasks.contains { task in
            task.category == "diet" && (
                (task.time.contains("12:") || task.time.contains("01:") || task.time.contains("02:")) ||
                task.title.lowercased().contains("lunch")
            )
        }
        
        let hasDinner = tasks.contains { task in
            task.category == "diet" && (
                task.time.contains("PM") && !task.time.contains("12:") && !task.time.contains("01:") && !task.time.contains("02:") ||
                task.title.lowercased().contains("dinner")
            )
        }
        
        print("📋 Task coverage:")
        print("   - Fitness: \(hasFitness ? "✅" : "❌")")
        print("   - Breakfast: \(hasBreakfast ? "✅" : "❌")")
        print("   - Lunch: \(hasLunch ? "✅" : "❌")")
        print("   - Dinner: \(hasDinner ? "✅" : "❌")")
        
        // Determine what to suggest
        var suggestion = ""
        if !hasFitness {
            suggestion = "fitness"
        } else if !hasBreakfast {
            suggestion = "breakfast"
        } else if !hasLunch {
            suggestion = "lunch"
        } else if !hasDinner {
            suggestion = "dinner"
        } else {
            // All basic tasks covered, generate a random healthy snack or workout
            suggestion = Bool.random() ? "fitness" : "snack"
        }
        
        print("💡 Suggestion: Generate \(suggestion)")
        
        return TaskAnalysis(
            hasFitness: hasFitness,
            hasBreakfast: hasBreakfast,
            hasLunch: hasLunch,
            hasDinner: hasDinner,
            totalTasks: tasks.count,
            suggestion: suggestion
        )
    }
    
    /// Build smart prompt based on task analysis
    private func buildSmartPrompt(based analysis: TaskAnalysis, userProfile: UserProfile?) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        
        var prompt = "It's \(timeOfDay). "
        
        switch analysis.suggestion {
        case "fitness":
            prompt += """
            Create a workout task with a SHORT, CONCISE title (2-4 words max, like 'Upper Body Strength' or 'Full Body HIIT').
            Consider the user's current fitness level and goals. Suggest an appropriate workout for \(timeOfDay).
            """
            
        case "breakfast":
            prompt += """
            Create a healthy breakfast task for ONE PERSON. The user hasn't logged breakfast yet.
            Provide nutritious breakfast options with specific portion sizes (e.g., '2 eggs', '1 cup oatmeal', '6oz yogurt').
            Use single servings appropriate for one person.
            """
            
        case "lunch":
            prompt += """
            Create a healthy lunch task for ONE PERSON. The user hasn't logged lunch yet.
            Provide balanced lunch options with specific portion sizes (e.g., '6oz chicken', '1 cup rice', '1 cup vegetables').
            Use single servings appropriate for one person.
            """
            
        case "dinner":
            prompt += """
            Create a healthy dinner task for ONE PERSON. The user hasn't logged dinner yet.
            Provide nutritious dinner options with specific portion sizes (e.g., '8oz salmon', '1.5 cups quinoa', '2 cups salad').
            Use single servings appropriate for one person.
            """
            
        case "snack":
            prompt += """
            Create a healthy snack task for ONE PERSON. Suggest a nutritious snack between meals.
            Keep it light and balanced with specific portions (e.g., '1 apple', '1oz almonds', '1 protein bar').
            Use single servings appropriate for one person.
            """
            
        default:
            prompt += "Create a helpful fitness or nutrition task for today."
        }
        
        prompt += """
        
        
        Please provide:
        1. A clear, concise task title (max 50 characters)
        2. A detailed description
        3. Task category (fitness or diet)
        4. If fitness: List specific exercises with sets, reps, rest periods, duration (minutes), and calories
        5. If diet: List specific foods/meals with portion sizes and calories
        6. Suggested time of day (format: "HH:MM AM/PM")
        
        Format your response as:
        TITLE: [title here]
        DESCRIPTION: [description here]
        CATEGORY: [fitness or diet]
        TIME: [time here]
        
        For fitness tasks:
        EXERCISES:
        - [Exercise name]: [sets] sets x [reps] reps, [rest]s rest, [duration]min, [calories]cal
        
        For diet tasks:
        FOODS:
        - [Food name]: [quantity] [unit], [calories]cal
        
        Examples of valid units: serving, oz, g, kg, lbs, cups, tbsp, etc.
        Example: "Chicken Breast: 6 oz, 280cal"
        Example: "Oatmeal: 1 serving, 150cal"
        Example: "Banana: 100 g, 89cal"
        """
        
        return prompt
    }
    
    /// Generate task content using AI based on user's profile and prompt (Legacy - for Ask AI feature)
    private func generateTaskWithAI() {
        print("🎬 AI Generation started...")
        print("📝 Prompt: \(aiPromptText)")
        
        guard !aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiGenerateError = "Please describe what task you'd like to create"
            print("❌ Empty prompt")
            return
        }
        
        isAIGenerating = true
        aiGenerateError = nil
        print("⏳ Calling OpenAI API...")
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // ✅ Build system prompt using AIPromptBuilder
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // User's request
        let userMessage = """
        Create a task based on this description: "\(aiPromptText)"
        
        Please provide:
        1. A clear, concise task title (max 50 characters)
        2. A detailed description
        3. Task category (fitness or diet)
        4. If fitness: List specific exercises with sets, reps, rest periods, duration (minutes), and calories
        5. If diet: List specific foods/meals with portion sizes and calories
        6. Suggested time of day (format: "HH:MM AM/PM")
        
        Format your response as:
        TITLE: [title here]
        DESCRIPTION: [description here]
        CATEGORY: [fitness or diet]
        TIME: [time here]
        
        For fitness tasks:
        EXERCISES:
        - [Exercise name]: [sets] sets x [reps] reps, [rest]s rest, [duration]min, [calories]cal
        
        For diet tasks:
        FOODS:
        - [Food name]: [quantity] [unit], [calories]cal
        
        Examples of valid units: serving, oz, g, kg, lbs, cups, tbsp, etc.
        Example: "Chicken Breast: 6 oz, 280cal"
        Example: "Oatmeal: 1 serving, 150cal"
        Example: "Banana: 100 g, 89cal"
        """
        
        // Call OpenAI
        Task {
            do {
                print("📡 Sending request to OpenAI...")
                let FirebaseChatMessages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userMessage)
                ]

                let response = try await firebaseAIService.sendChatRequest(
                    messages: FirebaseChatMessages
                )
                print("✅ Received response from OpenAI")
                
                // Extract content from response
                let content = response.choices.first?.message.content ?? ""
                print("📄 Response content: \(content.prefix(200))...")
                
                await MainActor.run {
                    self.isAIGenerating = false
                    print("🔄 Parsing and filling content...")
                    self.parseAndFillTaskContent(content)
                    self.isAIGenerateSheetPresented = false
                    self.aiPromptText = "" // Clear prompt for next use
                    print("✅ Generation completed!")
                }
            } catch {
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isAIGenerating = false
                    self.aiGenerateError = "Failed to generate: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // ✅ buildAISystemPrompt() removed - now using AIPromptBuilder.buildSystemPrompt()
    
    /// Parse AI response and fill form fields
    private func parseAndFillTaskContent(_ content: String) {
        print("🤖 Parsing AI generated content...")
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        var exercises: [FitnessEntry] = []
        var foods: [DietEntry] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Parse title
            if trimmed.hasPrefix("TITLE:") {
                let title = trimmed.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespaces)
                // No prefix for AI generated titles, use as is
                titleText = String(title.prefix(50))
            }
            
            // Parse description
            else if trimmed.hasPrefix("DESCRIPTION:") {
                descriptionText = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespaces)
            }
            
            // Parse category
            else if trimmed.hasPrefix("CATEGORY:") {
                let category = trimmed.replacingOccurrences(of: "CATEGORY:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                if category.contains("fitness") || category.contains("workout") {
                    selectedCategory = .fitness
                } else if category.contains("diet") || category.contains("nutrition") || category.contains("meal") {
                    selectedCategory = .diet
                }
            }
            
            // Parse time
            else if trimmed.hasPrefix("TIME:") {
                let timeString = trimmed.replacingOccurrences(of: "TIME:", with: "").trimmingCharacters(in: .whitespaces)
                if let parsedTime = parseTimeString(timeString) {
                    timeDate = parsedTime
                }
            }
            
            // Track sections
            else if trimmed == "EXERCISES:" {
                currentSection = "exercises"
            }
            else if trimmed == "FOODS:" {
                currentSection = "foods"
            }
            
            // Parse exercise line
            else if currentSection == "exercises" && trimmed.hasPrefix("-") {
                if let exercise = parseExerciseLine(trimmed) {
                    exercises.append(exercise)
                }
            }
            
            // Parse food line
            else if currentSection == "foods" && trimmed.hasPrefix("-") {
                if let food = parseFoodLine(trimmed) {
                    foods.append(food)
                }
            }
        }
        
        // Fill entries
        if selectedCategory == .fitness {
            fitnessEntries = exercises
            print("✅ Added \(exercises.count) fitness entries")
        } else if selectedCategory == .diet {
            dietEntries = foods
            print("✅ Added \(foods.count) diet entries")
        }
        
        print("✅ Task content filled successfully!")
    }
    
    /// Parse time string like "09:00 AM" to Date
    private func parseTimeString(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.date(from: timeString)
    }
    
    /// Parse exercise line like "- Push-ups: 3 sets x 15 reps, 60s rest, 5min, 40cal"
    private func parseExerciseLine(_ line: String) -> FitnessEntry? {
        // Remove leading dash and whitespace
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("-") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        // Split by colon to get name and details
        let parts = text.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let details = parts[1].trimmingCharacters(in: .whitespaces)
        
        // Extract duration (e.g., "5min")
        var duration = 5 // default
        if let durationRegex = try? NSRegularExpression(pattern: #"(\d+)\s*min"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = durationRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let durationRange = Range(match.range(at: 1), in: details) {
                    duration = Int(details[durationRange]) ?? 5
                }
            }
        }
        
        // Extract calories (e.g., "40cal")
        var calories = duration * 7 // default fallback
        if let caloriesRegex = try? NSRegularExpression(pattern: #"(\d+)\s*cal"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = caloriesRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: details) {
                    calories = Int(details[caloriesRange]) ?? calories
                }
            }
        }
        
        return FitnessEntry(
            exercise: nil,
            customName: name,
            minutesInt: duration,
            caloriesText: String(calories)
        )
    }
    
    /// Parse food line like "- Grilled Chicken: 6oz, 280cal" or "- Oatmeal: 1 serving, 150cal"
    private func parseFoodLine(_ line: String) -> DietEntry? {
        print("🍽️ Parsing food line: \(line)")
        
        // Remove leading dash and whitespace
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("-") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        // Split by colon to get name and details
        let parts = text.components(separatedBy: ":")
        guard parts.count >= 2 else {
            print("❌ Failed to parse: no colon found")
            return nil
        }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let details = parts[1].trimmingCharacters(in: .whitespaces)
        
        print("   Name: \(name)")
        print("   Details: \(details)")
        
        // Extract portion and unit (e.g., "6oz" -> quantity: "6", unit: "oz")
        var quantity = "1"
        var unit = "serving"
        
        let portionComponents = details.components(separatedBy: ",")
        if !portionComponents.isEmpty {
            let portionText = portionComponents[0].trimmingCharacters(in: .whitespaces)
            print("   Portion text: '\(portionText)'")
            
            // Try multiple regex patterns to match different formats
            var matched = false
            
            // Pattern 1: Number + unit with optional space (e.g., "6oz", "6 oz", "150g", "150 g")
            if let regex = try? NSRegularExpression(pattern: #"^(\d+\.?\d*)\s*([a-zA-Z]+)$"#, options: []) {
                let nsPortionText = portionText as NSString
                if let match = regex.firstMatch(in: portionText, range: NSRange(location: 0, length: nsPortionText.length)) {
                    if let qtyRange = Range(match.range(at: 1), in: portionText) {
                        quantity = String(portionText[qtyRange])
                    }
                    if let unitRange = Range(match.range(at: 2), in: portionText) {
                        unit = String(portionText[unitRange])
                    }
                    matched = true
                    print("   ✅ Matched pattern 1: qty=\(quantity), unit=\(unit)")
                }
            }
            
            // Pattern 2: Number + space + word unit (e.g., "1 serving", "2 cups")
            if !matched, let regex = try? NSRegularExpression(pattern: #"^(\d+\.?\d*)\s+([a-zA-Z\s]+)$"#, options: []) {
                let nsPortionText = portionText as NSString
                if let match = regex.firstMatch(in: portionText, range: NSRange(location: 0, length: nsPortionText.length)) {
                    if let qtyRange = Range(match.range(at: 1), in: portionText) {
                        quantity = String(portionText[qtyRange])
                    }
                    if let unitRange = Range(match.range(at: 2), in: portionText) {
                        unit = String(portionText[unitRange]).trimmingCharacters(in: .whitespaces)
                    }
                    matched = true
                    print("   ✅ Matched pattern 2: qty=\(quantity), unit=\(unit)")
                }
            }
            
            // Pattern 3: Just a unit word (e.g., "serving")
            if !matched && portionText.range(of: #"^[a-zA-Z\s]+$"#, options: .regularExpression) != nil {
                unit = portionText
                quantity = "1"
                matched = true
                print("   ✅ Matched pattern 3 (unit only): qty=\(quantity), unit=\(unit)")
            }
            
            if !matched {
                print("   ⚠️ No pattern matched, using defaults")
            }
        }
        
        // Extract calories (e.g., "280cal")
        var calories = 100 // default fallback
        if let caloriesRegex = try? NSRegularExpression(pattern: #"(\d+)\s*cal"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = caloriesRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: details) {
                    calories = Int(details[caloriesRange]) ?? calories
                }
            }
        }
        
        print("   📊 Final parsed: qty=\(quantity), unit=\(unit), cal=\(calories)")
        
        return DietEntry(
            food: nil,
            customName: name,
            quantityText: quantity,
            unit: unit,
            caloriesText: String(calories)
        )
    }
    
    // MARK: - Title & Description AI Generation
    
    /// Animate text appearing character by character (typing effect)
    private func animateTextAppearance(
        finalText: String,
        target: Binding<String>,
        delayPerChar: TimeInterval = 0.03
    ) async {
        let characters = Array(finalText)
        var currentText = ""
        
        for char in characters {
            currentText.append(char)
            await MainActor.run {
                target.wrappedValue = currentText
            }
            try? await Task.sleep(nanoseconds: UInt64(delayPerChar * 1_000_000_000))
        }
    }
    
    /// Generate or refine task title based on user profile
    private func generateOrRefineTitle() {
        guard !isTitleGenerating else { return }
        
        isTitleGenerating = true
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Build system prompt
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // Build user message based on whether title is empty or not
        let userMessage: String
        if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Generate new title based on user profile
            userMessage = """
            Generate a concise, clear task title (2-4 words max) for a fitness or nutrition task based on the user's profile.
            The title should be relevant to their goals and lifestyle.
            Examples: "Morning Run", "Upper Body Strength", "Healthy Breakfast", "Evening Yoga"
            
            Respond with ONLY the title, no additional text or explanation.
            """
        } else {
            // Refine existing title (improve grammar, clarity)
            userMessage = """
            Improve and refine this task title for clarity and grammar: "\(titleText)"
            
            Keep it concise (2-4 words max), maintain the same meaning, but make it clearer and more professional.
            Respond with ONLY the improved title, no additional text or explanation.
            """
        }
        
        Task {
            do {
                let messages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userMessage)
                ]
                
                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        // Clean up the response - remove quotes, extra whitespace, etc.
                        let cleanedTitle = content
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\"", with: "")
                            .replacingOccurrences(of: "'", with: "")
                        
                        // Limit to 40 characters (same as TextField limit)
                        let finalTitle = String(cleanedTitle.prefix(40))
                        
                        // Animate text appearance
                        isTitleGenerating = false
                        Task {
                            await animateTextAppearance(finalText: finalTitle, target: $titleText)
                        }
                    } else {
                        isTitleGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Title generation error: \(error)")
                    isTitleGenerating = false
                }
            }
        }
    }
    
    /// Generate description based on existing title, or generate both title and description if title is empty
    private func generateDescription() {
        guard !isDescriptionGenerating else { return }
        
        isDescriptionGenerating = true
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Build system prompt
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // Build user message based on whether title exists
        let userMessage: String
        if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Generate a task suggestion (both title and description) that the user should do
            userMessage = """
            Suggest a fitness or nutrition task that would be beneficial for the user based on their profile, goals, and lifestyle.
            This should be something they would want to do or should do.
            
            Provide:
            1. A concise task title (2-4 words max) - something they should do
            2. A brief, helpful description (1-2 sentences) explaining what the task involves
            
            Format your response EXACTLY as:
            TITLE: [title here]
            DESCRIPTION: [description here]
            
            Make it relevant, actionable, and aligned with their fitness goals.
            Examples:
            - TITLE: Morning Run
              DESCRIPTION: 5km jog in the park to start the day with energy and boost metabolism
            - TITLE: Healthy Breakfast
              DESCRIPTION: Balanced meal with protein, carbs, and healthy fats to fuel your day
            - TITLE: Upper Body Strength
              DESCRIPTION: 30-minute workout focusing on chest, back, and arms to build muscle
            """
        } else {
            // Generate description based on existing title
            userMessage = """
            Generate a brief, helpful description (1-2 sentences) that fits well with this task title: "\(titleText)"
            
            The description should explain what the task involves, provide context, and make it clear what the user needs to do.
            Keep it concise, actionable, and relevant to the title.
            
            Respond with ONLY the description text, no additional labels or formatting.
            """
        }
        
        Task {
            do {
                let messages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userMessage)
                ]
                
                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        isDescriptionGenerating = false
                        
                        if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Parse both title and description
                            var finalTitle = ""
                            var finalDescription = ""
                            
                            let lines = content.components(separatedBy: .newlines)
                            for line in lines {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                if trimmed.hasPrefix("TITLE:") {
                                    let title = trimmed.replacingOccurrences(of: "TITLE:", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                        .replacingOccurrences(of: "\"", with: "")
                                        .replacingOccurrences(of: "'", with: "")
                                    finalTitle = String(title.prefix(40))
                                } else if trimmed.hasPrefix("DESCRIPTION:") {
                                    finalDescription = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                }
                            }
                            
                            // Animate both title and description
                            Task {
                                // Animate title first
                                await animateTextAppearance(finalText: finalTitle, target: $titleText)
                                // Then animate description
                                await animateTextAppearance(finalText: finalDescription, target: $descriptionText)
                            }
                        } else {
                            // Just set description
                            let cleanedDesc = content
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: "DESCRIPTION:", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            
                            // Animate description appearance
                            Task {
                                await animateTextAppearance(finalText: cleanedDesc, target: $descriptionText)
                            }
                        }
                    } else {
                        isDescriptionGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Description generation error: \(error)")
                    isDescriptionGenerating = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AddTaskView(
            selectedDate: Calendar.current.startOfDay(for: Date()),
            newlyAddedTaskId: .constant(nil),
            onTaskCreated: { _ in }
        )
    }
}
