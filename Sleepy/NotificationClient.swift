import Foundation
import UserNotifications

final class NotificationClient {
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleBedtimePrompt(at date: Date) async throws {
        try await schedule(
            id: "bedtime.prompt",
            body: "Are you brushing your teeth now?",
            at: date
        )
    }

    func scheduleNoResponseFollowUp(at date: Date) async throws {
        try await schedule(
            id: "bedtime.no-response",
            body: "Alright man, it's getting late, stop trolling.",
            at: date
        )
    }

    private func schedule(id: String, body: String, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Sleepy"
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }
}
