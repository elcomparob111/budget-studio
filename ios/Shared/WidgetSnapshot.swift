import Foundation

enum AppGroup {
    static let id = "group.com.budgetstudio.app"
    static let snapshotKey = "widget-snapshot-v1"
    static let addExpenseURL = URL(string: "budgetstudio://add")!

    /// True when this process has a mounted App Group container (entitlement + provisioning).
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    /// Shared defaults for the widget; nil when the App Group isn't provisioned on this install.
    static var sharedDefaults: UserDefaults? {
        guard isAvailable else { return nil }
        return UserDefaults(suiteName: id)
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
        guard let defaults = AppGroup.sharedDefaults,
              let data = defaults.data(forKey: AppGroup.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save() {
        guard let defaults = AppGroup.sharedDefaults,
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: AppGroup.snapshotKey)
    }
}
