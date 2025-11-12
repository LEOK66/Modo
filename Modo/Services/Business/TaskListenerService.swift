import Foundation
import FirebaseAuth
import FirebaseDatabase

/// Service for managing Firebase real-time listeners for tasks
class TaskListenerService {
    private let databaseService: DatabaseServiceProtocol
    private let cacheService: TaskCacheService
    
    /// Initialize with dependencies
    /// - Parameters:
    ///   - databaseService: Database service for Firebase operations (defaults to shared instance)
    ///   - cacheService: Cache service for local storage (defaults to shared instance)
    init(databaseService: DatabaseServiceProtocol = DatabaseService.shared, cacheService: TaskCacheService = TaskCacheService.shared) {
        self.databaseService = databaseService
        self.cacheService = cacheService
    }
    
    private var currentListenerHandle: DatabaseHandle?
    private var currentListenerDate: Date?
    private var isListenerActive = false
    private var listenerUpdateTask: Task<Void, Never>?
    
    /// Setup listener for a specific date
    func setupListener(
        for date: Date,
        userId: String,
        isViewVisible: Bool,
        onUpdate: @escaping ([TaskItem]) -> Void
    ) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if already listening to this date
        if let currentDate = currentListenerDate,
           calendar.isDate(currentDate, inSameDayAs: normalizedDate),
           isListenerActive {
            print("✅ TaskListenerService: Already listening to \(normalizedDate), skipping setup")
            return
        }
        
        // Stop any existing listener first
        stopListener()
        
        guard isViewVisible else {
            print("⚠️ TaskListenerService: View not visible, skipping listener setup")
            return
        }
        
        print("🔌 TaskListenerService: Setting up listener for \(normalizedDate)")
        
        // Capture the expected date to validate callbacks
        let expectedDate = normalizedDate
        
        let handle = databaseService.listenToTasks(userId: userId, date: normalizedDate) { tasks in
            // Only process updates if listener is active
            guard self.isListenerActive else {
                print("⚠️ TaskListenerService: Ignoring listener update - listener inactive")
                return
            }
            
            // Ensure this callback corresponds to the current listener/date
            let cal = Calendar.current
            guard let currentDate = self.currentListenerDate,
                  cal.isDate(currentDate, inSameDayAs: expectedDate) else {
                print("⚠️ TaskListenerService: Listener callback for stale date, ignoring")
                return
            }
            
            // Debounce rapid updates
            self.listenerUpdateTask?.cancel()
            self.listenerUpdateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
                guard !Task.isCancelled else { return }
                self.handleListenerUpdate(tasks: tasks, date: expectedDate, userId: userId, onUpdate: onUpdate)
            }
        }
        
        if let handle = handle {
            currentListenerHandle = handle
            currentListenerDate = normalizedDate
            isListenerActive = true
            print("✅ TaskListenerService: Listener active for \(normalizedDate)")
        }
    }
    
    /// Handle listener update
    private func handleListenerUpdate(
        tasks: [TaskItem],
        date: Date,
        userId: String,
        onUpdate: @escaping ([TaskItem]) -> Void
    ) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        print("🔄 TaskListenerService: Real-time update received for \(date) - \(tasks.count) tasks")
        
        // Update cache without triggering additional Firebase operations
        Task.detached(priority: .background) {
            self.cacheService.saveTasksForDate(tasks, date: normalizedDate, userId: userId)
        }
        
        // Call update callback on main thread
        DispatchQueue.main.async {
            onUpdate(tasks)
        }
    }
    
    /// Stop current listener
    func stopListener() {
        // Cancel any pending updates
        listenerUpdateTask?.cancel()
        listenerUpdateTask = nil
        
        // Stop Firebase listener
        if let handle = currentListenerHandle {
            databaseService.stopListening(handle: handle)
            print("🛑 TaskListenerService: Stopped listener for \(currentListenerDate?.description ?? "unknown")")
        }
        
        // Clear state
        currentListenerHandle = nil
        currentListenerDate = nil
        isListenerActive = false
    }
    
    /// Check if listener is active for a specific date
    func isListening(to date: Date) -> Bool {
        guard let currentDate = currentListenerDate,
              isListenerActive else {
            return false
        }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        return calendar.isDate(currentDate, inSameDayAs: normalizedDate)
    }
}

