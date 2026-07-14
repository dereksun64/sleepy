import Foundation
import UserNotifications

enum NotificationID {
    static let category = "bedtime.actions"
    static let prompt = "bedtime.prompt"
    static let noResponse = "bedtime.no-response"
    static func snooze(_ count: Int) -> String { "bedtime.snooze.\(count)" }
    static let all = [prompt, noResponse] + (1...3).map(snooze)

    static func snoozeCount(for requestIdentifier: String) -> Int? {
        if requestIdentifier == prompt { return 0 }
        let prefix = "bedtime.snooze."
        guard requestIdentifier.hasPrefix(prefix),
              let count = Int(requestIdentifier.dropFirst(prefix.count)),
              (1...3).contains(count) else { return nil }
        return count
    }
}

enum NotificationAction: String, CaseIterable {
    case startingNow = "bedtime.starting-now"
    case snooze = "bedtime.snooze"
    case alreadyDone = "bedtime.already-done"
    case skipTonight = "bedtime.skip-tonight"
}

final class NotificationClient {
    private let center: UNUserNotificationCenter
    private let addRequest: (UNNotificationRequest) async throws -> Void
    private let removeRequests: ([String]) -> Void
    private let setCategories: (Set<UNNotificationCategory>) -> Void

    init(
        center: UNUserNotificationCenter = .current(),
        addRequest: ((UNNotificationRequest) async throws -> Void)? = nil,
        removeRequests: (([String]) -> Void)? = nil,
        setCategories: ((Set<UNNotificationCategory>) -> Void)? = nil
    ) {
        self.center = center
        self.addRequest = addRequest ?? { try await center.add($0) }
        self.removeRequests = removeRequests ?? { center.removePendingNotificationRequests(withIdentifiers: $0) }
        self.setCategories = setCategories ?? { center.setNotificationCategories($0) }
    }

    func requestPermission() async -> PermissionState {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return await permissionStatus()
        } catch {
            return .unavailable
        }
    }

    func permissionStatus() async -> PermissionState {
        Self.permissionState(for: await center.notificationSettings().authorizationStatus)
    }

    func registerCategories() {
        setCategories([Self.bedtimeCategory()])
    }

    func scheduleNight(interval: DateInterval, calendar: Calendar = .current) async throws {
        removeRequests(NotificationID.all)
        try await addRequest(Self.makePromptRequest(id: NotificationID.prompt, at: interval.start, calendar: calendar))
        guard let followUp = calendar.date(byAdding: .minute, value: 10, to: interval.start) else {
            throw CocoaError(.coderInvalidValue)
        }
        try await addRequest(Self.makeNoResponseRequest(at: followUp, calendar: calendar))
    }

    func scheduleSnooze(count: Int, from now: Date, calendar: Calendar = .current) async throws {
        guard let date = calendar.date(byAdding: .minute, value: 5, to: now) else {
            throw CocoaError(.coderInvalidValue)
        }
        try await addRequest(Self.makePromptRequest(id: NotificationID.snooze(count), at: date, calendar: calendar))
    }

    func cancelNoResponseFollowUp() {
        removeRequests([NotificationID.noResponse])
    }

    static func bedtimeCategory() -> UNNotificationCategory {
        let titles = ["Starting now", "Remind me in 5 minutes", "Already done", "Skip tonight"]
        let actions = zip(NotificationAction.allCases, titles).map {
            UNNotificationAction(identifier: $0.rawValue, title: $1, options: [.foreground])
        }
        return UNNotificationCategory(identifier: NotificationID.category, actions: actions, intentIdentifiers: [])
    }

    static func makePromptRequest(id: String, at date: Date, calendar: Calendar) -> UNNotificationRequest {
        makeRequest(id: id, body: "Are you brushing your teeth now?", category: NotificationID.category, at: date, calendar: calendar)
    }

    static func makeNoResponseRequest(at date: Date, calendar: Calendar) -> UNNotificationRequest {
        makeRequest(id: NotificationID.noResponse, body: "Alright man, it's getting late, stop trolling.", category: "", at: date, calendar: calendar)
    }

    static func permissionState(for status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .approved
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unavailable
        }
    }

    private static func makeRequest(
        id: String,
        body: String,
        category: String,
        at date: Date,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Sleepy"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
