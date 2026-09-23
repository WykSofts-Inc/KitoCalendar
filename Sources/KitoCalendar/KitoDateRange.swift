//
//  KitoDateRange.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A span of whole days, both ends inclusive — a stay from check-in to check-out, a trip, a
/// reporting period. The initializer orders the ends, so `start` is never after `end`.
public struct KitoDateRange: Hashable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    /// Nights from `start` to `end` — 12 to 18 October is 6 nights.
    public func nights(calendar: Calendar = .current) -> Int {
        KitoCalendarMath.nights(from: start, to: end, calendar: calendar)
    }

    /// Calendar days covered, both ends included — 12 to 18 October is 7 days.
    public func dayCount(calendar: Calendar = .current) -> Int {
        nights(calendar: calendar) + 1
    }

    /// Whether `date` falls on a day inside the range, ends included.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: end)
    }

    /// "12 – 18 Oct · 6 nights" (or "Oct 12 – 18 · 6 nights" where the month comes first). Pass
    /// `unit: nil` to leave the count off.
    public func formatted(
        unit: KitoRangeUnit? = .nights,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let dates = formattedDates(calendar: calendar, locale: locale)
        guard let unit else { return dates }
        return "\(dates) · \(unit.label(for: self, calendar: calendar))"
    }

    /// Just the dates: "12 – 18 Oct", "28 Oct – 3 Nov", "30 Dec 2026 – 2 Jan 2027".
    public func formattedDates(calendar: Calendar = .current, locale: Locale = .current) -> String {
        let format = RangeFormatter(calendar: calendar, locale: locale)
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: end)

        if calendar.isDate(start, inSameDayAs: end) {
            return format.string(start, template: "dMMM")
        }
        if sameMonth {
            return format.dayComesFirst
                ? "\(format.string(start, template: "d")) – \(format.string(end, template: "dMMM"))"
                : "\(format.string(start, template: "dMMM")) – \(format.string(end, template: "d"))"
        }
        if sameYear {
            return "\(format.string(start, template: "dMMM")) – \(format.string(end, template: "dMMM"))"
        }
        return "\(format.string(start, template: "dMMMy")) – \(format.string(end, template: "dMMMy"))"
    }
}

/// What a range's count is measured in.
public enum KitoRangeUnit: Sendable {
    /// Stays: 12 to 18 October is "6 nights".
    case nights
    /// Trips and periods: 12 to 18 October is "7 days".
    case days

    /// The count for `range`, e.g. 6 for 12–18 October in nights.
    public func count(for range: KitoDateRange, calendar: Calendar = .current) -> Int {
        switch self {
        case .nights: return range.nights(calendar: calendar)
        case .days: return range.dayCount(calendar: calendar)
        }
    }

    /// "1 night", "6 nights", "7 days".
    public func label(for range: KitoDateRange, calendar: Calendar = .current) -> String {
        let count = count(for: range, calendar: calendar)
        switch self {
        case .nights: return count == 1 ? "1 night" : "\(count) nights"
        case .days: return count == 1 ? "1 day" : "\(count) days"
        }
    }
}

/// Tap-to-pick state for a range calendar, like an airline or hotel booking screen:
///
/// 1. The first tap sets the start.
/// 2. A later day sets the end and completes the range.
/// 3. A day before the start moves the start there instead.
/// 4. Tapping the start again clears it (or, with `allowsSingleDay`, makes a one-day range).
/// 5. Any tap on a complete range starts a new one.
public struct KitoRangeSelection: Equatable, Sendable {
    public private(set) var start: Date?
    public private(set) var end: Date?
    /// Whether tapping the start twice picks that single day.
    public var allowsSingleDay: Bool

    public init(_ range: KitoDateRange? = nil, allowsSingleDay: Bool = false, calendar: Calendar = .current) {
        self.allowsSingleDay = allowsSingleDay
        if let range {
            start = calendar.startOfDay(for: range.start)
            end = calendar.startOfDay(for: range.end)
        }
    }

    /// The finished range, or `nil` while it's empty or waiting for an end.
    public var range: KitoDateRange? {
        guard let start, let end else { return nil }
        return KitoDateRange(start: start, end: end)
    }

    public var isEmpty: Bool { start == nil }
    public var isComplete: Bool { start != nil && end != nil }
    /// A start is picked and the next tap will pick the end.
    public var isAwaitingEnd: Bool { start != nil && end == nil }

    /// Applies a tap on `date` (any time that day).
    public mutating func select(_ date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        guard let start, end == nil else {
            self.start = day
            self.end = nil
            return
        }
        if day < start {
            self.start = day
        } else if day == start {
            if allowsSingleDay { end = day } else { self.start = nil }
        } else {
            end = day
        }
    }

    /// Replaces the selection with `range` (e.g. from a preset), or clears it.
    public mutating func set(_ range: KitoDateRange?, calendar: Calendar = .current) {
        start = range.map { calendar.startOfDay(for: $0.start) }
        end = range.map { calendar.startOfDay(for: $0.end) }
    }

    public mutating func clear() {
        start = nil
        end = nil
    }
}

/// Builds date strings from localized templates, with the calendar's time zone.
private struct RangeFormatter {
    let calendar: Calendar
    let locale: Locale

    func string(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// "18 Oct" (day first) or "Oct 18" (month first) in this locale.
    var dayComesFirst: Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "dMMM", options: 0, locale: locale) ?? "d MMM"
        guard let day = pattern.firstIndex(of: "d") else { return true }
        guard let month = pattern.firstIndex(where: { $0 == "M" || $0 == "L" }) else { return true }
        return day < month
    }
}
