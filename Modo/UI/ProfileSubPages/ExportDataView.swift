import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// View for exporting health report as PDF
struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var viewModel = ExportDataViewModel()
    
    // Get current user's profile
    @Query private var profiles: [UserProfile]
    private var userProfile: UserProfile? {
        guard let userId = authService.currentUser?.uid else { return nil }
        return profiles.first { $0.userId == userId }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Export Data")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generate a health report PDF containing your body metrics, nutrition recommendations, and goal progress.")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        
                        // Export Button
                        exportButton
                        
                        // Status Display
                        if viewModel.isExporting {
                            exportProgressView
                        }
                        
                        if let errorMessage = viewModel.errorMessage {
                            errorView(errorMessage)
                        }
                        
                        if let pdfURL = viewModel.pdfURL {
                            successView(pdfURL)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.setup(
                userId: authService.currentUser?.uid ?? "",
                modelContext: modelContext,
                userProfile: userProfile,
                authService: authService
            )
        }
        .onChange(of: userProfile) { oldValue, newValue in
            if let profile = newValue {
                viewModel.updateUserProfile(profile)
            }
        }
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button {
            viewModel.exportHealthReport()
        } label: {
            HStack {
                if viewModel.isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 18))
                }
                
                Text(viewModel.isExporting ? "Generating Report..." : "Generate Health Report")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.canExport ? Color(hexString: "7C3AED") : Color.gray)
            .cornerRadius(16)
        }
        .disabled(!viewModel.canExport || viewModel.isExporting)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Export Progress View
    private var exportProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: viewModel.exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hexString: "7C3AED")))
                .frame(height: 4)
            
            if let statusText = viewModel.statusText {
                Text(statusText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Export Failed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Success View
    @available(iOS 16.0, *)
    @ViewBuilder
    private func shareLinkView(pdfURL: URL) -> some View {
        // Try to load app icon from Assets
        if let appIcon = loadAppIcon() {
            // Use custom app icon with SharePreview image parameter
            ShareLink(
                item: pdfURL,
                preview: SharePreview("Health Report", image: Image(uiImage: appIcon))
            ) {
                shareButtonLabel
            }
        } else {
            // Fallback: Use system icon with SharePreview icon parameter
            ShareLink(
                item: pdfURL,
                preview: SharePreview("Health Report", icon: "doc.text.fill")
            ) {
                shareButtonLabel
            }
        }
    }
    
    private var shareButtonLabel: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
            Text("Share Report")
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color(hexString: "7C3AED"))
        .cornerRadius(16)
    }
    
    /// Load app icon from Assets
    private func loadAppIcon() -> UIImage? {
        // Try to load from Asset Catalog
        if let icon = UIImage(named: "AppIcon") {
            return icon
        }
        
        // Try loading appstore icon file directly
        if let iconPath = Bundle.main.path(forResource: "appstore", ofType: "png", inDirectory: nil),
           let icon = UIImage(contentsOfFile: iconPath) {
            return icon
        }
        
        // Try to get from bundle's icon files
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
            for iconName in iconFiles.reversed() {
                if let icon = UIImage(named: iconName) {
                    return icon
                }
            }
        }
        
        return nil
    }
    
    private func successView(_ pdfURL: URL) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hexString: "22C55E"))
            
            Text("Report Ready!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Your health report has been generated successfully.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Share Link (iOS 16+)
            if #available(iOS 16.0, *) {
                shareLinkView(pdfURL: pdfURL)
                    .padding(.horizontal, 24)
            } else {
                // Fallback for iOS 15
                Button {
                    viewModel.sharePDF(url: pdfURL)
                } label: {
                    shareButtonLabel
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
}

// MARK: - Export Data ViewModel
@MainActor
final class ExportDataViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var statusText: String?
    @Published var pdfURL: URL?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var userId: String = ""
    private var modelContext: ModelContext?
    private var userProfile: UserProfile?
    private weak var authService: AuthService?
    private let pdfExportService = PDFExportService.shared
    private let databaseService: DatabaseServiceProtocol = DatabaseService.shared
    
    // MARK: - Computed Properties
    var canExport: Bool {
        !userId.isEmpty && userProfile != nil
    }
    
    // MARK: - Setup Methods
    func setup(
        userId: String,
        modelContext: ModelContext,
        userProfile: UserProfile?,
        authService: AuthService
    ) {
        self.userId = userId
        self.modelContext = modelContext
        self.userProfile = userProfile
        self.authService = authService
    }
    
    func updateUserProfile(_ profile: UserProfile?) {
        self.userProfile = profile
    }
    
    // MARK: - Export Methods
    func exportHealthReport() {
        guard canExport,
              let modelContext = modelContext,
              let profile = userProfile,
              let authService = authService else {
            errorMessage = userProfile == nil 
                ? "User profile not found. Please complete your profile first."
                : "Unable to access required services."
            return
        }
        
        isExporting = true
        exportProgress = 0.0
        statusText = "Preparing data..."
        errorMessage = nil
        pdfURL = nil
        
        exportProgress = 0.3
        statusText = "Generating report..."
        
        // Create and setup progress view model
        let progressViewModel = ProgressViewModel()
        progressViewModel.setup(
            modelContext: modelContext,
            authService: authService,
            userProfile: profile
        )
        
        // Wait for progress data to load, then generate report
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.generateReport(profile: profile, progressViewModel: progressViewModel)
        }
    }
    
    private func generateReport(profile: UserProfile, progressViewModel: ProgressViewModel) {
        exportProgress = 0.5
        statusText = "Creating PDF..."
        
        pdfExportService.generateHealthReport(
            userId: userId,
            userProfile: profile,
            progressViewModel: progressViewModel
        ) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let url):
                    self.exportProgress = 1.0
                    self.statusText = "Complete!"
                    self.pdfURL = url
                    self.errorMessage = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExporting = false
                        self.statusText = nil
                    }
                    
                case .failure(let error):
                    self.isExporting = false
                    self.exportProgress = 0.0
                    self.statusText = nil
                    self.errorMessage = error.localizedDescription
                    self.pdfURL = nil
                }
            }
        }
    }
    
    // MARK: - Share Methods (iOS 15 fallback)
    func sharePDF(url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // For iPad
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                           y: rootViewController.view.bounds.midY,
                                           width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ExportDataView()
            .environmentObject(AuthService.shared)
            .modelContainer(for: [UserProfile.self])
    }
}

