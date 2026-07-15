import Foundation

enum AppGroup {
    static let id = "group.com.budgetstudio.app"
    static let snapshotFileName = "widget-snapshot-v1.json"
    static let addExpenseURL = URL(string: "budgetstudio://add")!

    /// True when this process has a mounted App Group container (entitlement + provisioning).
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    /// JSON file in the shared container; avoids UserDefaults(suiteName:) CFPrefs console noise.
    static var snapshotURL: URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            return nil
        }
        return container.appendingPathComponent(snapshotFileName)
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
        guard let url = AppGroup.snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save() {
        guard let url = AppGroup.snapshotURL,
              let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
