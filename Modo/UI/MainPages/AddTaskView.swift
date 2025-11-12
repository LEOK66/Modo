import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let selectedDate: Date
    @Binding var newlyAddedTaskId: UUID?
    let onTaskCreated: (TaskItem) -> Void
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel: AddTaskViewModel
    
    // Focus states (cannot be in ViewModel, must be in View)
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    
    init(selectedDate: Date, newlyAddedTaskId: Binding<UUID?>, onTaskCreated: @escaping (TaskItem) -> Void) {
        self.selectedDate = selectedDate
        self._newlyAddedTaskId = newlyAddedTaskId
        self.onTaskCreated = onTaskCreated
        
        // Create temporary model context for ViewModel initialization
        // The actual modelContext from @Environment will be used via updateViewModelWithModelContext()
        // This is needed because @StateObject requires initialization in init, but @Environment
        // is only available when the view's body is rendered
        let schema = Schema([UserProfile.self, FirebaseChatMessage.self, DailyCompletion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let tempModelContext = ModelContext(container)
        
        // Create ViewModel directly with default parameters
        // Repository will be created automatically using ServiceContainer
        self._viewModel = StateObject(wrappedValue: AddTaskViewModel(
            selectedDate: selectedDate,
            modelContext: tempModelContext
        ))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            backgroundView
            mainContentView
            undoBannerView
        }
        .sheet(isPresented: $viewModel.isQuickPickPresented) {
            quickPickSheet
        }
        .sheet(isPresented: $viewModel.isAskAISheetPresented) {
            AskAIChatView(messages: $viewModel.askAIMessages)
        }
        .sheet(isPresented: $viewModel.isDurationSheetPresented, onDismiss: {
            viewModel.recalcCaloriesFromDurationIfNeeded()
            viewModel.dismissKeyboard()
        }) {
            durationSheet
        }
        .onChange(of: viewModel.isQuickPickPresented) { _, isPresented in
            if !isPresented {
                viewModel.clearEditingIndices()
            }
        }
        .onChange(of: titleFocused) { _, isFocused in
            viewModel.titleFocused = isFocused
        }
        .onChange(of: descriptionFocused) { _, isFocused in
            viewModel.descriptionFocused = isFocused
        }
        .onChange(of: dietNameFocusIndex) { _, index in
            viewModel.dietNameFocusIndex = index
        }
        .onChange(of: fitnessNameFocusIndex) { _, index in
            viewModel.fitnessNameFocusIndex = index
        }
        .onChange(of: viewModel.titleFocused) { _, isFocused in
            titleFocused = isFocused
        }
        .onChange(of: viewModel.descriptionFocused) { _, isFocused in
            descriptionFocused = isFocused
        }
        .onChange(of: viewModel.dietNameFocusIndex) { _, index in
            dietNameFocusIndex = index
        }
        .onChange(of: viewModel.fitnessNameFocusIndex) { _, index in
            fitnessNameFocusIndex = index
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
        .onAppear {
            // Update ViewModel's modelContext with the actual one from environment
            // This is needed because @StateObject is initialized in init() before @Environment is available
            viewModel.updateModelContext(modelContext)
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        Color(hexString: "F9FAFB")
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.dismissKeyboard()
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
                isAIGenerating: viewModel.isAIGenerating,
                onAskAITapped: { viewModel.isAskAISheetPresented = true },
                onAIGenerateTapped: { viewModel.generateTaskAutomatically() }
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
                    if viewModel.selectedCategory == .diet {
                        dismissKeyboardSpacer
                        dietEntriesCard
                    }
                    if viewModel.selectedCategory == .fitness {
                        dismissKeyboardSpacer
                        fitnessEntriesCard
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.pendingScrollId) { _, newValue in
                guard let id = newValue else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
                viewModel.pendingScrollId = nil
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
                viewModel.dismissKeyboard()
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
    
    private var undoBannerView: some View {
        Group {
            if viewModel.showUndoBanner {
                HStack(spacing: 12) {
                    Text(viewModel.undoMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "101828"))
                    Spacer()
                    Button("Undo") {
                        viewModel.handleUndoAction()
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
    
    private var quickPickSheet: some View {
        QuickPickSheetView(
            isPresented: $viewModel.isQuickPickPresented,
            mode: viewModel.quickPickMode,
            searchText: $viewModel.quickPickSearch,
            dietEntries: $viewModel.dietEntries,
            editingDietEntryIndex: $viewModel.editingDietEntryIndex,
            fitnessEntries: $viewModel.fitnessEntries,
            editingFitnessEntryIndex: $viewModel.editingFitnessEntryIndex,
            titleText: $viewModel.title,
            recentFoods: $viewModel.recentFoods,
            recentExercises: $viewModel.recentExercises,
            onlineFoods: $viewModel.onlineFoods,
            isOnlineLoading: $viewModel.isOnlineLoading,
            onRecalcDietCalories: { index in
                viewModel.recalcEntryCalories(at: index)
            },
            onPendingScrollId: { id in
                viewModel.pendingScrollId = id
            },
            onSetDietFocusIndex: { index in
                viewModel.dietNameFocusIndex = index
                dietNameFocusIndex = index
            },
            onSetFitnessFocusIndex: { index in
                viewModel.fitnessNameFocusIndex = index
                fitnessNameFocusIndex = index
            },
            onSearchFoods: { query, completion in
                viewModel.searchFoods(query: query, completion: completion)
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
                    Picker("Hours", selection: $viewModel.durationHoursInt) {
                        ForEach(0...5, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .onChange(of: viewModel.durationHoursInt) { _, _ in
                        viewModel.recalcCaloriesFromDurationIfNeeded()
                    }
                }
                VStack {
                    Text("Minutes")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Picker("Minutes", selection: $viewModel.durationMinutesInt) {
                        ForEach(0...59, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .onChange(of: viewModel.durationMinutesInt) { _, _ in
                        viewModel.recalcCaloriesFromDurationIfNeeded()
                    }
                }
            }
            Button("Done") {
                viewModel.recalcCaloriesFromDurationIfNeeded()
                viewModel.isDurationSheetPresented = false
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
            titleText: $viewModel.title,
            titleFocused: $titleFocused,
            isTitleGenerating: viewModel.isTitleGenerating,
            onGenerateTapped: { viewModel.generateOrRefineTitle() }
        )
    }

    private var descriptionCard: some View {
        DescriptionCardView(
            descriptionText: $viewModel.description,
            descriptionFocused: $descriptionFocused,
            isDescriptionGenerating: viewModel.isDescriptionGenerating,
            onGenerateTapped: { viewModel.generateDescription() }
        )
    }

    private var timeCard: some View {
        TimeCardView(
            timeDate: $viewModel.timeDate,
            isTimeSheetPresented: $viewModel.isTimeSheetPresented,
            onDismissKeyboard: { viewModel.dismissKeyboard() }
        )
    }

    private var categoryCard: some View {
        CategoryCardView(
            selectedCategory: $viewModel.selectedCategory,
            dietEntries: $viewModel.dietEntries,
            fitnessEntries: $viewModel.fitnessEntries
        )
    }

    private var dietEntriesCard: some View {
        DietEntriesCardView(
            dietEntries: $viewModel.dietEntries,
            editingDietEntryIndex: $viewModel.editingDietEntryIndex,
            titleText: $viewModel.title,
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
                viewModel.clearAllDietEntries()
                triggerHapticLight()
            },
            onRecalcCalories: { index in
                viewModel.recalcEntryCalories(at: index)
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
            titleText: $viewModel.title,
            fitnessNameFocusIndex: $fitnessNameFocusIndex,
            pendingScrollId: $viewModel.pendingScrollId,
            durationHoursInt: $viewModel.durationHoursInt,
            durationMinutesInt: $viewModel.durationMinutesInt,
            isDurationSheetPresented: $viewModel.isDurationSheetPresented,
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
                viewModel.clearAllFitnessEntries()
                triggerHapticLight()
            },
            onTriggerHaptic: {
                triggerHapticLight()
            },
            onDismissKeyboard: {
                viewModel.dismissKeyboard()
            },
            formattedDuration: { h, m in
                viewModel.formattedDuration(h: h, m: m)
            }
        )
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
                        .background(viewModel.canSave ? Color.black : Color(hexString: "D1D5DB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!viewModel.canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateViewModelWithModelContext() {
        // Update ViewModel with actual modelContext from environment
        viewModel.updateModelContext(modelContext)
    }
    
    private func saveTask() {
        guard let task = viewModel.createTask() else {
            return
        }
        
        onTaskCreated(task)
        newlyAddedTaskId = task.id
        triggerHapticMedium()
        dismiss()
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
