//
//  KitoCalendarMath.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The date arithmetic every view in the kit is built on. Everything takes a `Calendar`, so the
/// first weekday, time zone and locale always come from the caller (the views pass
/// `@Environment(\.calendar)`), never from a hidden global.
public enum KitoCalendarMath {
    /// Midnight on the first day of the month containing `date`.
    public static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Midnight on the first day of the week containing `date`, honouring `calendar.firstWeekday`
    /// (Sunday in the US, Monday in Kenya and most of Europe).
    public static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The seven days of the week containing `date`, each at midnight.
    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let start = startOfWeek(containing: date, calendar: calendar)
        return (0..<7).map { adding(days: $0, to: start, calendar: calendar) }
    }

    /// Nights between two days — check-in to check-out. Time of day is ignored and daylight
    /// saving changes don't shorten or lengthen a night. Negative when `end` is before `start`.
    public static func nights(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Weekday names in display order, starting at `calendar.firstWeekday`, in the calendar's
    /// locale (or `locale` when given).
    public static func weekdaySymbols(
        calendar: Calendar = .current,
        locale: Locale? = nil,
        style: KitoWeekdayStyle = .veryShort
    ) -> [String] {
        // Setting a locale can reset `firstWeekday` to the locale's default, so read the order
        // from the calendar as given and only the names from the localized copy.
        let shift = ((calendar.firstWeekday - 1) % 7 + 7) % 7
        var named = calendar
        if let locale { named.locale = locale }
        let symbols: [String]
        switch style {
        case .veryShort: symbols = named.veryShortStandaloneWeekdaySymbols
        case .short: symbols = named.shortStandaloneWeekdaySymbols
        case .full: symbols = named.standaloneWeekdaySymbols
        }
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Every day (at midnight) that `event` touches. A zero-length event touches the day it
    /// starts on; an event ending exactly at midnight doesn't touch the day that midnight begins.
    public static func days(spannedBy event: KitoCalendarEvent, calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: event.start)
        let lastInstant = event.end > event.start ? event.end.addingTimeInterval(-0.001) : event.start
        let last = calendar.startOfDay(for: lastInstant)
        var days: [Date] = []
        var day = first
        while day <= last, days.count < 3_660 {
            days.append(day)
            day = adding(days: 1, to: day, calendar: calendar)
        }
        return days
    }

    /// Events bucketed by the days they touch, keyed by midnight.
    public static func eventsByDay(_ events: [KitoCalendarEvent], calendar: Calendar = .current) -> [Date: [KitoCalendarEvent]] {
        var buckets: [Date: [KitoCalendarEvent]] = [:]
        for event in events {
            for day in days(spannedBy: event, calendar: calendar) {
                buckets[day, default: []].append(event)
            }
        }
        return buckets
    }

    /// Events grouped into days for an agenda: days in order, and within a day all-day events
    /// first, then by start time, then by title. A multi-day event appears on every day it touches.
    public static func agenda(for events: [KitoCalendarEvent], calendar: Calendar = .current) -> [KitoAgendaDay] {
        eventsByDay(events, calendar: calendar)
            .map { day, events in
                KitoAgendaDay(date: day, events: events.sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                    if lhs.start != rhs.start { return lhs.start < rhs.start }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                })
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Internal helpers

    static func adding(days: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days) * 86_400)
    }

    static func adding(months: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date.addingTimeInterval(TimeInterval(months) * 30 * 86_400)
    }

    static func adding(weeks: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date.addingTimeInterval(TimeInterval(weeks) * 7 * 86_400)
    }

    /// Months from `from` to `to`, both inclusive, each at the start of the month.
    static func months(from: Date, to: Date, calendar: Calendar) -> [Date] {
        let first = startOfMonth(for: from, calendar: calendar)
        let last = startOfMonth(for: to, calendar: calendar)
        var months: [Date] = []
        var month = first
        while month <= last, months.count < 1_200 {
            months.append(month)
            month = adding(months: 1, to: month, calendar: calendar)
        }
        return months
    }

    /// Weeks from `from` to `to`, both inclusive, each at the start of the week.
    static func weeks(from: Date, to: Date, calendar: Calendar) -> [Date] {
        let first = startOfWeek(containing: from, calendar: calendar)
        let last = startOfWeek(containing: to, calendar: calendar)
        var weeks: [Date] = []
        var week = first
        while week <= last, weeks.count < 2_000 {
            weeks.append(week)
            week = adding(weeks: 1, to: week, calendar: calendar)
        }
        return weeks
    }
}

/// How long the weekday names above a calendar are: "M", "Mon" or "Monday".
public enum KitoWeekdayStyle: Sendable {
    case veryShort
    case short
    case full
}

/// One day in an agenda: its date (midnight) and the events that touch it, in display order.
public struct KitoAgendaDay: Identifiable, Hashable, Sendable {
    public let date: Date
    public let events: [KitoCalendarEvent]
    public var id: Date { date }

    public init(date: Date, events: [KitoCalendarEvent]) {
        self.date = date
        self.events = events
    }
}
