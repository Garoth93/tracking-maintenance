import Foundation
import UserNotifications
import UpkeepCore

/// Local notifications for deadlines (they work with a free Apple account).
enum Notifier {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces every pending reminder with the current plan.
    static func reschedule(_ data: AppData, today: DayDate) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard data.settings.notificationsEnabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let plans = data.reminderPlans(today: today, daysBefore: data.settings.notifyDaysBefore)
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            var when = DateComponents()
            when.year = plan.day.year
            when.month = plan.day.month
            when.day = plan.day.day
            when.hour = data.settings.notifyHour
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}
