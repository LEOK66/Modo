import Foundation
import SwiftUI
import UIKit
import PDFKit
import SwiftData

/// Service for generating health report PDF exports
final class PDFExportService {
    static let shared = PDFExportService()
    
    private init() {}
    
    /// Data model for health report
    struct HealthReportData {
        let userProfile: UserProfile
        let profileMetrics: ProfileMetrics
        let nutritionRecommendations: NutritionRecommendations
        let goalProgress: GoalProgress
        
        struct ProfileMetrics {
            let height: String
            let weight: String
            let age: String
        }
        
        struct NutritionRecommendations {
            let protein: String
            let fat: String
            let carbohydrates: String
        }
        
        struct GoalProgress {
            let description: String
            let completedDays: Int
            let targetDays: Int
            let percentage: Double
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate health report PDF (simplified - only ProgressView data)
    /// - Parameters:
    ///   - userId: User ID
    ///   - userProfile: User profile
    ///   - progressViewModel: Progress view model for calculations
    ///   - completion: Completion handler with PDF file URL or error
    func generateHealthReport(
        userId: String,
        userProfile: UserProfile,
        progressViewModel: ProgressViewModel,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Build report data directly from profile and progress view model
        let reportData = buildReportData(
            profile: userProfile,
            progressViewModel: progressViewModel
        )
        
        // Generate PDF from data
        generatePDF(from: reportData) { pdfResult in
            completion(pdfResult)
        }
    }
    
    // MARK: - Private Methods - Data Building
    
    /// Build health report data from profile and progress view model (simplified - only ProgressView data)
    private func buildReportData(
        profile: UserProfile,
        progressViewModel: ProgressViewModel
    ) -> HealthReportData {
        // Build profile metrics
        let profileMetrics = HealthReportData.ProfileMetrics(
            height: formatMetric(profile.heightValue, unit: profile.heightUnit ?? "cm"),
            weight: formatMetric(profile.weightValue, unit: profile.weightUnit ?? "kg"),
            age: profile.age.map { "\($0) years" } ?? "-"
        )
        
        // Build nutrition recommendations (calculate directly from profile)
        let nutritionData = calculateNutritionRecommendations(profile: profile)
        let nutritionRecommendations = HealthReportData.NutritionRecommendations(
            protein: nutritionData.protein,
            fat: nutritionData.fat,
            carbohydrates: nutritionData.carbohydrates
        )
        
        // Build goal progress (from ProgressViewModel)
        let goalDescription = progressViewModel.goalDescriptionText
        let completedDays = progressViewModel.progressData.completedDays
        let targetDays = progressViewModel.progressData.targetDays
        let percentage = targetDays > 0 ? Double(completedDays) / Double(targetDays) : 0.0
        
        let goalProgress = HealthReportData.GoalProgress(
            description: goalDescription,
            completedDays: completedDays,
            targetDays: targetDays,
            percentage: percentage
        )
        
        return HealthReportData(
            userProfile: profile,
            profileMetrics: profileMetrics,
            nutritionRecommendations: nutritionRecommendations,
            goalProgress: goalProgress
        )
    }
    
    // MARK: - Helper Methods - Calculations
    
    /// Calculate nutrition recommendations from profile
    private func calculateNutritionRecommendations(profile: UserProfile) -> (protein: String, fat: String, carbohydrates: String) {
        // For gain_muscle goal, use weight-based protein recommendation
        if profile.goal == "gain_muscle" {
            guard let weightValue = profile.weightValue,
                  let weightUnit = profile.weightUnit else {
                return ("-", "-", "-")
            }
            let weightKg = HealthCalculator.convertWeightToKg(weightValue, unit: weightUnit)
            let protein = HealthCalculator.recommendedProtein(weightKg: weightKg)
            return ("\(protein)g", "-", "-")
        }
        
        // Calculate macros from calories
        guard let macros = calculateMacros(profile: profile) else {
            return ("-", "-", "-")
        }
        
        return ("\(macros.protein)g", "\(macros.fat)g", "\(macros.carbohydrates)g")
    }
    
    /// Calculate macronutrients from profile
    private func calculateMacros(profile: UserProfile) -> HealthCalculator.Macronutrients? {
        let weightKg: Double? = {
            guard let value = profile.weightValue, let unit = profile.weightUnit else { return nil }
            return HealthCalculator.convertWeightToKg(value, unit: unit)
        }()
        
        let heightCm: Double? = {
            guard let value = profile.heightValue, let unit = profile.heightUnit else { return nil }
            return HealthCalculator.convertHeightToCm(value, unit: unit)
        }()
        
        guard let goal = profile.goal, !goal.isEmpty else { return nil }
        
        guard let totalCalories = HealthCalculator.targetCalories(
            goal: goal,
            age: profile.age,
            genderCode: profile.gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: profile.lifestyle,
            userInputCalories: profile.dailyCalories
        ) else {
            return nil
        }
        
        return HealthCalculator.recommendedMacros(goal: goal, totalCalories: totalCalories)
    }
    
    /// Format metric value with unit
    private func formatMetric(_ value: Double?, unit: String) -> String {
        guard let value = value else { return "-" }
        return "\(Int(value)) \(unit)"
    }
    
    // MARK: - Private Methods - PDF Generation
    
    /// Generate PDF from health report data
    private func generatePDF(
        from data: HealthReportData,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            // Create PDF view
            let pdfView = HealthReportPDFView(data: data)
            
            // Render SwiftUI view to image first
            let imageRenderer = ImageRenderer(content: pdfView)
            imageRenderer.scale = 1.0 // Use 1.0 scale to match PDF points (72 DPI)
            
            // Create PDF document
            let pdfMetaData = [
                kCGPDFContextCreator: "Modor App",
                kCGPDFContextAuthor: data.userProfile.username ?? "User",
                kCGPDFContextTitle: "Health Report"
            ]
            
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = pdfMetaData as [String: Any]
            
            // Page size (A4 equivalent in points)
            let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
            let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
            
            // Generate filename with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let filename = "Modor_Health_Report_\(dateFormatter.string(from: Date())).pdf"
            
            // Save to temporary directory
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            do {
                try pdfRenderer.writePDF(to: tempURL) { context in
                    // Render SwiftUI view to image
                    guard let image = imageRenderer.uiImage else {
                        return
                    }
                    
                    // Calculate proper sizing - keep aspect ratio and fit to page width
                    let pageWidth = pageRect.width
                    let pageHeight = pageRect.height
                    let imageAspectRatio = image.size.height / image.size.width
                    
                    // Scale image to fit page width, maintaining aspect ratio
                    let scaledWidth = pageWidth
                    let scaledHeight = scaledWidth * imageAspectRatio
                    
                    // If content fits on one page, draw it centered
                    if scaledHeight <= pageHeight {
                        context.beginPage()
                        
                        let xOffset: CGFloat = 0
                        let yOffset: CGFloat = (pageHeight - scaledHeight) / 2
                        
                        let imageRect = CGRect(
                            x: xOffset,
                            y: yOffset,
                            width: scaledWidth,
                            height: scaledHeight
                        )
                        
                        image.draw(in: imageRect)
                    } else {
                        // Content exceeds one page - split into multiple pages
                        let totalPages = Int(ceil(scaledHeight / pageHeight))
                        let imageWidth = image.size.width
                        let imageHeight = image.size.height
                        
                        for pageIndex in 0..<totalPages {
                            context.beginPage()
                            
                            let sourceY = CGFloat(pageIndex) * pageHeight
                            let sourceHeight = min(pageHeight, scaledHeight - sourceY)
                            
                            // Calculate source rect in image coordinates
                            let sourceRect = CGRect(
                                x: 0,
                                y: (sourceY / scaledHeight) * imageHeight,
                                width: imageWidth,
                                height: (sourceHeight / scaledHeight) * imageHeight
                            )
                            
                            // Draw the cropped portion
                            let destinationRect = CGRect(
                                x: 0,
                                y: 0,
                                width: scaledWidth,
                                height: sourceHeight
                            )
                            
                            if let cgImage = image.cgImage,
                               let croppedImage = cgImage.cropping(to: sourceRect) {
                                let pageImage = UIImage(cgImage: croppedImage, scale: image.scale, orientation: image.imageOrientation)
                                pageImage.draw(in: destinationRect)
                            }
                        }
                    }
                }
                
                completion(.success(tempURL))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

