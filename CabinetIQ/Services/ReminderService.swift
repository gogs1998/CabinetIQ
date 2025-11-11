import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, ObservableObject {
    static let shared = ReminderService()

    @Published private(set) var isAuthorized = false
    private let center = UNUserNotificationCenter.current()

    func prepareAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    func scheduleReminders(for document: DocumentEntity) {
        guard let dueDate = document.dueDate else { return }
        guard let identifier = document.id else { return }
        let identifiers = reminderOffsets.map { id(for: identifier, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isAuthorized else { return }
        for offset in reminderOffsets {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: offset, to: dueDate) else { continue }
            let components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            var comps = components
            comps.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "\(document.docType ?? "Document") due soon"
            content.body = document.issuer ?? "CabinetIQ reminder"
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
