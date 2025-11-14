import SwiftUI

struct DetailPageView: View {
    @Environment(\.dismiss) private var dismiss
    let taskId: UUID
    let getTask: (UUID) -> MainPageView.TaskItem?
    let onUpdateTask: (MainPageView.TaskItem, MainPageView.TaskItem) -> Void
    
    private var task: MainPageView.TaskItem? {
        getTask(taskId)
    }
    
    // Edit state - we need to work with mutable copies
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var timeDate: Date = Date()
    @State private var isTimeSheetPresented: Bool = false
    @State private var isEditing: Bool = false
    @State private var selectedCategory: AddTaskView.Category? = nil
    @State private var dietEntries: [AddTaskView.DietEntry] = []
    @State private var fitnessEntries: [AddTaskView.FitnessEntry] = []
    
    // Quick pick states (similar to AddTaskView)
    @State private var isQuickPickPresented: Bool = false
    @State private var quickPickMode: QuickPickMode? = nil
    @State private var quickPickSearch: String = ""
    @State private var editingDietEntryIndex: Int? = nil
    @State private var editingFitnessEntryIndex: Int? = nil
    @State private var durationHoursInt: Int = 0
    @State private var durationMinutesInt: Int = 0
    @State private var isDurationSheetPresented: Bool = false
    
    enum QuickPickMode { case food, exercise }
    
    // Focus states
    @FocusState private var dietNameFocusIndex: Int?
    @FocusState private var fitnessNameFocusIndex: Int?
    @FocusState private var searchFieldFocused: Bool
    
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
        .sheet(isPresented: $isTimeSheetPresented) {
            timePickerSheet
        }
        .sheet(isPresented: $isDurationSheetPresented) {
            durationPickerSheet
        }
        .sheet(isPresented: $isQuickPickPresented) {
            quickPickSheet
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
                    // Task Title Card
                    card {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(task.title)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color(hexString: "101828"))
                                    if !task.subtitle.isEmpty {
                                        Text(task.subtitle)
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hexString: "6A7282"))
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                    Text(task.time)
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(Color(hexString: "364153"))
                                if let endTime = task.endTime {
                                    HStack(spacing: 4) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 14))
                                        Text(endTime)
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(Color(hexString: "364153"))
                                }
                                Spacer()
                                // Status badge
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(task.isDone ? Color(hexString: task.emphasisHex) : Color(hexString: "E5E7EB"))
                                        .frame(width: 8, height: 8)
                                    Text(task.isDone ? "Done" : "Pending")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hexString: "6A7282"))
                                }
                            }
                        }
                    }
                    
                    // Diet entries
                    if task.category == .diet && !task.dietEntries.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Food Items")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hexString: "101828"))
                                
                                ForEach(task.dietEntries, id: \.id) { entry in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.food?.name ?? entry.customName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hexString: "101828"))
                                        HStack(spacing: 12) {
                                            Text("\(entry.quantityText) \(entry.unit)")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hexString: "6A7282"))
                                            Text("\(entry.caloriesText) cal")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hexString: "16A34A"))
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                
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
                        }
                    }
                    
                    // Fitness entries
                    if task.category == .fitness && !task.fitnessEntries.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Exercises")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hexString: "101828"))
                                
                                ForEach(task.fitnessEntries, id: \.id) { entry in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.exercise?.name ?? entry.customName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hexString: "101828"))
                                        HStack(spacing: 12) {
                                            Text(durationText(forMinutes: entry.minutesInt))
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hexString: "6A7282"))
                                            Text("\(entry.caloriesText) cal")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hexString: "364153"))
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(hexString: "F9FAFB"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Total Calories")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "0A0A0A"))
                                    Spacer()
                                    Text("-\(totalFitnessCalories) cal")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "364153"))
                                }
                            }
                        }
                    }
                    
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
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Task Title")
                TextField("e.g., Morning Run", text: $titleText)
                    .textInputAutocapitalization(.words)
                    .onChange(of: titleText) { _, newValue in
                        if newValue.count > 40 { titleText = String(newValue.prefix(40)) }
                    }
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
    
    private var descriptionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Description")
                TextField("e.g., 5km jog in the park", text: $descriptionText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
                            dietEntries.removeAll()
                            triggerHapticLight()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dietEntries.indices, id: \.self) { idx in
                        dietEntryRow(at: idx)
                    }
                    
                    Button(action: {
                        dietEntries.append(AddTaskView.DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
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
                }
            }
        }
    }
    
    private var fitnessEntriesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Exercises")
                    Spacer()
                    if !fitnessEntries.isEmpty {
                        Button("Clear all") {
                            fitnessEntries.removeAll()
                            triggerHapticLight()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fitnessEntries.indices, id: \.self) { idx in
                        fitnessEntryRow(at: idx)
                    }
                    
                    Button(action: {
                        fitnessEntries.append(AddTaskView.FitnessEntry())
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
                            Text("-\(totalFitnessCalories) cal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Entry Rows (similar to AddTaskView)
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
                    dietEntries.remove(at: index)
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
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    
                    let hasGrams = entry.food?.hasPer100g == true
                    let hasServing = entry.food?.servingCalories != nil
                    
                    Picker(selection: Binding(
                        get: { dietEntries[index].unit },
                        set: { newValue in
                            dietEntries[index].unit = newValue
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
                    fitnessEntries.remove(at: index)
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
        .padding(12)
        .background(Color(hexString: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Sheets
    private var timePickerSheet: some View {
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
    
    private var durationPickerSheet: some View {
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
                                if dietEntries[pickIndex].unit.isEmpty { dietEntries[pickIndex].unit = "serving" }
                                if dietEntries[pickIndex].quantityText.isEmpty { dietEntries[pickIndex].quantityText = "1" }
                                editingDietEntryIndex = nil
                                dietNameFocusIndex = pickIndex
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
                        
                        if !local.isEmpty {
                            Text("Local results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(local) { item in
                                Button(action: {
                                    if let pickIndex = editingDietEntryIndex, pickIndex < dietEntries.count {
                                        dietEntries[pickIndex].food = item
                                        dietEntries[pickIndex].customName = ""
                                        let u = item.defaultUnit ?? (item.hasPer100g ? "g" : "serving")
                                        dietEntries[pickIndex].unit = u
                                        if u == "g" { dietEntries[pickIndex].quantityText = "100" } else { dietEntries[pickIndex].quantityText = "1" }
                                        recalcEntryCalories(pickIndex)
                                        editingDietEntryIndex = nil
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
                                editingFitnessEntryIndex = nil
                                fitnessNameFocusIndex = idx
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
                        
                        if !filteredExercises.isEmpty {
                            Text("Local results")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hexString: "6A7282"))
                            ForEach(filteredExercises) { item in
                                Button(action: {
                                    if let idx = editingFitnessEntryIndex, idx < fitnessEntries.count {
                                        fitnessEntries[idx].exercise = item
                                        fitnessEntries[idx].customName = ""
                                        if fitnessEntries[idx].minutesInt == 0 { fitnessEntries[idx].minutesInt = 30 }
                                        let per30 = item.calPer30Min
                                        let est = Int(round(Double(per30) * Double(fitnessEntries[idx].minutesInt) / 30.0))
                                        fitnessEntries[idx].caloriesText = String(est)
                                        editingFitnessEntryIndex = nil
                                    }
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
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
    }
    
    private func categoryChip(_ category: AddTaskView.Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            
            if category == .diet && dietEntries.isEmpty {
                dietEntries.append(AddTaskView.DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
            } else if category == .fitness && fitnessEntries.isEmpty {
                fitnessEntries.append(AddTaskView.FitnessEntry())
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
    
    private var formattedTime: String {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: timeDate)
    }
    
    private func durationText(forMinutes minutes: Int) -> String {
        let total = max(0, minutes)
        let hours: Int = total / 60
        let mins: Int = total % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    private func formattedDuration(h: Int, m: Int) -> String {
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
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
    
    private var totalDietCalories: Int {
        dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private var totalFitnessCalories: Int {
        fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private func recalcEntryCalories(_ index: Int) {
        guard index < dietEntries.count else { return }
        guard dietEntries[index].food != nil else { return }
        let calculatedCalories = dietEntryCalories(dietEntries[index])
        dietEntries[index].caloriesText = String(calculatedCalories)
    }
    
    private func dietEntryCalories(_ entry: AddTaskView.DietEntry) -> Int {
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
        return "—"
    }
    
    private func recalcCaloriesFromDurationIfNeeded() {
        guard selectedCategory == .fitness else { return }
        guard let idx = editingFitnessEntryIndex, idx < fitnessEntries.count else { return }
        let h = durationHoursInt
        let m = durationMinutesInt
        let totalMinutes = max(0, h * 60 + m)
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
            AddTaskView.DietEntry(
                food: entry.food,
                customName: entry.customName,
                quantityText: entry.quantityText,
                unit: entry.unit,
                caloriesText: entry.caloriesText
            )
        }
        fitnessEntries = task.fitnessEntries.map { entry in
            var newEntry = AddTaskView.FitnessEntry()
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
                return "+\(totalDietCalories) cal"
            case .fitness:
                return "-\(totalFitnessCalories) cal"
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
        let truncatedSubtitle = truncateSubtitle(descriptionText)
        
        // Format time string for display
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        let timeString = df.string(from: newTimeDate)
        
        // Create new TaskItem with updated values, preserving the original id
        let newTask = MainPageView.TaskItem(
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
    
    private func truncateSubtitle(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        let firstSentence = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        
        if firstSentence.count > 50 {
            let truncated = String(firstSentence.prefix(47))
            return truncated + "..."
        }
        
        return firstSentence
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
