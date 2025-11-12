import SwiftUI

struct DailyChallengeDetailView: View {
    @ObservedObject var viewModel: DailyChallengeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Challenge header with icon
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(viewModel.isCompleted ? Color(hexString: "DCFCE7") : Color(hexString: "EDE9FE"))
                                .frame(width: 80, height: 80)
                            
                            if viewModel.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hexString: "22C55E"))
                            } else {
                                Text(viewModel.challenge?.emoji ?? "👟")
                                    .font(.system(size: 40))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Challenge")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            if viewModel.isCompleted {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "22C55E"))
                                    Text("Completed")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "22C55E"))
                                }
                            } else if viewModel.isAddedToTasks {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                    Text("Added to Tasks")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                }
                            }
                        }
                        
                        Spacer()
                        if !viewModel.isAddedToTasks && !viewModel.isCompleted {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Add")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                viewModel.addToTasks { taskId in
                                    guard let taskId = taskId,
                                          let challenge = viewModel.challenge else {
                                        dismiss()
                                        return
                                    }
                                    
                                    // Post notification to MainPageView to create task
                                    let userInfo: [String: Any] = [
                                        "taskId": taskId.uuidString,
                                        "title": challenge.title,
                                        "subtitle": challenge.subtitle,
                                        "emoji": challenge.emoji,
                                        "category": "fitness",
                                        "type": challenge.type.rawValue,
                                        "targetValue": challenge.targetValue
                                    ]
                                    
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("AddDailyChallengeTask"),
                                        object: nil,
                                        userInfo: userInfo
                                    )
                                    
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Challenge details
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challenge")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            Text(viewModel.challenge?.title ?? "Loading...")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hexString: "111827"))
                        }
                        
                        // Subtitle/Description
                        if let subtitle = viewModel.challenge?.subtitle, !subtitle.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hexString: "6B7280"))
                                
                                Text(subtitle)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hexString: "374151"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Challenge type and target
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            HStack(spacing: 16) {
                                // Type badge
                                HStack(spacing: 8) {
                                    Image(systemName: typeIcon)
                                        .font(.system(size: 14))
                                        .foregroundColor(typeColor)
                                    
                                    Text(typeText)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hexString: "374151"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(typeColor.opacity(0.1))
                                )
                                
                                // Target value
                                if let targetValue = viewModel.challenge?.targetValue, targetValue > 0 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "target")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hexString: "8B5CF6"))
                                        
                                        Text("\(targetValue) \(targetUnit)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hexString: "374151"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hexString: "8B5CF6").opacity(0.1))
                                    )
                                }
                            }
                        }
                        
                        // Estimated impact (calories/duration) — uses same logic as when adding to main page
                        if let impact = estimatedImpact {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Estimated Impact")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hexString: "6B7280"))
                                
                                HStack(spacing: 12) {
                                    if impact.calories != nil {
                                        HStack(spacing: 6) {
                                            Image(systemName: impact.isDiet ? "plus.circle.fill" : "minus.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(impact.isDiet ? Color(hexString: "10B981") : Color(hexString: "EF4444"))
                                            Text("\(impact.isDiet ? "+" : "-")\(impact.calories!) cal")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hexString: "374151"))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill((impact.isDiet ? Color(hexString: "10B981") : Color(hexString: "EF4444")).opacity(0.1))
                                        )
                                    }
                                    
                                    if let minutes = impact.durationMinutes, minutes > 0 {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hexString: "8B5CF6"))
                                            Text("\(minutes) min")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hexString: "374151"))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hexString: "8B5CF6").opacity(0.1))
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Tips section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hexString: "F59E0B"))
                                
                                Text("Tips")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hexString: "6B7280"))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TipRow(icon: "checkmark.circle", text: "Complete this challenge to earn bonus points")
                                TipRow(icon: "star.fill", text: "Track your progress in the main tasks view")
                                TipRow(icon: "trophy.fill", text: "Daily challenges help build healthy habits")
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hexString: "FFFBEB"))
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(hexString: "F9FAFB"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hexString: "6B7280"))
                    }
                }
            }
        }
    }
    
    private var typeText: String {
        switch viewModel.challenge?.type {
        case .fitness: return "Fitness"
        case .diet: return "Nutrition"
        case .mindfulness: return "Mindfulness"
        case .other, .none: return "Challenge"
        }
    }
    
    private var typeIcon: String {
        switch viewModel.challenge?.type {
        case .fitness: return "figure.run"
        case .diet: return "leaf.fill"
        case .mindfulness: return "brain.head.profile"
        case .other, .none: return "star.fill"
        }
    }
    
    private var typeColor: Color {
        switch viewModel.challenge?.type {
        case .fitness: return Color(hexString: "8B5CF6")
        case .diet: return Color(hexString: "22C55E")
        case .mindfulness: return Color(hexString: "3B82F6")
        case .other, .none: return Color(hexString: "F59E0B")
        }
    }
    
    private var targetUnit: String {
        guard let challenge = viewModel.challenge else { return "" }
        switch challenge.type {
        case .diet:
            // Try to infer serving unit from title
            return extractServingUnit(from: challenge.title)
        case .fitness:
            let lower = challenge.title.lowercased()
            if lower.contains("minute") || lower.contains("min") { return "min" }
            if lower.contains("km") { return "km" }
            if lower.contains("mile") { return "miles" }
            if lower.contains("step") { return "steps" }
            return ""
        case .mindfulness:
            return "min"
        case .other:
            return ""
        }
    }
    
    // MARK: - Impact estimation helpers (mirrors logic used when adding to main page)
    private var estimatedImpact: (isDiet: Bool, calories: Int?, durationMinutes: Int?)? {
        guard let challenge = viewModel.challenge else { return nil }
        switch challenge.type {
        case .diet:
            let calories = estimateDietCalories(from: challenge.title, targetValue: challenge.targetValue)
            return (true, calories, nil)
        case .fitness:
            let (_, calories, minutes) = parseActivityChallenge(title: challenge.title, targetValue: challenge.targetValue)
            return (false, calories, minutes)
        case .mindfulness, .other:
            return nil
        }
    }
    
    private func parseActivityChallenge(title: String, targetValue: Int) -> (String, Int, Int) {
        let titleLower = title.lowercased()
        if titleLower.contains("step") {
            let activityName = "Walking"
            let caloriesBurned = Int(Double(targetValue) * 0.04)
            let durationMinutes = max(15, min(180, targetValue / 100))
            return (activityName, caloriesBurned, durationMinutes)
        }
        if titleLower.contains("minute") || titleLower.contains("min") {
            let activityName = extractActivityName(from: title)
            let durationMinutes = targetValue
            let caloriesBurned = targetValue * 7
            return (activityName, caloriesBurned, durationMinutes)
        }
        if titleLower.contains("rep") || titleLower.contains("set") ||
           titleLower.contains("push") || titleLower.contains("squat") ||
           titleLower.contains("plank") {
            let activityName = extractActivityName(from: title)
            let caloriesBurned = max(50, targetValue * 2)
            let durationMinutes = max(10, min(60, targetValue / 2))
            return (activityName, caloriesBurned, durationMinutes)
        }
        if titleLower.contains("km") || titleLower.contains("mile") {
            let activityName = extractActivityName(from: title)
            let caloriesBurned = titleLower.contains("km") ? targetValue * 100 : targetValue * 160
            let durationMinutes = titleLower.contains("km") ? targetValue * 6 : targetValue * 10
            return (activityName, caloriesBurned, durationMinutes)
        }
        let activityName = extractActivityName(from: title)
        let caloriesBurned = max(200, min(600, targetValue * 3))
        let durationMinutes = max(20, min(60, 45))
        return (activityName, caloriesBurned, durationMinutes)
    }
    
    private func extractActivityName(from title: String) -> String {
        let titleLower = title.lowercased()
        if titleLower.contains("walk") || titleLower.contains("step") { return "Walking" }
        if titleLower.contains("run") || titleLower.contains("jog") { return "Running" }
        if titleLower.contains("swim") { return "Swimming" }
        if titleLower.contains("bike") || titleLower.contains("cycl") { return "Cycling" }
        if titleLower.contains("yoga") { return "Yoga" }
        if titleLower.contains("push") { return "Push-ups" }
        if titleLower.contains("squat") { return "Squats" }
        if titleLower.contains("plank") { return "Plank" }
        if titleLower.contains("strength") || titleLower.contains("weight") { return "Strength Training" }
        if titleLower.contains("cardio") { return "Cardio" }
        if titleLower.contains("hiit") { return "HIIT" }
        let cleaned = title
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\\d+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "steps", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "minutes", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "reps", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "sets", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Exercise" : cleaned.capitalized
    }
    
    private func estimateDietCalories(from title: String, targetValue: Int) -> Int {
        let titleLower = title.lowercased()
        if titleLower.contains("water") || titleLower.contains("glass") { return 0 }
        if titleLower.contains("protein") && titleLower.contains("gram") { return targetValue * 4 }
        if titleLower.contains("vegeta") || titleLower.contains("salad") { return targetValue * 30 }
        if titleLower.contains("fruit") { return targetValue * 60 }
        return targetValue * 50
    }
    
    private func extractServingUnit(from title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("glass") { return "glasses" }
        if lower.contains("gram") { return "grams" }
        if lower.contains("serving") { return "servings" }
        if lower.contains("cup") { return "cups" }
        return "units"
    }
}

// MARK: - Tip Row Component

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "F59E0B"))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "374151"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

