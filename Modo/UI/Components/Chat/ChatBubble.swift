import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var onAccept: ((ChatMessage) -> Void)?
    var onReject: ((ChatMessage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer()
                userMessageView
            } else {
                aiAvatarView
                aiMessageView
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // MARK: - AI Avatar
    private var aiAvatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - User Message
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "1F2937"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hexString: "DDD6FE"))
                    .cornerRadius(20)
                    .frame(maxWidth: 260, alignment: .trailing)
                
                // User avatar placeholder
                Circle()
                    .fill(Color(hexString: "8B5CF6").opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hexString: "8B5CF6"))
                    )
            }
            
            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "9CA3AF"))
                .padding(.trailing, 44)
        }
    }
    
    // MARK: - AI Message
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.messageType == "workout_plan", let plan = message.workoutPlan {
                workoutPlanView(plan)
            } else {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "1F2937"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hexString: "F3F4F6"))
                    .cornerRadius(20)
                    .frame(maxWidth: 260, alignment: .leading)
            }
            
            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "9CA3AF"))
                .padding(.leading, 4)
        }
    }
    
    // MARK: - Workout Plan View
    private func workoutPlanView(_ plan: WorkoutPlanData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message.content)
                .font(.system(size: 16))
                .foregroundColor(Color(hexString: "1F2937"))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.exercises) { exercise in
                    HStack(spacing: 4) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                        Text("\(exercise.sets)×\(exercise.reps) \(exercise.name)")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(Color(hexString: "374151"))
                }
            }
            
            if let notes = plan.notes {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6B7280"))
                    .italic()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    onReject?(message)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hexString: "EF4444"))
                        .frame(width: 44, height: 44)
                }
                
                Button(action: {
                    onAccept?(message)
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hexString: "10B981"))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(hexString: "F3F4F6"))
        .cornerRadius(20)
        .frame(maxWidth: 280, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ChatBubble(message: ChatMessage(
            content: "Hi! I'm your MODO wellness assistant. I can help you with diet planning, fitness routines, and healthy lifestyle tips. What would you like to know?",
            isFromUser: false
        ))
        
        ChatBubble(message: ChatMessage(
            content: "add a work out plan for tomorrow.",
            isFromUser: true
        ))
        
        ChatBubble(message: ChatMessage(
            content: "Here's your workout plan for tomorrow 💪:",
            isFromUser: false,
            messageType: "workout_plan",
            workoutPlan: WorkoutPlanData(
                date: "2025-10-31",
                goal: "muscle_gain",
                dailyKcalTarget: 2700,
                exercises: [
                    WorkoutPlanData.Exercise(name: "Squats", sets: 3, reps: "10", restSec: 90),
                    WorkoutPlanData.Exercise(name: "Push-ups", sets: 3, reps: "8", restSec: 60),
                    WorkoutPlanData.Exercise(name: "Dumbbell Rows", sets: 3, reps: "12", restSec: 90),
                    WorkoutPlanData.Exercise(name: "Brisk walk or light jog", sets: 1, reps: "15 min", restSec: nil)
                ],
                notes: "Sounds good?"
            )
        ))
    }
    .background(Color.white)
}

