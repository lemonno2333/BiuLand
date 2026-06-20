import Foundation

enum AppGroup {
    static let identifier = "group.com.leo.BiuLand"

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
