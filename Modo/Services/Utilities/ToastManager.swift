import Foundation
import Combine
import SwiftUI

/// Manages toast message display with automatic dismissal
/// Uses the existing ToastType from Toast.swift
@MainActor
class ToastManager: ObservableObject {
    @Published var message: String = ""
    @Published var isPresented: Bool = false
    @Published var type: ToastType = .error
    
    private var dismissTask: Task<Void, Never>?
    
    /// Shows a toast message with automatic dismissal after the specified duration
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of toast (error or success)
    ///   - duration: Duration in seconds before auto-dismiss (default: 3.0)
    func show(message: String, type: ToastType = .error, duration: Double = 3.0) {
        // Cancel existing dismiss task
        dismissTask?.cancel()
        
        self.message = message
        self.type = type
        self.isPresented = true
        
        // Auto-dismiss after duration
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await hide()
            }
        }
    }
    
    /// Shows an error toast
    func showError(_ message: String, duration: Double = 3.0) {
        show(message: message, type: .error, duration: duration)
    }
    
    /// Shows a success toast
    func showSuccess(_ message: String, duration: Double = 3.0) {
        show(message: message, type: .success, duration: duration)
    }
    
    /// Manually hides the toast
    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation {
            isPresented = false
        }
    }
    
    deinit {
        dismissTask?.cancel()
    }
}

