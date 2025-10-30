import SwiftUI

// MARK: - Empty Tasks View Component
struct EmptyTasksView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Empty state icon
            ZStack {
                Circle()
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(Color(hexString: "F3F4F6"))
                    .frame(width: 10, height: 10)
                    .offset(x: 34, y: 6)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 2)
                    )
                    .offset(x: -40, y: 23)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color(hexString: "D1D5DC"), lineWidth: 2)
                    )
                    .offset(x: 22, y: -42)
                
                Circle()
                    .stroke(Color(hexString: "D1D5DC"), lineWidth: 2)
                    .opacity(0.8)
                    .frame(width: 40, height: 40)
            }
            .frame(height: 104)
            
            // Text content
            VStack(spacing: 8) {
                Text("Nothing here yet")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hexString: "0A0A0A"))
                    .tracking(-0.439453)
                
                Text("Your task list is feeling a bit lonely. Let's add some goals to keep it company!")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .tracking(-0.150391)
                    .multilineTextAlignment(.center)
                    .lineSpacing(9)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Preview
#Preview {
    EmptyTasksView()
        .background(Color.white)
}

