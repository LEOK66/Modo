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
    
    // Focus states (cannot be in ViewModel, must be in View)
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    
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
            Color(.systemBackground).ignoresSafeArea()
            
            // Check if task exists
            if task != nil {
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
                        .foregroundColor(.secondary)
                    Button("Go Back") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $viewModel.isTrainingParamsSheetPresented, onDismiss: {
            viewModel.saveTrainingParamsToEntry()
        }) {
            trainingParamsSheet
        }
        .sheet(isPresented: $viewModel.isQuickPickPresented) {
            QuickPickSheetView(
                isPresented: $viewModel.isQuickPickPresented,
                mode: viewModel.quickPickMode,
                searchText: $viewModel.quickPickSearch,
                dietEntries: $viewModel.dietEntries,
                editingDietEntryIndex: $viewModel.editingDietEntryIndex,
                fitnessEntries: $viewModel.fitnessEntries,
                editingFitnessEntryIndex: $viewModel.editingFitnessEntryIndex,
                titleText: $viewModel.titleText,
                recentFoods: $viewModel.recentFoods,
                recentExercises: $viewModel.recentExercises,
                onlineFoods: $viewModel.onlineFoods,
                isOnlineLoading: $viewModel.isOnlineLoading,
                onRecalcDietCalories: { index in
                    viewModel.recalcEntryCalories(index)
                },
                onPendingScrollId: { id in
                    viewModel.pendingScrollId = id
                },
                onSetDietFocusIndex: { index in
                    dietNameFocusIndex = index
                },
                onSetFitnessFocusIndex: { index in
                    fitnessNameFocusIndex = index
                },
                onSearchFoods: { _, completion in
                    // For DetailPageView, we don't need online search
                    completion([])
                }
            )
        }
        .onChange(of: viewModel.isQuickPickPresented) { _, isPresented in
            if !isPresented {
                viewModel.clearEditingIndices()
            }
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
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Only handle horizontal swipes (ignore vertical)
                    if abs(horizontalAmount) > abs(verticalAmount) && horizontalAmount > 0 {
                        dismiss()
                    }
                }
        )
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
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
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
            isTimeSheetPresented: $viewModel.isTimeSheetPresented,
            onDismissKeyboard: {
                titleFocused = false
                descriptionFocused = false
                dietNameFocusIndex = nil
                fitnessNameFocusIndex = nil
                viewModel.dismissKeyboard()
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
            pendingScrollId: $viewModel.pendingScrollId,
            onAddFoodItem: {
                viewModel.addDietEntry()
                triggerHapticLight()
            },
            onEditFoodItem: { index in
                viewModel.editDietEntry(at: index)
            },
            onDeleteFoodItem: { index in
                viewModel.deleteDietEntry(at: index)
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
            pendingScrollId: $viewModel.pendingScrollId,
            editingSets: $viewModel.editingSets,
            editingReps: $viewModel.editingReps,
            editingRestSec: $viewModel.editingRestSec,
            editingDurationMin: $viewModel.editingDurationMin,
            isTrainingParamsSheetPresented: $viewModel.isTrainingParamsSheetPresented,
            onAddExercise: {
                viewModel.addFitnessEntry()
                triggerHapticLight()
            },
            onEditExercise: { index in
                viewModel.editFitnessEntry(at: index)
            },
            onDeleteExercise: { index in
                viewModel.deleteFitnessEntry(at: index)
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
                viewModel.dismissKeyboard()
            }
        )
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color(UIColor.separator))
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.cancelEditing()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button(action: {
                    viewModel.saveChanges { result in
                        switch result {
                        case .success(let updatedTask):
                            if let oldTask = viewModel.originalTask {
                                onUpdateTask(updatedTask, oldTask)
                            }
                            triggerHapticMedium()
                        case .failure(let error):
                            print("Failed to save task: \(error.localizedDescription)")
                        }
                    }
                }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Training Parameters Sheet
    
    private var trainingParamsSheet: some View {
        VStack(spacing: 16) {
            Text("Training Parameters")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sets")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("Sets", selection: Binding(
                            get: { viewModel.editingSets ?? 3 },
                            set: { viewModel.editingSets = $0 }
                        )) {
                            ForEach(1...10, id: \.self) { Text("\($0)") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps per Set")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        TextField("10", text: Binding(
                            get: { viewModel.editingReps ?? "" },
                            set: { viewModel.editingReps = $0.isEmpty ? nil : $0 }
                        ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rest (seconds)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("Rest", selection: Binding(
                            get: { viewModel.editingRestSec ?? 60 },
                            set: { viewModel.editingRestSec = $0 }
                        )) {
                            ForEach([30, 45, 60, 90, 120, 180], id: \.self) { Text("\($0)s") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration (min)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("Duration", selection: $viewModel.editingDurationMin) {
                            ForEach(0...120, id: \.self) { Text("\($0)") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Button("Done") {
                viewModel.saveTrainingParamsToEntry()
                viewModel.isTrainingParamsSheetPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
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
