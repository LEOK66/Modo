import SwiftUI

struct StatsCardView: View {
    let progressPercent: Double
    let daysCompletedText: String
    let expectedCaloriesText: String
    let currentlyCaloriesText: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(daysCompletedText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 66, alignment: .leading)
            .padding(.leading, 8)

            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 8)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progressPercent)
                    .stroke(Color(hexString: "22C55E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.easeInOut(duration: 0.5), value: progressPercent)
                Text("\(Int(progressPercent * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 56, height: 88)
            .padding(.horizontal, 0)

            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1, height: 64)
                .padding(.horizontal, 12)

            VStack(alignment: .center, spacing: 10) {
                Text("Calories")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("Expected")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text(expectedCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 65)
                    Divider().frame(width: 1, height: 22).padding(.horizontal, 6)
                    VStack(alignment: .center, spacing: 2) {
                        Text("Currently")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text(currentlyCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 65)
                }
            }
            .padding(.horizontal, 6)
            .padding(.trailing, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.04), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        )
        .frame(width: 327, height: 124)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

