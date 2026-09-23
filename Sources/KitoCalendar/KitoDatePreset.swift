//
//  KitoDatePreset.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A one-tap range — "This weekend", "Next 7 days" — resolved against today when it's tapped,
/// so a preset made once stays right tomorrow.
public struct KitoDatePreset: Identifiable, Sendable {
    public let id: String
    public let title: String
    /// SF Symbol shown on the chip.
    public let systemImage: String
    private let resolve: @Sendable (_ now: Date, _ calendar: Calendar) -> KitoDateRange

    /// - Parameter range: returns the range for a given "now" and calendar.
    public init(
        id: String? = nil,
        _ title: String,
        systemImage: String = "calendar",
        range: @escaping @Sendable (_ now: Date, _ calendar: Calendar) -> KitoDateRange
    ) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.resolve = range
    }

    /// The range this preset stands for today (or on `now`).
    public func range(relativeTo now: Date = .now, calendar: Calendar = .current) -> KitoDateRange {
        resolve(now, calendar)
    }

    /// The weekend under way, or the next one — as the calendar's locale defines a weekend
    /// (Saturday–Sunday in most places). Never starts before today.
    public static let thisWeekend = KitoDatePreset(id: "thisWeekend", "This weekend", systemImage: "sun.max") { now, calendar in
        let today = calendar.startOfDay(for: now)
        let weekend = calendar.isDateInWeekend(today)
            ? calendar.dateIntervalOfWeekend(containing: today)
            : calendar.nextWeekend(startingAfter: today)
        guard let weekend else {
            return KitoDateRange(start: today, end: KitoCalendarMath.adding(days: 1, to: today, calendar: calendar))
        }
        let start = max(calendar.startOfDay(for: weekend.start), today)
        let end = calendar.startOfDay(for: weekend.end.addingTimeInterval(-1))
        return KitoDateRange(start: start, end: max(start, end))
    }

    /// Today and the six days after it — seven calendar days.
    public static let nextSevenDays = KitoDatePreset(id: "nextSevenDays", "Next 7 days", systemImage: "7.circle") { now, calendar in
        let today = calendar.startOfDay(for: now)
        return KitoDateRange(start: today, end: KitoCalendarMath.adding(days: 6, to: today, calendar: calendar))
    }

    /// Today to the last day of this month.
    public static let thisMonth = KitoDatePreset(id: "thisMonth", "This month", systemImage: "calendar") { now, calendar in
        let today = calendar.startOfDay(for: now)
        let firstOfNext = KitoCalendarMath.adding(months: 1, to: KitoCalendarMath.startOfMonth(for: today, calendar: calendar), calendar: calendar)
        let last = KitoCalendarMath.adding(days: -1, to: firstOfNext, calendar: calendar)
        return KitoDateRange(start: today, end: max(today, last))
    }

    /// This weekend, next 7 days and this month.
    public static let standard: [KitoDatePreset] = [.thisWeekend, .nextSevenDays, .thisMonth]
}
