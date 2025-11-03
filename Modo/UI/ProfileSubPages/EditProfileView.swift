import SwiftUI
import SwiftData
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @Query private var profiles: [UserProfile]

    // Local editable states (initialized from existing profile)
    @State private var heightValue: String = ""
    @State private var heightUnit: String = "cm"
    @State private var weightValue: String = ""
    @State private var weightUnit: String = "kg"
    @State private var ageValue: String = ""
    @State private var genderCode: String? = nil
    @State private var lifestyleCode: String? = nil
    @State private var goalCode: String? = nil
    @State private var dailyCalories: String = ""
    @State private var dailyProtein: String = ""
    @State private var targetWeightLoss: String = ""
    @State private var targetWeightLossUnit: String = "kg"
    @State private var targetDays: String = ""

    // Validation flags (lightweight)
    @State private var showTargetDaysError = false

    private var userProfile: UserProfile? {
        guard let userId = authService.currentUser?.uid else { return nil }
        return profiles.first { $0.userId == userId }
    }
    
    // MARK: - Helpers for recommendations
    private func weightInKg() -> Double? {
        guard let v = Double(weightValue) else { return nil }
        return HealthCalculator.convertWeightToKg(v, unit: weightUnit)
    }
    private func heightInCm() -> Double? {
        guard let v = Double(heightValue) else { return nil }
        return HealthCalculator.convertHeightToCm(v, unit: heightUnit)
    }
    private func recommendedCaloriesValue() -> Int? {
        guard let age = Int(ageValue),
              let gender = genderCode,
              let kg = weightInKg(),
              let cm = heightInCm(),
              let lifestyle = lifestyleCode else { return nil }
        return HealthCalculator.recommendedCalories(age: age, genderCode: gender, weightKg: kg, heightCm: cm, lifestyleCode: lifestyle)
    }
    private func recommendedProteinValue() -> Int? {
        guard let kg = weightInKg() else { return nil }
        return HealthCalculator.recommendedProtein(weightKg: kg)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Body Metrics")) {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("-", text: $heightValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("Unit", selection: $heightUnit) {
                            Text("cm").tag("cm")
                            Text("in").tag("in")
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("-", text: $weightValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("Unit", selection: $weightUnit) {
                            Text("kg").tag("kg")
                            Text("lb").tag("lb")
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("-", text: $ageValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Basics")) {
                    Picker("Gender", selection: Binding(get: { genderCode ?? "" }, set: { genderCode = $0.isEmpty ? nil : $0 })) {
                        Text("-").tag("")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    Picker("Lifestyle", selection: Binding(get: { lifestyleCode ?? "" }, set: { lifestyleCode = $0.isEmpty ? nil : $0 })) {
                        Text("-").tag("")
                        Text("Sedentary").tag("sedentary")
                        Text("Moderately Active").tag("moderately_active")
                        Text("Athletic").tag("athletic")
                    }
                }

                Section(header: Text("Goal")) {
                    Picker("Type", selection: Binding(get: { goalCode ?? "" }, set: { goalCode = $0.isEmpty ? nil : $0 })) {
                        Text("-").tag("")
                        Text("Lose Weight").tag("lose_weight")
                        Text("Keep Healthy").tag("keep_healthy")
                        Text("Gain Muscle").tag("gain_muscle")
                    }
                    if goalCode == "lose_weight" {
                        HStack {
                            Text("Target Loss")
                            Spacer()
                            TextField("-", text: $targetWeightLoss)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Picker("Unit", selection: $targetWeightLossUnit) {
                                Text("kg").tag("kg")
                                Text("lb").tag("lb")
                            }
                            .pickerStyle(.menu)
                        }
                    } else if goalCode == "keep_healthy" {
                        HStack {
                            Text("Daily Calories")
                            Spacer()
                            TextField("-", text: $dailyCalories)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("kcal")
                        }
                        if let rec = recommendedCaloriesValue() {
                            HStack {
                                Text("Recommended")
                                Spacer()
                                Text("\(rec) kcal").foregroundColor(.secondary)
                                Button("Use") { dailyCalories = String(rec) }
                            }
                        }
                    } else if goalCode == "gain_muscle" {
                        HStack {
                            Text("Daily Protein")
                            Spacer()
                            TextField("-", text: $dailyProtein)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("g")
                        }
                        if let rec = recommendedProteinValue() {
                            HStack {
                                Text("Recommended")
                                Spacer()
                                Text("\(rec) g").foregroundColor(.secondary)
                                Button("Use") { dailyProtein = String(rec) }
                            }
                        }
                    }
                    HStack {
                        Text("Target Days")
                        Spacer()
                        TextField("-", text: $targetDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if showTargetDaysError {
                        Text("Please enter 1-365 days")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
            .onAppear {
                hydrateFromProfile()
                // Prefill suggestions if empty
                if goalCode == "keep_healthy", dailyCalories.isEmpty, let rec = recommendedCaloriesValue() {
                    dailyCalories = String(rec)
                }
                if goalCode == "gain_muscle", dailyProtein.isEmpty, let rec = recommendedProteinValue() {
                    dailyProtein = String(rec)
                }
            }
        }
    }

    private func hydrateFromProfile() {
        guard let p = userProfile else { return }
        if let h = p.heightValue { heightValue = String(Int(h)) }
        heightUnit = p.heightUnit ?? heightUnit
        if let w = p.weightValue { weightValue = String(Int(w)) }
        weightUnit = p.weightUnit ?? weightUnit
        if let a = p.age { ageValue = String(a) }
        genderCode = p.gender
        lifestyleCode = p.lifestyle
        goalCode = p.goal
        if let c = p.dailyCalories { dailyCalories = String(c) }
        if let pr = p.dailyProtein { dailyProtein = String(pr) }
        if let tw = p.targetWeightLossValue { targetWeightLoss = String(Int(tw)) }
        targetWeightLossUnit = p.targetWeightLossUnit ?? targetWeightLossUnit
        if let td = p.targetDays { targetDays = String(td) }
    }

    private func saveChanges() {
        // Validate minimal risky fields
        if !targetDays.isEmpty {
            let td = Int(targetDays) ?? 0
            showTargetDaysError = !(1...365).contains(td)
            if showTargetDaysError { return }
        }

        guard let userId = authService.currentUser?.uid else { return }
        let profile: UserProfile
        if let existing = userProfile { profile = existing } else { profile = UserProfile(userId: userId); modelContext.insert(profile) }

        // Parse numbers softly: empty strings mean keep nil
        let heightDouble = Double(heightValue)
        let weightDouble = Double(weightValue)
        let ageInt = Int(ageValue)
        let caloriesInt = Int(dailyCalories)
        let proteinInt = Int(dailyProtein)
        let targetLossDouble = Double(targetWeightLoss)
        let targetDaysInt = Int(targetDays)

        profile.updateProfile(
            heightValue: heightValue.isEmpty ? nil : heightDouble,
            heightUnit: heightUnit,
            weightValue: weightValue.isEmpty ? nil : weightDouble,
            weightUnit: weightUnit,
            age: ageValue.isEmpty ? nil : ageInt,
            genderCode: genderCode,
            lifestyleCode: lifestyleCode,
            goalCode: goalCode,
            dailyCalories: dailyCalories.isEmpty ? nil : caloriesInt,
            dailyProtein: dailyProtein.isEmpty ? nil : proteinInt,
            targetWeightLossValue: targetWeightLoss.isEmpty ? nil : targetLossDouble,
            targetWeightLossUnit: targetWeightLossUnit,
            targetDays: targetDays.isEmpty ? nil : targetDaysInt
        )

        // If goal changed and was set, reset start date to now
        if let newGoal = goalCode, newGoal != profile.goal {
            profile.goalStartDate = Date()
        }

        do { try modelContext.save() } catch { print("Save error: \(error.localizedDescription)") }

        DatabaseService.shared.saveUserProfile(profile) { _ in }

        dismiss()
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
        .modelContainer(for: [UserProfile.self, DailyCompletion.self])
}


