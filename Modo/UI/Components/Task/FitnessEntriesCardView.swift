import SwiftUI

/// Fitness entries card component for task form
struct FitnessEntriesCardView: View {
    @Binding var fitnessEntries: [FitnessEntry]
    @Binding var editingFitnessEntryIndex: Int?
    @Binding var titleText: String
    @FocusState.Binding var fitnessNameFocusIndex: Int?
    @Binding var pendingScrollId: String?
    @Binding var editingSets: Int?
    @Binding var editingReps: String?
    @Binding var editingRestSec: Int?
    @Binding var editingDurationMin: Int
    @Binding var isTrainingParamsSheetPresented: Bool
    
    let onAddExercise: () -> Void
    let onEditExercise: (Int) -> Void
    let onDeleteExercise: (Int) -> Void
    let onClearAll: () -> Void
    let onTriggerHaptic: () -> Void
    let onDismissKeyboard: () -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Exercises")
                    Spacer()
                    if !fitnessEntries.isEmpty {
                        Button("Clear all") {
                            onClearAll()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fitnessEntries.indices, id: \.self) { idx in
                        fitnessEntryRow(at: idx)
                            .id("fit-\(idx)")
                    }
                    
                    Button(action: onAddExercise) {
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
                        .background(Color(.tertiarySystemBackground))
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
                                .foregroundColor(.primary)
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
                            .foregroundColor(.secondary)
                        Text("No exercise added yet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Tap 'Add Exercise' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
    }
    
    private var totalFitnessCalories: Int {
        fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private func fitnessEntryRow(at index: Int) -> some View {
        let entry = fitnessEntries[index]
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    onEditExercise(index)
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(entry.exercise?.name ?? (entry.customName.isEmpty ? "Choose Exercise" : entry.customName))
                            .foregroundColor(entry.exercise != nil ? .primary : .secondary)
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
                    onDeleteExercise(index)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hexString: "EF4444"))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            // Training Parameters (only show if any value exists)
            if entry.sets != nil || entry.reps != nil || entry.restSec != nil {
                Button(action: {
                    // Load current values
                    editingSets = entry.sets
                    editingReps = entry.reps
                    editingRestSec = entry.restSec
                    editingDurationMin = entry.minutesInt
                    // Clear focus
                    onDismissKeyboard()
                    isTrainingParamsSheetPresented = true
                    editingFitnessEntryIndex = index
                }) {
                    HStack(spacing: 12) {
                        if let sets = entry.sets, let reps = entry.reps {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sets × Reps")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("\(sets) × \(reps)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if entry.sets != nil || entry.reps != nil, entry.restSec != nil {
                            Divider()
                                .frame(height: 32)
                        }
                        
                        if let rest = entry.restSec {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rest")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("\(rest)s")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }
                        
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
            } else {
                // Show "Add Training Params" button if no params exist
                Button(action: {
                    // Initialize with empty values
                    editingSets = 3
                    editingReps = "10"
                    editingRestSec = 60
                    editingDurationMin = entry.minutesInt
                    onDismissKeyboard()
                    isTrainingParamsSheetPresented = true
                    editingFitnessEntryIndex = index
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.secondary)
                        Text("Add Training Details")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                            .opacity(0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            
            if entry.exercise == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Exercise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("e.g., Stretching", text: Binding(
                        get: { fitnessEntries[index].customName },
                        set: { newValue in fitnessEntries[index].customName = newValue }
                    ))
                    .focused($fitnessNameFocusIndex, equals: index)
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
        .contextMenu {
            Button("Duplicate") {
                let copy = entry
                fitnessEntries.insert(copy, at: min(index + 1, fitnessEntries.count))
                pendingScrollId = "fit-\(min(index + 1, fitnessEntries.count - 1))"
                onTriggerHaptic()
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
        @State private var fitnessEntries: [FitnessEntry] = [
            FitnessEntry()
        ]
        @State private var editingFitnessEntryIndex: Int? = nil
        @State private var titleText = ""
        @FocusState private var fitnessNameFocusIndex: Int?
        @State private var pendingScrollId: String? = nil
        @State private var editingSets: Int? = 3
        @State private var editingReps: String? = "10"
        @State private var editingRestSec: Int? = 60
        @State private var editingDurationMin: Int = 0
        @State private var isTrainingParamsSheetPresented: Bool = false
        
        var body: some View {
            FitnessEntriesCardView(
                fitnessEntries: $fitnessEntries,
                editingFitnessEntryIndex: $editingFitnessEntryIndex,
                titleText: $titleText,
                fitnessNameFocusIndex: $fitnessNameFocusIndex,
                pendingScrollId: $pendingScrollId,
                editingSets: $editingSets,
                editingReps: $editingReps,
                editingRestSec: $editingRestSec,
                editingDurationMin: $editingDurationMin,
                isTrainingParamsSheetPresented: $isTrainingParamsSheetPresented,
                onAddExercise: {
                    fitnessEntries.append(FitnessEntry())
                },
                onEditExercise: { index in
                    editingFitnessEntryIndex = index
                },
                onDeleteExercise: { index in
                    fitnessEntries.remove(at: index)
                },
                onClearAll: {
                    fitnessEntries.removeAll()
                },
                onTriggerHaptic: {},
                onDismissKeyboard: {}
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

