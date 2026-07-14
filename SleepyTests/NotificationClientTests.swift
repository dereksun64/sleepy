import UserNotifications
import XCTest
@testable import Sleepy

@MainActor
final class NotificationClientTests: XCTestCase {
    func testStableIdentifiers() {
        XCTAssertEqual(NotificationID.category, "bedtime.actions")
        XCTAssertEqual(NotificationID.prompt, "bedtime.prompt")
        XCTAssertEqual(NotificationID.noResponse, "bedtime.no-response")
        XCTAssertEqual(NotificationID.snooze(3), "bedtime.snooze.3")
        XCTAssertEqual(
            NotificationID.all,
            ["bedtime.prompt", "bedtime.no-response", "bedtime.snooze.1", "bedtime.snooze.2", "bedtime.snooze.3"]
        )
    }

    func testPromptContainsCategoryCopyAndRequestedDate() throws {
        let calendar = singaporeCalendar
        let date = Date(timeIntervalSince1970: 1_752_500_000)
        let request = NotificationClient.makePromptRequest(id: NotificationID.prompt, at: date, calendar: calendar)

        XCTAssertEqual(request.identifier, NotificationID.prompt)
        XCTAssertEqual(request.content.body, "Are you brushing your teeth now?")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationID.category)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents, calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date))
    }

    func testFollowUpHasStableCopyAndNoActionCategory() {
        let request = NotificationClient.makeNoResponseRequest(at: .now, calendar: singaporeCalendar)

        XCTAssertEqual(request.identifier, NotificationID.noResponse)
        XCTAssertEqual(request.content.body, "Alright man, it's getting late, stop trolling.")
        XCTAssertEqual(request.content.categoryIdentifier, "")
    }

    func testCategoryHasExactlyFourForegroundActionsInRequiredOrder() {
        let category = NotificationClient.bedtimeCategory()

        XCTAssertEqual(category.identifier, NotificationID.category)
        XCTAssertEqual(category.actions.map(\.identifier), NotificationAction.allCases.map(\.rawValue))
        XCTAssertEqual(category.actions.map(\.title), ["Starting now", "Remind me in 5 minutes", "Already done", "Skip tonight"])
        XCTAssertTrue(category.actions.allSatisfy { $0.options.contains(.foreground) })
    }

    func testPermissionStatusMappingIsAuthoritative() {
        XCTAssertEqual(NotificationClient.permissionState(for: .authorized), .approved)
        XCTAssertEqual(NotificationClient.permissionState(for: .provisional), .approved)
        XCTAssertEqual(NotificationClient.permissionState(for: .ephemeral), .approved)
        XCTAssertEqual(NotificationClient.permissionState(for: .denied), .denied)
        XCTAssertEqual(NotificationClient.permissionState(for: .notDetermined), .unknown)
    }

    func testRegisterCategoriesInstallsOnlyBedtimeCategory() {
        let recorder = NotificationRecorder()

        recorder.client().registerCategories()

        XCTAssertEqual(recorder.registeredCategories.count, 1)
        XCTAssertEqual(recorder.registeredCategories.first?.map(\.identifier), [NotificationID.category])
    }

    func testScheduleNightRemovesObsoleteRequestsAndAddsPromptAndFollowUp() async throws {
        let recorder = NotificationRecorder()
        let client = recorder.client()
        let calendar = singaporeCalendar
        let start = Date(timeIntervalSince1970: 1_752_500_000)

        try await client.scheduleNight(
            interval: DateInterval(start: start, duration: 8 * 60 * 60),
            calendar: calendar
        )

        XCTAssertEqual(recorder.removedIdentifiers, [NotificationID.all])
        XCTAssertEqual(recorder.requests.map(\.identifier), [NotificationID.prompt, NotificationID.noResponse])
        XCTAssertEqual(
            recorder.requests.map(\.requestedDateComponents),
            [start, calendar.date(byAdding: .minute, value: 10, to: start)!]
                .map { calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        )
    }

    func testSnoozeUsesStableCountIdentifierAndFiveMinuteDate() async throws {
        let recorder = NotificationRecorder()
        let client = recorder.client()
        let calendar = singaporeCalendar
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        try await client.scheduleSnooze(count: 2, from: now, calendar: calendar)

        XCTAssertEqual(recorder.requests.map(\.identifier), [NotificationID.snooze(2)])
        XCTAssertEqual(
            recorder.requests.first?.requestedDateComponents,
            calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: calendar.date(byAdding: .minute, value: 5, to: now)!
            )
        )
    }

    func testDelegateBuffersKnownActionWithSourceRequestIdentifier() {
        let delegate = AppDelegate()
        var received: [(NotificationAction, String)] = []

        delegate.forwardResponse(
            actionIdentifier: NotificationAction.snooze.rawValue,
            requestIdentifier: NotificationID.snooze(2)
        )
        delegate.installResponseHandler { received.append(($0, $1)) }

        XCTAssertEqual(received.map(\.0), [.snooze])
        XCTAssertEqual(received.map(\.1), [NotificationID.snooze(2)])
    }

    func testDelegateForwardsOnlyKnownActionsAfterInstallation() {
        let delegate = AppDelegate()
        var received: [(NotificationAction, String)] = []
        delegate.installResponseHandler { received.append(($0, $1)) }

        delegate.forwardResponse(actionIdentifier: UNNotificationDefaultActionIdentifier, requestIdentifier: "ignored")
        delegate.forwardResponse(
            actionIdentifier: NotificationAction.startingNow.rawValue,
            requestIdentifier: NotificationID.prompt
        )

        XCTAssertEqual(received.map(\.0), [.startingNow])
        XCTAssertEqual(received.map(\.1), [NotificationID.prompt])
    }

    private var singaporeCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }
}

private final class NotificationRecorder {
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []
    var registeredCategories: [Set<UNNotificationCategory>] = []

    func client() -> NotificationClient {
        NotificationClient(
            addRequest: { self.requests.append($0) },
            removeRequests: { self.removedIdentifiers.append($0) },
            setCategories: { self.registeredCategories.append($0) }
        )
    }
}

private extension UNNotificationRequest {
    var requestedDateComponents: DateComponents? {
        (trigger as? UNCalendarNotificationTrigger)?.dateComponents
    }
}
