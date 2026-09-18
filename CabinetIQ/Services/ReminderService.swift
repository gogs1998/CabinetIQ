import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, ObservableObject {
    static let shared = ReminderService()

    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let center = UNUserNotificationCenter.current()

    func prepareAuthorization() {
        refreshStatus()
    }

    func refreshStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
        }
    }

    func scheduleReminders(for document: DocumentEntity) {
        guard let dueDate = document.dueDate else { return }
        guard let identifier = document.id else { return }
        let identifiers = reminderOffsets.map { id(for: identifier, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }
        guard isAuthorized || authorizationStatus == .notDetermined else { return }
        for offset in reminderOffsets {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: offset, to: dueDate) else { continue }
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            comps.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            let days = abs(offset)
            content.title = "\(document.docTypeValue.displayName) in \(days) days"
            content.body = "\(document.displayTitle) is due \(FieldCatalog.date(dueDate) ?? "soon")."
            content.userInfo = ["documentID": identifier.uuidString]
            let request = UNNotificationRequest(identifier: id(for: identifier, offset: offset), content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelReminders(for document: DocumentEntity) {
        guard let identifier = document.id else { return }
        let identifiers = reminderOffsets.map { id(for: identifier, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private var reminderOffsets: [Int] { [-30, -7] }

    private func id(for identifier: UUID, offset: Int) -> String {
        "cabinetiq.reminder.\(identifier.uuidString).\(offset)"
    }
}
