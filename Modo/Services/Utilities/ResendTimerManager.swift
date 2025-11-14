import Foundation
import Combine

/// Manages resend timer logic for email verification and password reset
@MainActor
class ResendTimerManager: ObservableObject {
    @Published var remainingTime: Int = 0
    @Published var canResend: Bool = true
    
    private var timer: Timer?
    private var duration: Int = 60
    
    /// Starts the timer with the specified duration (default: 60 seconds)
    func start(duration: Int = 60) {
        self.duration = duration
        remainingTime = duration
        canResend = false
        
        // Invalidate existing timer if any
        timer?.invalidate()
        
        // Timer callbacks run on the main run loop, so we can update @Published properties directly
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.canResend = true
                timer.invalidate()
                self.timer = nil
            }
        }
    }
    
    /// Resets the timer to the initial duration
    func reset() {
        start(duration: duration)
    }
    
    /// Stops the timer and resets state
    func stop() {
        timer?.invalidate()
        timer = nil
        remainingTime = 0
        canResend = true
    }
    
    deinit {
        timer?.invalidate()
    }
}

