import Foundation

struct PickupCodeHistoryItem: Codable, Hashable, Identifiable {
    let id: UUID
    let code: String
    let context: String
    let icon: String
    let brandIconName: String?
    let brandName: String?
    let category: PickupCategory?
    let confidence: Double
    let createdAt: Date
}

struct CurrentPickupCodeItem: Codable, Hashable {
    let code: String
    let context: String
    let icon: String
    let brandIconName: String?
    let brandName: String?
    let category: PickupCategory?
    let confidence: Double
    let createdAt: Date
    let expiresAt: Date
}

enum PickupCodeHistoryStore {
    nonisolated private static let key = "pickupCodeHistory"
    nonisolated private static let currentKey = "currentPickupCode"
    nonisolated private static let limit = 5
    nonisolated private static let currentLifetime: TimeInterval = 20 * 60

    nonisolated static func load() -> [PickupCodeHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([PickupCodeHistoryItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(limit))
    }

    nonisolated static func loadCurrent(now: Date = Date()) -> CurrentPickupCodeItem? {
        guard let current = rawCurrent() else { return nil }
        guard current.expiresAt > now else { return nil }
        return current
    }

    @discardableResult
    nonisolated static func saveCurrent(
        code: String,
        context: String,
        icon: String,
        brandIconName: String? = nil,
        brandName: String? = nil,
        category: PickupCategory? = nil,
        confidence: Double,
        now: Date = Date()
    ) -> CurrentPickupCodeItem {
        let current = CurrentPickupCodeItem(
            code: code,
            context: context,
            icon: icon,
            brandIconName: brandIconName,
            brandName: brandName,
            category: category,
            confidence: confidence,
            createdAt: now,
            expiresAt: now.addingTimeInterval(currentLifetime)
        )

        saveCurrent(current)
        return current
    }

    @discardableResult
    nonisolated static func archiveCurrentIfExpired(now: Date = Date()) -> [PickupCodeHistoryItem] {
        guard let current = rawCurrent(), current.expiresAt <= now else {
            return load()
        }

        clearCurrent()
        return add(current)
    }

    @discardableResult
    nonisolated static func completeCurrent() -> [PickupCodeHistoryItem] {
        guard let current = rawCurrent() else { return load() }
        clearCurrent()
        return add(current)
    }

    nonisolated static func clearCurrent() {
        UserDefaults.standard.removeObject(forKey: currentKey)
    }

    @discardableResult
    nonisolated static func add(
        code: String,
        context: String,
        icon: String,
        brandIconName: String? = nil,
        brandName: String? = nil,
        category: PickupCategory? = nil,
        confidence: Double
    ) -> [PickupCodeHistoryItem] {
        let item = PickupCodeHistoryItem(
            id: UUID(),
            code: code,
            context: context,
            icon: icon,
            brandIconName: brandIconName,
            brandName: brandName,
            category: category,
            confidence: confidence,
            createdAt: Date()
        )

        var items = load()
        items.insert(item, at: 0)
        items = Array(items.prefix(limit))
        save(items)
        return items
    }

    @discardableResult
    nonisolated private static func add(_ current: CurrentPickupCodeItem) -> [PickupCodeHistoryItem] {
        add(
            code: current.code,
            context: current.context,
            icon: current.icon,
            brandIconName: current.brandIconName,
            brandName: current.brandName,
            category: current.category,
            confidence: current.confidence
        )
    }

    nonisolated private static func rawCurrent() -> CurrentPickupCodeItem? {
        guard let data = UserDefaults.standard.data(forKey: currentKey),
              let current = try? JSONDecoder().decode(CurrentPickupCodeItem.self, from: data) else {
            return nil
        }
        return current
    }

    nonisolated private static func saveCurrent(_ current: CurrentPickupCodeItem) {
        guard let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: currentKey)
    }

    nonisolated private static func save(_ items: [PickupCodeHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
