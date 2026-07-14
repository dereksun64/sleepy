import XCTest
@testable import Sleepy

final class SleepScheduleTests: XCTestCase {
    private func calendar(_ identifier: String = "America/Los_Angeles") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ text: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    func testWakeLaterThanBedtimeStaysOnSameDay() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: cal),
            bedtime: date("2001-01-01 21:00", calendar: cal),
            wakeTime: date("2001-01-01 23:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 21:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-14 23:00", calendar: cal))
    }

    func testEqualOrEarlierWakeMovesToFollowingDay() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: cal))
    }

    func testAfterMidnightResolvesToPreviousBedtimeDate() {
        let cal = calendar()
        let interval = SleepSchedule.currentOrNext(
            at: date("2026-07-15 01:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: cal))
    }

    func testSpringDSTUsesCalendarWallClockTime() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-03-07 12:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.end, date("2026-03-08 07:00", calendar: cal))
        XCTAssertEqual(interval.duration, 7 * 60 * 60)
    }

    func testSameInputsResolveInSelectedTimeZone() {
        let singapore = calendar("Asia/Singapore")
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: singapore),
            bedtime: date("2001-01-01 23:00", calendar: singapore),
            wakeTime: date("2001-01-01 07:00", calendar: singapore),
            calendar: singapore
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: singapore))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: singapore))
    }
}
