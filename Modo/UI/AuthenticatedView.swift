import SwiftUI
import FirebaseAuth

struct AuthenticatedView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let user = authService.currentUser {
                Text("Email: \(user.email ?? "No email")")
                    .font(.body)
            }
            
            Button("Sign Out") {
                do {
                    try authService.signOut()
                } catch {
                    print("Sign out error: \(error.localizedDescription)")
                }
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}
