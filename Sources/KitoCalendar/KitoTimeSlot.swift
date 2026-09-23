//
//  KitoTimeSlot.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A bookable window — a haircut at 10:30, a table at 19:00.
public struct KitoTimeSlot: Identifiable, Hashable, Sendable {
    public let start: Date
    public let end: Date
    public var isAvailable: Bool
    /// Morning, afternoon or evening, from the start hour.
    public let period: KitoDayPeriod
    public var id: Date { start }

    public init(start: Date, end: Date, isAvailable: Bool = true, calendar: Calendar = .current) {
        self.start = start
        self.end = max(start, end)
        self.isAvailable = isAvailable
        self.period = KitoDayPeriod(hour: calendar.component(.hour, from: start))
    }
}

/// The three groups a slot picker shows.
public enum KitoDayPeriod: String, CaseIterable, Identifiable, Sendable {
    /// Before noon.
    case morning
    /// Noon to 17:00.
    case afternoon
    /// 17:00 onwards.
    case evening

    public init(hour: Int) {
        switch hour {
        case ..<12: self = .morning
        case ..<17: self = .afternoon
        default: self = .evening
        }
    }

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    /// SF Symbol for the group header.
    public var systemImage: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

/// A time of day, e.g. `.init(8, 30)` for half past eight. Hour 24 means midnight at the end of
/// the day.
public struct KitoClockTime: Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: KitoClockTime, rhs: KitoClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// Opening hours and slot length for a day of bookings. Slots start every `interval` minutes from
/// `opens` and are `duration` minutes long; the last one ends by `closes`.
///
/// ```swift
/// let salon = KitoSlotSchedule(opens: .init(8, 30), closes: .init(18), duration: 45, interval: 15)
/// let slots = salon.slots(on: day, booked: bookings, notBefore: .now)
/// ```
public struct KitoSlotSchedule: Hashable, Sendable {
    public var opens: KitoClockTime
    public var closes: KitoClockTime
    /// Slot length in minutes.
    public var duration: Int
    /// Minutes between slot starts. Equal to `duration` for back-to-back slots.
    public var interval: Int

    /// - Parameters:
    ///   - duration: slot length in minutes.
    ///   - interval: minutes between starts; `nil` means back to back (`duration`).
    public init(
        opens: KitoClockTime = .init(9),
        closes: KitoClockTime = .init(17),
        duration: Int = 30,
        interval: Int? = nil
    ) {
        self.opens = opens
        self.closes = closes
        self.duration = duration
        self.interval = interval ?? duration
    }

    /// The slots on `day`. A slot is unavailable when it overlaps any `booked` interval or starts
    /// before `notBefore` (pass `.now` to grey out what's already passed today).
    public func slots(
        on day: Date,
        booked: [DateInterval] = [],
        notBefore earliest: Date? = nil,
        calendar: Calendar = .current
    ) -> [KitoTimeSlot] {
        guard duration > 0, interval > 0, opens < closes else { return [] }
        let midnight = calendar.startOfDay(for: day)
        func time(_ minutes: Int) -> Date {
            calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight.addingTimeInterval(TimeInterval(minutes * 60))
        }

        var slots: [KitoTimeSlot] = []
        var minute = opens.minutesSinceMidnight
        while minute + duration <= closes.minutesSinceMidnight, slots.count < 1_440 {
            let start = time(minute)
            let end = time(minute + duration)
            let clashes = booked.contains { start < $0.end && end > $0.start }
            let passed = earliest.map { start < $0 } ?? false
            slots.append(KitoTimeSlot(start: start, end: end, isAvailable: !clashes && !passed, calendar: calendar))
            minute += interval
        }
        return slots
    }
}
