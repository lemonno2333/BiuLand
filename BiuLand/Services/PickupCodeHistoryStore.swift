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

enum PickupCodeHistoryStore {
    nonisolated private static let key = "pickupCodeHistory"
    nonisolated private static let limit = 10

    nonisolated static func load() -> [PickupCodeHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([PickupCodeHistoryItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(limit))
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

    nonisolated private static func save(_ items: [PickupCodeHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
