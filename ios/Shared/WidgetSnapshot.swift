import Foundation

enum AppGroup {
    static let id = "group.com.budgetstudio.app"
    static let snapshotKey = "widget-snapshot-v1"
    static let addExpenseURL = URL(string: "budgetstudio://add")!

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

struct WidgetSnapshot: Codable, Equatable {
    var safeToSpend: Double
    var monthLabel: String
    var updatedAt: TimeInterval
    var signedIn: Bool

    static let empty = WidgetSnapshot(
        safeToSpend: 0,
        monthLabel: "",
        updatedAt: 0,
        signedIn: false
    )

    static func load() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.snapshotKey)
    }
}
