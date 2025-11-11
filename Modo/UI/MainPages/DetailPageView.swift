import SwiftUI

struct DetailPageView: View {
    @Environment(\.dismiss) private var dismiss
    let taskId: UUID
    let getTask: (UUID) -> TaskItem?
    let onUpdateTask: (TaskItem, TaskItem) -> Void
    
    private var task: TaskItem? {
        getTask(taskId)
    }
    
    // Edit state - we need to work with mutable copies
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var timeDate: Date = Date()
    @State private var isTimeSheetPresented: Bool = false
    @State private var isEditing: Bool = false
    @State private var selectedCategory: TaskCategory? = nil
    @State private var dietEntries: [DietEntry] = []
    @State private var fitnessEntries: [FitnessEntry] = []
    
    // Quick pick states (similar to AddTaskView)
    @State private var isQuickPickPresented: Bool = false
    @State private var quickPickMode: QuickPickSheetView.QuickPickMode? = nil
    @State private var quickPickSearch: String = ""
    @State private var editingDietEntryIndex: Int? = nil
    @State private var editingFitnessEntryIndex: Int? = nil
    @State private var durationHoursInt: Int = 0
    @State private var durationMinutesInt: Int = 0
    @State private var isDurationSheetPresented: Bool = false
    
    // QuickPickSheetView states
    @State private var recentFoods: [MenuData.FoodItem] = []
    @State private var recentExercises: [MenuData.ExerciseItem] = []
    @State private var onlineFoods: [MenuData.FoodItem] = []
    @State private var isOnlineLoading: Bool = false
    
    // Focus states
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    @State private var pendingScrollId: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
            // Check if task exists
            if let task = task {
                VStack(spacing: 0) {
                    // Header
                    PageHeader(title: isEditing ? "Edit Task" : "Task Details")
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                if isEditing {
                                    editingContentView
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)
                                        ))
                                } else {
                                    displayContentView
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        ))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                    }
                    
                    if isEditing {
                        bottomActionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
            } else {
                // Error state
                VStack(spacing: 16) {
                    Spacer()
                    Text("Task not found")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Button("Go Back") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $isDurationSheetPresented) {
            DurationPickerSheetView(
                isPresented: $isDurationSheetPresented,
                durationHours: $durationHoursInt,
                durationMinutes: $durationMinutesInt,
                onDurationChanged: {
                    recalcCaloriesFromDurationIfNeeded()
                }
            )
        }
        .sheet(isPresented: $isQuickPickPresented) {
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
                    // For DetailPageView, we don't need online search
                    // Just return empty array
                    completion([])
                }
            )
        }
        .onAppear {
            if self.task != nil {
                loadTaskData()
            }
        }
        .onChange(of: taskId) { _, _ in
            // Reload data if task id changes
            if self.task != nil {
                loadTaskData()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Display Content (Read-only)
    private var displayContentView: some View {
        Group {
            if let task = task {
                VStack(spacing: 16) {
                    TaskDetailDisplayView(task: task)
                    
                    // Edit button
                    Button(action: {
                        loadTaskData() // Reload data when entering edit mode
                        isEditing = true
                    }) {
                        Text("Edit Task")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Editing Content
    private var editingContentView: some View {
        Group {
            if let task = task {
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
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Edit Cards
    private var titleCard: some View {
        TitleCardView(
            titleText: $titleText,
            titleFocused: $titleFocused,
            isTitleGenerating: false,
            onGenerateTapped: {}
        )
    }
    
    private var descriptionCard: some View {
        DescriptionCardView(
            descriptionText: $descriptionText,
            descriptionFocused: $descriptionFocused,
            isDescriptionGenerating: false,
            onGenerateTapped: {}
        )
    }
    
    private var timeCard: some View {
        TimeCardView(
            timeDate: $timeDate,
            isTimeSheetPresented: $isTimeSheetPresented,
            onDismissKeyboard: {
                titleFocused = false
                descriptionFocused = false
                dietNameFocusIndex = nil
                fitnessNameFocusIndex = nil
            }
        )
    }
    
    private var categoryCard: some View {
        CategoryCardView(
            selectedCategory: $selectedCategory,
            dietEntries: $dietEntries,
            fitnessEntries: $fitnessEntries
        )
    }
    
    private var caloriesCard: some View {
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
                dietEntries.remove(at: index)
                triggerHapticMedium()
            },
            onClearAll: {
                dietEntries.removeAll()
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
                    fitnessEntries.remove(at: index)
                    triggerHapticMedium()
            },
            onClearAll: {
                fitnessEntries.removeAll()
                triggerHapticLight()
            },
            onTriggerHaptic: {
                triggerHapticLight()
            },
            onDismissKeyboard: {
                titleFocused = false
                descriptionFocused = false
                dietNameFocusIndex = nil
                fitnessNameFocusIndex = nil
            },
            formattedDuration: { h, m in
                TaskEditHelper.formattedDuration(hours: h, minutes: m)
            }
        )
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color(hexString: "E5E7EB"))
            
            HStack(spacing: 12) {
                Button(action: {
                    isEditing = false
                    loadTaskData() // Reload original data
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "364153"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button(action: {
                    saveChanges()
                    isEditing = false
                    triggerHapticMedium()
                }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
    
    // MARK: - Helper Methods
    
    private func recalcEntryCalories(_ index: Int) {
        guard index < dietEntries.count else { return }
        guard dietEntries[index].food != nil else { return }
        let calculatedCalories = TaskEditHelper.dietEntryCalories(dietEntries[index])
        dietEntries[index].caloriesText = String(calculatedCalories)
    }
    
    private func recalcCaloriesFromDurationIfNeeded() {
        guard selectedCategory == .fitness else { return }
        guard let idx = editingFitnessEntryIndex, idx < fitnessEntries.count else { return }
        let totalMinutes = max(0, durationHoursInt * 60 + durationMinutesInt)
        fitnessEntries[idx].minutesInt = totalMinutes
        if let per30 = fitnessEntries[idx].exercise?.calPer30Min {
            let estimated = Int(round(Double(per30) * Double(totalMinutes) / 30.0))
            fitnessEntries[idx].caloriesText = String(estimated)
        }
    }
    
    private func loadTaskData() {
        guard let task = task else { return }
        titleText = task.title
        descriptionText = task.subtitle
        selectedCategory = task.category
        // Extract time from task.timeDate for time picker
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: task.timeDate)
        if let hour = timeComponents.hour, let minute = timeComponents.minute {
            // Create a Date with today's date and the task's time
            let today = Date()
            timeDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        } else {
            timeDate = Date()
        }
        
        // Create deep copies to avoid mutating the original task
        dietEntries = task.dietEntries.map { entry in
            DietEntry(
                food: entry.food,
                customName: entry.customName,
                quantityText: entry.quantityText,
                unit: entry.unit,
                caloriesText: entry.caloriesText
            )
        }
        fitnessEntries = task.fitnessEntries.map { entry in
            var newEntry = FitnessEntry()
            newEntry.exercise = entry.exercise
            newEntry.customName = entry.customName
            newEntry.minutesInt = entry.minutesInt
            newEntry.caloriesText = entry.caloriesText
            return newEntry
        }
    }
    
    private func saveChanges() {
        guard let oldTask = task else { return }
        
        // Merge time from timeDate (hour:minute) with old task's date
        // Extract date part from old task's timeDate (normalized)
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldTask.timeDate)
        
        // Extract time components from the new timeDate (selected by user)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        
        // Merge time with old task's date
        let newTimeDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                        minute: timeComponents.minute ?? 0,
                                        second: 0,
                                        of: oldDateKey) ?? oldDateKey
        
        // Calculate end time for fitness tasks
        let endTimeValue: String?
        if selectedCategory == .fitness {
            let totalMinutes = fitnessEntries.map { $0.minutesInt }.reduce(0, +)
            if totalMinutes > 0 {
                let endDate = calendar.date(byAdding: .minute, value: totalMinutes, to: newTimeDate) ?? newTimeDate
                let df = DateFormatter()
                df.locale = .current
                df.timeStyle = .short
                df.dateStyle = .none
                endTimeValue = df.string(from: endDate)
            } else {
                endTimeValue = nil
            }
        } else {
            endTimeValue = nil
        }
        
        // Build calories meta text
        let metaText: String = {
            switch selectedCategory {
            case .diet:
                let totalCalories = dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
                return "+\(totalCalories) cal"
            case .fitness:
                let totalCalories = fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
                return "-\(totalCalories) cal"
            default:
                return ""
            }
        }()
        
        // Determine the correct emphasis color based on the selected category
        let emphasisHexValue: String = {
            switch selectedCategory {
            case .diet: return "16A34A"
            case .fitness: return "364153"
            case .others: return "364153"
            case .none: return oldTask.emphasisHex
            }
        }()
        
        // Truncate subtitle
        let truncatedSubtitle = TaskEditHelper.truncateSubtitle(descriptionText)
        
        // Format time string for display
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        let timeString = df.string(from: newTimeDate)
        
        // Create new TaskItem with updated values, preserving the original id
        let newTask = TaskItem(
            id: oldTask.id,
            title: titleText.isEmpty ? oldTask.title : titleText,
            subtitle: truncatedSubtitle,
            time: timeString,
            timeDate: newTimeDate,
            endTime: endTimeValue,
            meta: metaText,
            isDone: oldTask.isDone,
            emphasisHex: emphasisHexValue,
            category: selectedCategory ?? oldTask.category,
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries
        )
        
        // Call update callback
        onUpdateTask(newTask, oldTask)
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
}
