import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let selectedDate: Date
    @Binding var newlyAddedTaskId: UUID?
    let onTaskCreated: (TaskItem) -> Void
    // Form state
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var timeDate: Date = Date()
    @State private var isTimeSheetPresented: Bool = false
    @State private var selectedCategory: TaskCategory? = nil
    @State private var isDurationSheetPresented: Bool = false
    @State private var durationHoursInt: Int = 0
    @State private var durationMinutesInt: Int = 0
    @State private var isQuickPickPresented: Bool = false
    @State private var quickPickMode: QuickPickSheetView.QuickPickMode? = nil
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
    @State private var pendingScrollId: String? = nil
    
    // Helper function to dismiss keyboard
    private func dismissKeyboard() {
        titleFocused = false
        descriptionFocused = false
        dietNameFocusIndex = nil
        fitnessNameFocusIndex = nil
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
    
    // ✅ Use new AI services for task generation
    private let aiService = AddTaskAIService()
    private let aiParser = AddTaskAIParser()

    @State private var dietEntries: [DietEntry] = []
    @State private var editingDietEntryIndex: Int? = nil
    
    @State private var fitnessEntries: [FitnessEntry] = []
    @State private var editingFitnessEntryIndex: Int? = nil
    
    var totalDietCalories: Int {
        let values: [Int] = dietEntries.map { entry in
            Int(entry.caloriesText) ?? 0
        }
        let sum: Int = values.reduce(0, +)
        return sum
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView
            mainContentView
            undoBannerView
        }
        .sheet(isPresented: $isQuickPickPresented) {
            quickPickSheet
        }
        .sheet(isPresented: $isAskAISheetPresented) {
            AskAIChatView(messages: $askAIMessages)
        }
        .sheet(isPresented: $isDurationSheetPresented, onDismiss: {
            dismissKeyboard()
        }) {
            durationSheet
        }
        .onChange(of: isQuickPickPresented) { _, isPresented in
            if !isPresented {
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
    
    private var backgroundView: some View {
        Color(hexString: "F9FAFB")
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Add New Task")
                .padding(.top, 12)
                .padding(.horizontal, 24)
            Spacer().frame(height: 12)
            // AI Toolbar
            AIToolbarView(
                isAIGenerating: isAIGenerating,
                onAskAITapped: { isAskAISheetPresented = true },
                onAIGenerateTapped: { generateTaskAutomatically() }
            )
            scrollableContent
                .background(Color(hexString: "F3F4F6"))
                .padding(.top, 8)
            bottomActionBar
        }
    }
    
    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    titleCard
                        .id("title")
                    dismissKeyboardSpacer
                    descriptionCard
                        .id("description")
                    dismissKeyboardSpacer
                    timeCard
                    dismissKeyboardSpacer
                    categoryCard
                    if selectedCategory == .diet {
                        dismissKeyboardSpacer
                        dietEntriesCard
                    }
                    if selectedCategory == .fitness {
                        dismissKeyboardSpacer
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("title", anchor: .center) }
                    }
                }
            }
            .onChange(of: descriptionFocused) { _, isFocused in
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("description", anchor: .center) }
                    }
                }
            }
            .onChange(of: dietNameFocusIndex) { _, index in
                if let index = index {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("diet-\(index)", anchor: .center) }
                    }
                }
            }
            .onChange(of: fitnessNameFocusIndex) { _, index in
                if let index = index {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("fit-\(index)", anchor: .center) }
                    }
                }
            }
        }
    }
    
    private var dismissKeyboardSpacer: some View {
        Color.clear
            .frame(height: 16)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
    }
    
    private var undoBannerView: some View {
        Group {
            if showUndoBanner {
                HStack(spacing: 12) {
                    Text(undoMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "101828"))
                    Spacer()
                    Button("Undo") {
                        handleUndoAction()
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
    }
    
    private func handleUndoAction() {
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
    
    private var quickPickSheet: some View {
        QuickPickSheetView(
            isPresented: $isQuickPickPresented,
            mode: quickPickMode,
            searchText: $quickPickSearch,
            dietEntries: $dietEntries,
            editingDietEntryIndex: $editingDietEntryIndex,
            fitnessEntries: $fitnessEntries,
            editingFitnessEntryIndex: $editingFitnessEntryIndex,
            titleText: $titleText,
            recentFoods: $recentFoods,
            recentExercises: $recentExercises,
            onlineFoods: $onlineFoods,
            isOnlineLoading: $isOnlineLoading,
            onRecalcDietCalories: { index in
                recalcEntryCalories(index)
            },
            onPendingScrollId: { id in
                pendingScrollId = id
            },
            onSetDietFocusIndex: { index in
                dietNameFocusIndex = index
            },
            onSetFitnessFocusIndex: { index in
                fitnessNameFocusIndex = index
            },
            onSearchFoods: { query, completion in
                searchDebounceWork?.cancel()
                let work = DispatchWorkItem {
                    OffClient.searchFoodsCached(query: query, limit: 50) { results in
                        completion(results)
                    }
                }
                searchDebounceWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        )
    }
    
    private var durationSheet: some View {
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
    
    private var titleCard: some View {
        TitleCardView(
            titleText: $titleText,
            titleFocused: $titleFocused,
            isTitleGenerating: isTitleGenerating,
            onGenerateTapped: { generateOrRefineTitle() }
        )
    }

    private var descriptionCard: some View {
        DescriptionCardView(
            descriptionText: $descriptionText,
            descriptionFocused: $descriptionFocused,
            isDescriptionGenerating: isDescriptionGenerating,
            onGenerateTapped: { generateDescription() }
        )
    }

    private var timeCard: some View {
        TimeCardView(
            timeDate: $timeDate,
            isTimeSheetPresented: $isTimeSheetPresented,
            onDismissKeyboard: { dismissKeyboard() }
        )
    }

    private var categoryCard: some View {
        CategoryCardView(
            selectedCategory: $selectedCategory,
            dietEntries: $dietEntries,
            fitnessEntries: $fitnessEntries
        )
    }

    private var dietEntriesCard: some View {
        DietEntriesCardView(
            dietEntries: $dietEntries,
            editingDietEntryIndex: $editingDietEntryIndex,
            titleText: $titleText,
            dietNameFocusIndex: $dietNameFocusIndex,
            pendingScrollId: $pendingScrollId,
            onAddFoodItem: {
                dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
                editingDietEntryIndex = dietEntries.count - 1
                quickPickMode = .food
                quickPickSearch = ""
                isQuickPickPresented = true
                triggerHapticLight()
            },
            onEditFoodItem: { index in
                editingDietEntryIndex = index
                quickPickMode = .food
                quickPickSearch = ""
                isQuickPickPresented = true
            },
            onDeleteFoodItem: { index in
                let removed = dietEntries.remove(at: index)
                lastDeletedDiet = DeletedDietContext(entry: removed, index: index)
                undoMessage = "Diet item deleted"
                withAnimation { showUndoBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showUndoBanner = false }
                    lastDeletedDiet = nil
                }
                triggerHapticMedium()
            },
            onClearAll: {
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
            },
            onRecalcCalories: { index in
                recalcEntryCalories(index)
            },
            onTriggerHaptic: {
                triggerHapticLight()
            }
        )
    }

    private var fitnessEntriesCard: some View {
        FitnessEntriesCardView(
            fitnessEntries: $fitnessEntries,
            editingFitnessEntryIndex: $editingFitnessEntryIndex,
            titleText: $titleText,
            fitnessNameFocusIndex: $fitnessNameFocusIndex,
            pendingScrollId: $pendingScrollId,
            durationHoursInt: $durationHoursInt,
            durationMinutesInt: $durationMinutesInt,
            isDurationSheetPresented: $isDurationSheetPresented,
            onAddExercise: {
                fitnessEntries.append(FitnessEntry())
                editingFitnessEntryIndex = fitnessEntries.count - 1
                quickPickMode = .exercise
                quickPickSearch = ""
                isQuickPickPresented = true
                triggerHapticLight()
            },
            onEditExercise: { index in
                editingFitnessEntryIndex = index
                quickPickMode = .exercise
                quickPickSearch = ""
                isQuickPickPresented = true
            },
            onDeleteExercise: { index in
                let removed = fitnessEntries.remove(at: index)
                lastDeletedFitness = DeletedFitnessContext(entry: removed, index: index)
                undoMessage = "Exercise deleted"
                withAnimation { showUndoBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showUndoBanner = false }
                    lastDeletedFitness = nil
                }
                triggerHapticMedium()
            },
            onClearAll: {
                lastClearedFitness = fitnessEntries
                fitnessEntries.removeAll()
                undoMessage = "Exercises cleared"
                withAnimation { showUndoBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showUndoBanner = false }
                    lastClearedFitness = nil
                }
                triggerHapticLight()
            },
            onTriggerHaptic: {
                triggerHapticLight()
            },
            onDismissKeyboard: {
                dismissKeyboard()
            },
            formattedDuration: { h, m in
                formattedDuration(h: h, m: m)
            }
        )
    }
    

    
    // MARK: - Helper Methods
    
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

    private func categoryChip(_ category: TaskCategory) -> some View {
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

    
    private var totalFitnessCalories: Int {
        let values: [Int] = fitnessEntries.map { entry in
            Int(entry.caloriesText) ?? 0
        }
        let sum: Int = values.reduce(0, +)
        return sum
    }
    
    private var totalFitnessDurationMinutes: Int {
        let minutes: [Int] = fitnessEntries.map { $0.minutesInt }
        let sum: Int = minutes.reduce(0, +)
        return sum
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
                
                Button(action: saveTask) {
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
    
    // MARK: - Task Saving
    
    private func saveTask() {
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
        
        let task = TaskItem(
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
    }
    
    // MARK: - AI Generation
    
    /// Automatically generate a task based on existing tasks for the day
    private func generateTaskAutomatically() {
        print("🎬 Automatic AI Generation started...")
        
        isAIGenerating = true
        aiGenerateError = nil
        
        aiService.generateTaskAutomatically(for: selectedDate, modelContext: modelContext) { result in
            switch result {
            case .success(let content):
                print("✅ Received response from OpenAI")
                print("🔄 Parsing and filling content...")
                parseAndFillTaskContent(content)
                isAIGenerating = false
                print("✅ Generation completed!")
            case .failure(let error):
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                isAIGenerating = false
                aiGenerateError = "Failed to generate: \(error.localizedDescription)"
            }
        }
    }
    
    
    /// Generate task content using AI based on user's profile and prompt (Legacy - for Ask AI feature)
    private func generateTaskWithAI() {
        print("🎬 AI Generation started...")
        print("📝 Prompt: \(aiPromptText)")
        
        isAIGenerating = true
        aiGenerateError = nil
        
        aiService.generateTaskFromPrompt(userPrompt: aiPromptText, modelContext: modelContext) { result in
            switch result {
            case .success(let content):
                print("✅ Received response from OpenAI")
                print("🔄 Parsing and filling content...")
                parseAndFillTaskContent(content)
                isAIGenerating = false
                isAIGenerateSheetPresented = false
                aiPromptText = "" // Clear prompt for next use
                print("✅ Generation completed!")
            case .failure(let error):
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                isAIGenerating = false
                aiGenerateError = error.localizedDescription
            }
        }
    }
    
    /// Parse AI response and fill form fields
    private func parseAndFillTaskContent(_ content: String) {
        print("🤖 Parsing AI generated content...")
        
        let parsed = aiParser.parseTaskContent(content)
        
        // Fill form fields
        if let title = parsed.title {
            titleText = title
        }
        
        if let description = parsed.description {
            descriptionText = description
        }
        
        if let category = parsed.category {
            selectedCategory = category
        }
        
        if let timeDate = parsed.timeDate {
            self.timeDate = timeDate
        }
        
        // Fill entries
        if selectedCategory == .fitness {
            fitnessEntries = parsed.exercises
            print("✅ Added \(parsed.exercises.count) fitness entries")
        } else if selectedCategory == .diet {
            dietEntries = parsed.foods
            print("✅ Added \(parsed.foods.count) diet entries")
        }
        
        print("✅ Task content filled successfully!")
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
        
        aiService.generateOrRefineTitle(currentTitle: titleText, modelContext: modelContext) { result in
            switch result {
            case .success(let finalTitle):
                isTitleGenerating = false
                Task {
                    await animateTextAppearance(finalText: finalTitle, target: $titleText)
                }
            case .failure(let error):
                print("❌ Title generation error: \(error)")
                isTitleGenerating = false
            }
        }
    }
    
    /// Generate description based on existing title, or generate both title and description if title is empty
    private func generateDescription() {
        guard !isDescriptionGenerating else { return }
        
        isDescriptionGenerating = true
        
        aiService.generateDescription(currentTitle: titleText, modelContext: modelContext) { result in
            switch result {
            case .success(let (title, description)):
                isDescriptionGenerating = false
                
                Task {
                    if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Animate both title and description
                        await animateTextAppearance(finalText: title, target: $titleText)
                        await animateTextAppearance(finalText: description, target: $descriptionText)
                    } else {
                        // Just animate description
                        await animateTextAppearance(finalText: description, target: $descriptionText)
                    }
                }
            case .failure(let error):
                print("❌ Description generation error: \(error)")
                isDescriptionGenerating = false
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
