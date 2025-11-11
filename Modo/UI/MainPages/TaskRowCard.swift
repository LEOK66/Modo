import SwiftUI

/// Task row card component that displays a single task
/// Handles task display, completion state, and visual feedback
struct TaskRowCard: View {
    let title: String
    let subtitle: String
    let time: String
    let endTime: String?
    let meta: String
    @Binding var isDone: Bool
    let emphasis: Color
    let category: TaskCategory
    let isAIGenerated: Bool
    let isDailyChallenge: Bool
    let isFutureDate: Bool
    @State private var checkboxScale: CGFloat = 1.0
    @State private var strikethroughProgress: CGFloat = 0.0

    init(title: String, subtitle: String, time: String, endTime: String?, meta: String, isDone: Binding<Bool>, emphasis: Color, category: TaskCategory, isAIGenerated: Bool = false, isDailyChallenge: Bool = false, isFutureDate: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.endTime = endTime
        self.meta = meta
        self._isDone = isDone
        self.emphasis = emphasis
        self.category = category
        self.isAIGenerated = isAIGenerated
        self.isDailyChallenge = isDailyChallenge
        self.isFutureDate = isFutureDate
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox button - only show for non-future dates
            if !isFutureDate {
                Button {
                    let willBeDone = !isDone
                    
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        isDone.toggle()
                        triggerCompletionHaptic()
                    }
                    // Checkbox bounce animation
                    withAnimation(.easeOut(duration: 0.15)) {
                        checkboxScale = 1.3
                    }
                    withAnimation(.easeIn(duration: 0.15).delay(0.15)) {
                        checkboxScale = 1.0
                    }
                    // Strikethrough animation
                    if willBeDone {
                        withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
                            strikethroughProgress = 1.0
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            strikethroughProgress = 0.0
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isDone ? emphasis : Color.white)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: isDone ? 0 : 1)
                            )
                            .scaleEffect(checkboxScale)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(checkboxScale)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDone ? emphasis : Color(hexString: "101828"))
                            
                            // Animated strikethrough line
                            if strikethroughProgress > 0 {
                                Path { path in
                                    let y = geometry.size.height / 2
                                    let startX: CGFloat = 0
                                    let endX = geometry.size.width * strikethroughProgress
                                    path.move(to: CGPoint(x: startX, y: y))
                                    path.addLine(to: CGPoint(x: endX, y: y))
                                }
                                .stroke(
                                    emphasis,
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        lineCap: .round
                                    )
                                )
                                .animation(.none, value: strikethroughProgress)
                            }
                        }
                    }
                    .frame(height: 20) // Fixed height for GeometryReader
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    // Time display - hide for daily challenge tasks
                    if !isDailyChallenge {
                        if let endTime = endTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text("\(time) - \(endTime)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color(hexString: "364153"))
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text(time)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color(hexString: "364153"))
                        }
                    }
                    
                    // Daily Challenge badge if task is a daily challenge
                    if isDailyChallenge {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Challenge")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hexString: "F59E0B"), Color(hexString: "EAB308")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                    // AI badge if task is AI generated (and not a daily challenge)
                    else if isAIGenerated {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                            Text("AI")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hexString: AppColors.primaryPurple), Color(hexString: AppColors.secondaryIndigo)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                }
            }
            Spacer(minLength: 0)
            
            // Meta information (calories and exercises for fitness, calories for diet)
            if !meta.isEmpty {
                if category == .fitness {
                    // For fitness tasks, show calories and exercises count in 2 lines
                    VStack(alignment: .trailing, spacing: 4) {
                        // Extract calories from meta (format: "XX min • Y exercises • -ZZZ cal")
                        if let calMatch = meta.range(of: #"-?\d+\s*cal"#, options: .regularExpression) {
                            Text(meta[calMatch].replacingOccurrences(of: " ", with: ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(emphasis)
                        }
                        // Extract exercises count
                        if let exMatch = meta.range(of: #"\d+\s*exercises?"#, options: .regularExpression) {
                            Text(meta[exMatch])
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                    }
                } else {
                    // For diet and other tasks, show meta as is
                    Text(meta)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(emphasis)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDone ? emphasis.opacity(0.25) : Color(hexString: "E5E7EB"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Ensure strikethrough reflects current isDone when view (re)appears or external updates arrive
        .onAppear {
            strikethroughProgress = isDone ? 1.0 : 0.0
        }
        .onChange(of: isDone) { _, newValue in
            // Keep progress in sync if completion state changes from outside (e.g., listener)
            strikethroughProgress = newValue ? 1.0 : 0.0
        }
    }
    
    private func triggerCompletionHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

