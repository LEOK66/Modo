import Foundation

enum DefaultAvatars {
    // Update this list to match names in Assets.xcassets
    static let all: [String] = [
        "profile_1",
        "profile_2",
        "profile_3",
        "profile_4",
        "profile_5",
        "profile_6",
        "profile_7",
        "profile_8"
    ]

    static func random() -> String? {
        return all.randomElement()
    }
}

