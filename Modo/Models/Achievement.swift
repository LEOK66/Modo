import Foundation

// MARK: - Achievement Model
struct Achievement: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let color: String
    let isUnlocked: Bool
    let description: String
    let howToUnlock: String
    
    static let allAchievements: [Achievement] = [
        // Unlocked achievements
        Achievement(name: "First Step", iconName: "figure.walk", color: "#FF6B35", isUnlocked: true, description: "Your journey begins with a single step. Every great achievement starts somewhere.", howToUnlock: "Complete your very first task"),
        Achievement(name: "10-Day Streak", iconName: "flame.fill", color: "#FFD93D", isUnlocked: true, description: "Consistency is key! You've kept the momentum going for 10 days straight.", howToUnlock: "Complete tasks for 10 consecutive days"),
        Achievement(name: "Early Bird", iconName: "sunrise.fill", color: "#F4A261", isUnlocked: true, description: "Rise and shine! You're crushing goals while others are still sleeping.", howToUnlock: "Complete at least 5 tasks before 8:00 AM"),
        Achievement(name: "Week Warrior", iconName: "shield.fill", color: "#9D4EDD", isUnlocked: true, description: "Seven days of dedication. You've proven your commitment to excellence.", howToUnlock: "Complete all scheduled tasks for an entire week"),
        Achievement(name: "Overachiever", iconName: "star.fill", color: "#FFD60A", isUnlocked: true, description: "Going above and beyond! You don't just meet goals—you exceed them.", howToUnlock: "Exceed your daily task goal 5 times"),
        Achievement(name: "Night Owl", iconName: "moon.stars.fill", color: "#5A189A", isUnlocked: true, description: "Burning the midnight oil? You're most productive when the moon is out.", howToUnlock: "Complete at least 5 tasks after 10:00 PM"),
        
        // Locked achievements
        Achievement(name: "30-Day Diamond", iconName: "diamond.fill", color: "#6FCDCD", isUnlocked: false, description: "A rare gem! One month of unwavering dedication is truly remarkable.", howToUnlock: "Maintain a streak for 30 consecutive days"),
        Achievement(name: "Century Club", iconName: "target", color: "#E63946", isUnlocked: false, description: "Welcome to the elite! One hundred tasks completed—you're unstoppable.", howToUnlock: "Complete a total of 100 tasks"),
        Achievement(name: "Fitness Fanatic", iconName: "figure.run", color: "#2A9D8F", isUnlocked: false, description: "Your body is a temple, and you're the architect. Keep building!", howToUnlock: "Complete 50 fitness-related tasks"),
        Achievement(name: "Nutrition Ninja", iconName: "leaf.fill", color: "#52B788", isUnlocked: false, description: "Eating healthy is a lifestyle. You've mastered the art of nutrition.", howToUnlock: "Complete 50 diet/nutrition tasks"),
        Achievement(name: "Progress Pioneer", iconName: "chart.line.uptrend.xyaxis", color: "#4361EE", isUnlocked: false, description: "Data-driven excellence! Tracking your journey leads to success.", howToUnlock: "Log and track your progress for 30 days"),
        Achievement(name: "Iron Will", iconName: "figure.strengthtraining.traditional", color: "#E63946", isUnlocked: false, description: "Strength isn't just physical—it's mental. You've proven both.", howToUnlock: "Complete 100 fitness tasks"),
        Achievement(name: "Modo Master", iconName: "graduationcap.fill", color: "#6A4C93", isUnlocked: false, description: "You've unlocked every feature and mastered the art of productivity.", howToUnlock: "Use all app features and unlock all other achievements"),
        Achievement(name: "Professional Procrastinator", iconName: "bed.double.fill", color: "#8D99AE", isUnlocked: false, description: "Sometimes rest is productive too... or so you tell yourself!", howToUnlock: "Skip logging tasks for 7 days straight"),
        Achievement(name: "Cheat Day Champion", iconName: "birthday.cake.fill", color: "#FF6B35", isUnlocked: false, description: "Balance is everything! You know when to treat yourself.", howToUnlock: "Log 10 cheat meals or treats"),
        Achievement(name: "Snooze Master", iconName: "alarm.fill", color: "#457B9D", isUnlocked: false, description: "Just five more minutes... said 20 times. We've all been there!", howToUnlock: "Postpone or reschedule tasks 20 times"),
        Achievement(name: "The Comeback Kid", iconName: "arrow.uturn.up", color: "#F72585", isUnlocked: false, description: "Life happens, but you came back stronger. That's what matters!", howToUnlock: "Return to the app after 30 days of inactivity"),
        Achievement(name: "Midnight Snacker", iconName: "fork.knife", color: "#D4A373", isUnlocked: false, description: "The kitchen calls to you at midnight. No judgment here!", howToUnlock: "Log 10 meals or snacks after midnight"),
        Achievement(name: "Almost There", iconName: "scope", color: "#E9C46A", isUnlocked: false, description: "So close! 99% is the new 100% in our book.", howToUnlock: "Achieve a 99% task completion rate for a week"),
        Achievement(name: "Weekend Warrior", iconName: "figure.yoga", color: "#06FFA5", isUnlocked: false, description: "Weekends are for warriors! You stay active when others rest.", howToUnlock: "Complete tasks every Saturday and Sunday for 4 weeks"),
        Achievement(name: "Restart Royalty", iconName: "arrow.clockwise", color: "#7209B7", isUnlocked: false, description: "Fresh starts are your specialty. Keep trying until you succeed!", howToUnlock: "Restart your streak or goals 10 times"),
        Achievement(name: "Task Juggler", iconName: "circle.hexagongrid.fill", color: "#FF595E", isUnlocked: false, description: "Multitasking master! You handle more than most can dream of.", howToUnlock: "Complete 20 or more tasks in a single day"),
        Achievement(name: "Rainbow Warrior", iconName: "cloud.rainbow.half.fill", color: "#FF006E", isUnlocked: false, description: "Variety is the spice of life! You've explored every category.", howToUnlock: "Complete at least one task in every task category"),
        Achievement(name: "Around the Clock", iconName: "clock.fill", color: "#3A86FF", isUnlocked: false, description: "Morning, noon, or night—you're productive at all hours!", howToUnlock: "Log tasks during morning, afternoon, evening, and late night")
    ]
    
    static var unlockedAchievements: [Achievement] {
        allAchievements.filter { $0.isUnlocked }
    }
    
    static var lockedAchievements: [Achievement] {
        allAchievements.filter { !$0.isUnlocked }
    }
}

