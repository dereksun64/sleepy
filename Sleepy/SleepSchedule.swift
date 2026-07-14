import Foundation

enum SleepSchedule {
    static func interval(
        on bedtimeDay: Date,
        bedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let start = date(on: bedtimeDay, usingTimeFrom: bedtime, calendar: calendar)
        let bedtimeMinutes = minutesSinceMidnight(bedtime, calendar: calendar)
        let wakeMinutes = minutesSinceMidnight(wakeTime, calendar: calendar)
        let wakeDay = wakeMinutes > bedtimeMinutes
            ? bedtimeDay
            : calendar.date(byAdding: .day, value: 1, to: bedtimeDay)!
        let end = date(on: wakeDay, usingTimeFrom: wakeTime, calendar: calendar)
        return DateInterval(start: start, end: end)
    }

    static func currentOrNext(
        at now: Date,
        bedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let previous = interval(on: yesterday, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
        if previous.contains(now) { return previous }

        let today = interval(on: now, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
        if now <= today.end { return today }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return interval(on: tomorrow, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
    }

    private static func date(on day: Date, usingTimeFrom time: Date, calendar: Calendar) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        return calendar.date(from: components)!
    }

    private static func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
