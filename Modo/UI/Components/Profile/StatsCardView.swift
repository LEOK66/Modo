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
                    .foregroundColor(Color(hexString: "101828"))
                Text(daysCompletedText)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .frame(width: 66, alignment: .leading)
            .padding(.leading, 8)

            ZStack {
                Circle()
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 8)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progressPercent)
                    .stroke(Color(hexString: "22C55E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.easeInOut(duration: 0.5), value: progressPercent)
                Text("\(Int(progressPercent * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hexString: "101828"))
            }
            .frame(width: 56, height: 88)
            .padding(.horizontal, 0)

            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(width: 1, height: 64)
                .padding(.horizontal, 12)

            VStack(alignment: .center, spacing: 10) {
                Text("Calories")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hexString: "101828"))
                HStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("Expected")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .multilineTextAlignment(.center)
                        Text(expectedCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hexString: "101828"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 65)
                    Divider().frame(width: 1, height: 22).padding(.horizontal, 6)
                    VStack(alignment: .center, spacing: 2) {
                        Text("Currently")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .multilineTextAlignment(.center)
                        Text(currentlyCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hexString: "101828"))
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
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                )
        )
        .frame(width: 327, height: 124)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

