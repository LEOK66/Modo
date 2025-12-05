import SwiftUI
import UIKit

// MARK: - Share Sheet

/// A SwiftUI wrapper for UIActivityViewController to share content
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    var onDismiss: (() -> Void)?
    
    init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        if let excludedTypes = excludedActivityTypes {
            controller.excludedActivityTypes = excludedTypes
        }
        
        // Handle completion
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                onDismiss?()
            }
        }
        
        // For iPad support - set popover presentation
        // Note: The popover source will be set by the presenting view controller
        if let popover = controller.popoverPresentationController {
            // Set a default source rect (will be overridden by the presenting view if needed)
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

