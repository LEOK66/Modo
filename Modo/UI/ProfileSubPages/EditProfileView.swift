import SwiftUI
import SwiftData
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProfileService: UserProfileService
    @Query private var profiles: [UserProfile]
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel = EditProfileViewModel()
    
    private var userProfile: UserProfile? {
        userProfileService.currentProfile
    }

    var body: some View {
        Form {
            Section(header: Text("Body Metrics")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("-", text: $viewModel.heightValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("Unit", selection: $viewModel.heightUnit) {
                            Text("cm").tag("cm")
                            Text("in").tag("in")
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: viewModel.heightValue) {
                        if !viewModel.heightValue.isEmpty {
                            _ = viewModel.validateHeight()
                        } else {
                            viewModel.showHeightError = false
                        }
                    }
                    .onChange(of: viewModel.heightUnit) {
                        if !viewModel.heightValue.isEmpty {
                            _ = viewModel.validateHeight()
                        } else {
                            viewModel.showHeightError = false
                        }
                    }
                    if viewModel.showHeightError {
                        let range = viewModel.heightUnit == "cm" ? "50-250" : "20-96"
                        Text("Please enter a valid height (\(range) \(viewModel.heightUnit))")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("-", text: $viewModel.weightValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("Unit", selection: $viewModel.weightUnit) {
                            Text("kg").tag("kg")
                            Text("lb").tag("lb")
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: viewModel.weightValue) {
                        if !viewModel.weightValue.isEmpty {
                            _ = viewModel.validateWeight()
                        } else {
                            viewModel.showWeightError = false
                        }
                    }
                    .onChange(of: viewModel.weightUnit) {
                        if !viewModel.weightValue.isEmpty {
                            _ = viewModel.validateWeight()
                        } else {
                            viewModel.showWeightError = false
                        }
                    }
                    if viewModel.showWeightError {
                        let range = viewModel.weightUnit == "kg" ? "20-500" : "44-1100"
                        Text("Please enter a valid weight (\(range) \(viewModel.weightUnit))")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("-", text: $viewModel.ageValue)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section(header: Text("Basics")) {
                Picker("Gender", selection: Binding(get: { viewModel.genderCode ?? "" }, set: { viewModel.genderCode = $0.isEmpty ? nil : $0 })) {
                    Text("-").tag("")
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                    Text("Other").tag("other")
                }
                Picker("Lifestyle", selection: Binding(get: { viewModel.lifestyleCode ?? "" }, set: { viewModel.lifestyleCode = $0.isEmpty ? nil : $0 })) {
                    Text("-").tag("")
                    Text("Sedentary").tag("sedentary")
                    Text("Moderately Active").tag("moderately_active")
                    Text("Athletic").tag("athletic")
                }
            }

            Section(header: Text("Goal")) {
                Picker("Type", selection: Binding(get: { viewModel.goalCode ?? "" }, set: { viewModel.goalCode = $0.isEmpty ? nil : $0 })) {
                    Text("-").tag("")
                    Text("Lose Weight").tag("lose_weight")
                    Text("Keep Healthy").tag("keep_healthy")
                    Text("Gain Muscle").tag("gain_muscle")
                }
                if viewModel.goalCode == "lose_weight" {
                    HStack {
                        Text("Target Loss")
                        Spacer()
                        TextField("-", text: $viewModel.targetWeightLoss)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("Unit", selection: $viewModel.targetWeightLossUnit) {
                            Text("kg").tag("kg")
                            Text("lb").tag("lb")
                        }
                        .pickerStyle(.menu)
                    }
                } else if viewModel.goalCode == "keep_healthy" {
                    HStack {
                        Text("Daily Calories")
                        Spacer()
                        TextField("-", text: $viewModel.dailyCalories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("kcal")
                    }
                    if let rec = viewModel.recommendedCaloriesValue() {
                        HStack {
                            Text("Recommended")
                            Spacer()
                            Text("\(rec) kcal").foregroundColor(.secondary)
                            Button("Use") { viewModel.dailyCalories = String(rec) }
                        }
                    }
                } else if viewModel.goalCode == "gain_muscle" {
                    HStack {
                        Text("Daily Protein")
                        Spacer()
                        TextField("-", text: $viewModel.dailyProtein)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                    }
                    if let rec = viewModel.recommendedProteinValue() {
                        HStack {
                            Text("Recommended")
                            Spacer()
                            Text("\(rec) g").foregroundColor(.secondary)
                            Button("Use") { viewModel.dailyProtein = String(rec) }
                        }
                    }
                }
                HStack {
                    Text("Target Days")
                    Spacer()
                    TextField("-", text: $viewModel.targetDays)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                if viewModel.showTargetDaysError {
                    Text("Please enter 1-365 days")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.saveChanges()
                    dismiss()
                }
            }
        }
        .onAppear {
            // Setup ViewModel with dependencies
            viewModel.setup(
                modelContext: modelContext,
                authService: authService,
                userProfileService: userProfileService,
                userProfile: userProfile
            )
            // Prefill suggestions if empty
            if viewModel.goalCode == "keep_healthy", viewModel.dailyCalories.isEmpty, let rec = viewModel.recommendedCaloriesValue() {
                viewModel.dailyCalories = String(rec)
            }
            if viewModel.goalCode == "gain_muscle", viewModel.dailyProtein.isEmpty, let rec = viewModel.recommendedProteinValue() {
                viewModel.dailyProtein = String(rec)
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            Color.white
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }

}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
        .modelContainer(for: [UserProfile.self, DailyCompletion.self])
}


