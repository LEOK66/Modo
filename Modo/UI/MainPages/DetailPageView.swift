import SwiftUI
import SwiftData

struct DetailPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let taskId: UUID
    let getTask: (UUID) -> TaskItem?
    let onUpdateTask: (TaskItem, TaskItem) -> Void
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel: DetailTaskViewModel
    
    // UI-only states (cannot be in ViewModel)
    @State private var isTimeSheetPresented: Bool = false
    @State private var isQuickPickPresented: Bool = false
    @State private var quickPickMode: QuickPickSheetView.QuickPickMode? = nil
    @State private var quickPickSearch: String = ""
    @State private var isDurationSheetPresented: Bool = false
    
    // QuickPickSheetView states
    @State private var recentFoods: [MenuData.FoodItem] = []
    @State private var recentExercises: [MenuData.ExerciseItem] = []
    @State private var onlineFoods: [MenuData.FoodItem] = []
    @State private var isOnlineLoading: Bool = false
    
    // Focus states (cannot be in ViewModel)
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    @State private var pendingScrollId: String? = nil
    
    // Initialize ViewModel
    init(taskId: UUID, getTask: @escaping (UUID) -> TaskItem?, onUpdateTask: @escaping (TaskItem, TaskItem) -> Void) {
        self.taskId = taskId
        self.getTask = getTask
        self.onUpdateTask = onUpdateTask
        
        // Create temporary model context for ViewModel initialization
        // The actual modelContext will be set in onAppear via environment
        let schema = Schema([UserProfile.self, FirebaseChatMessage.self, DailyCompletion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let tempModelContext = ModelContext(container)
        
        // Get initial task if available
        let initialTask = getTask(taskId)
        
        // Create ViewModel directly with default parameters
        // Repository will be created automatically using ServiceContainer
        self._viewModel = StateObject(wrappedValue: DetailTaskViewModel(
            task: initialTask,
            modelContext: tempModelContext
        ))
    }
    
    private var task: TaskItem? {
        viewModel.task
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
            // Check if task exists
            if let task = task {
                VStack(spacing: 0) {
                    // Header
                    PageHeader(title: viewModel.isEditing ? "Edit Task" : "Task Details")
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                if viewModel.isEditing {
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
                    
                    if viewModel.isEditing {
                        bottomActionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isEditing)
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
                durationHours: $viewModel.durationHoursInt,
                durationMinutes: $viewModel.durationMinutesInt,
                onDurationChanged: {
                    viewModel.recalcCaloriesFromDurationIfNeeded()
                }
            )
        }
        .sheet(isPresented: $isQuickPickPresented) {
            QuickPickSheetView(
                isPresented: $isQuickPickPresented,
                mode: quickPickMode,
                searchText: $quickPickSearch,
                dietEntries: $viewModel.dietEntries,
                editingDietEntryIndex: $viewModel.editingDietEntryIndex,
                fitnessEntries: $viewModel.fitnessEntries,
                editingFitnessEntryIndex: $viewModel.editingFitnessEntryIndex,
                titleText: $viewModel.titleText,
                recentFoods: $recentFoods,
                recentExercises: $recentExercises,
                onlineFoods: $onlineFoods,
                isOnlineLoading: $isOnlineLoading,
                onRecalcDietCalories: { index in
                    viewModel.recalcEntryCalories(index)
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
            if let task = self.task {
                viewModel.loadTaskData(from: task)
            }
        }
        .onChange(of: taskId) { _, _ in
            // Reload data if task id changes
            if let task = self.task {
                viewModel.loadTaskData(from: task)
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
                        viewModel.startEditing()
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
                    
                    if viewModel.selectedCategory == .diet {
                        caloriesCard
                    }
                    
                    if viewModel.selectedCategory == .fitness {
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
            titleText: $viewModel.titleText,
            titleFocused: $titleFocused,
            isTitleGenerating: false,
            onGenerateTapped: {}
        )
    }
    
    private var descriptionCard: some View {
        DescriptionCardView(
            descriptionText: $viewModel.descriptionText,
            descriptionFocused: $descriptionFocused,
            isDescriptionGenerating: false,
            onGenerateTapped: {}
        )
    }
    
    private var timeCard: some View {
        TimeCardView(
            timeDate: $viewModel.timeDate,
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
            selectedCategory: $viewModel.selectedCategory,
            dietEntries: $viewModel.dietEntries,
            fitnessEntries: $viewModel.fitnessEntries
        )
    }
    
    private var caloriesCard: some View {
        DietEntriesCardView(
            dietEntries: $viewModel.dietEntries,
            editingDietEntryIndex: $viewModel.editingDietEntryIndex,
            titleText: $viewModel.titleText,
            dietNameFocusIndex: $dietNameFocusIndex,
            pendingScrollId: $pendingScrollId,
            onAddFoodItem: {
                viewModel.dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
                viewModel.editingDietEntryIndex = viewModel.dietEntries.count - 1
                quickPickMode = .food
                quickPickSearch = ""
                isQuickPickPresented = true
                triggerHapticLight()
            },
            onEditFoodItem: { index in
                viewModel.editingDietEntryIndex = index
                quickPickMode = .food
                quickPickSearch = ""
                isQuickPickPresented = true
            },
            onDeleteFoodItem: { index in
                viewModel.dietEntries.remove(at: index)
                triggerHapticMedium()
            },
            onClearAll: {
                viewModel.dietEntries.removeAll()
                triggerHapticLight()
            },
            onRecalcCalories: { index in
                viewModel.recalcEntryCalories(index)
            },
            onTriggerHaptic: {
                triggerHapticLight()
            }
        )
    }
    
    private var fitnessEntriesCard: some View {
        FitnessEntriesCardView(
            fitnessEntries: $viewModel.fitnessEntries,
            editingFitnessEntryIndex: $viewModel.editingFitnessEntryIndex,
            titleText: $viewModel.titleText,
            fitnessNameFocusIndex: $fitnessNameFocusIndex,
            pendingScrollId: $pendingScrollId,
            durationHoursInt: $viewModel.durationHoursInt,
            durationMinutesInt: $viewModel.durationMinutesInt,
            isDurationSheetPresented: $isDurationSheetPresented,
            onAddExercise: {
                viewModel.fitnessEntries.append(FitnessEntry())
                viewModel.editingFitnessEntryIndex = viewModel.fitnessEntries.count - 1
                quickPickMode = .exercise
                quickPickSearch = ""
                isQuickPickPresented = true
                triggerHapticLight()
            },
            onEditExercise: { index in
                viewModel.editingFitnessEntryIndex = index
                quickPickMode = .exercise
                quickPickSearch = ""
                isQuickPickPresented = true
            },
            onDeleteExercise: { index in
                viewModel.fitnessEntries.remove(at: index)
                triggerHapticMedium()
            },
            onClearAll: {
                viewModel.fitnessEntries.removeAll()
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
                    viewModel.cancelEditing()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "364153"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button(action: {
                    viewModel.saveChanges { result in
                        switch result {
                        case .success(let updatedTask):
                            // Notify parent view of the update
                            if let oldTask = viewModel.originalTask {
                                onUpdateTask(updatedTask, oldTask)
                            }
                            triggerHapticMedium()
                        case .failure(let error):
                            // Error is already handled in ViewModel (errorMessage)
                            print("Failed to save task: \(error.localizedDescription)")
                        }
                    }
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
