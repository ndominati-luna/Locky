import Foundation
import LockyKit
import Observation

/// Intrusion reports synced through iCloud (photos taken by the Mac).
@MainActor
@Observable
final class IntrusionStore {
    private(set) var reports: [IntrusionReport] = []
    private(set) var isLoading: Bool = false
    private(set) var isCloudAvailable: Bool = true
    /// Date of the most recent report the user has seen.
    private(set) var lastSeenDate: Date = UserDefaults.standard.object(forKey: "locky.intrusions.lastSeen") as? Date ?? .distantPast

    /// Reports received since the user last opened the list.
    var unseenCount: Int {
        reports.count { $0.date > lastSeenDate }
    }

    /// Marks every report as seen.
    func markAllSeen() {
        guard let newest = reports.map(\.date).max(), newest > lastSeenDate else { return }
        lastSeenDate = newest
        UserDefaults.standard.set(newest, forKey: "locky.intrusions.lastSeen")
    }

    func refresh(macID: UUID?) async {
        #if DEBUG
        guard !DemoMode.isEnabled else { return }
        #endif
        isLoading = true
        defer { isLoading = false }
        guard await CloudSync.shared.isAvailable() else {
            isCloudAvailable = false
            return
        }
        isCloudAvailable = true
        guard let all = try? await CloudSync.shared.fetchAll().intrusions else { return }
        reports = all.filter { macID == nil || $0.macID == macID }
    }

    func delete(_ report: IntrusionReport) async {
        reports.removeAll { $0.id == report.id }
        try? await CloudSync.shared.deleteIntrusions(ids: [report.id])
    }

    func deleteAll() async {
        let ids: [String] = reports.map(\.id)
        reports.removeAll()
        try? await CloudSync.shared.deleteIntrusions(ids: ids)
    }

    func clear() {
        reports.removeAll()
    }

    #if DEBUG
    func injectDemoReports(_ reports: [IntrusionReport]) {
        self.reports = reports
        isCloudAvailable = true
    }
    #endif
}
