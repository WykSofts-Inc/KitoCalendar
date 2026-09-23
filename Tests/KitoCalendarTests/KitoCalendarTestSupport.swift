//
//  KitoCalendarTestSupport.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
@testable import KitoCalendar

/// A Gregorian calendar pinned to a time zone, locale and first weekday, so tests don't depend
/// on the machine running them.
func makeCalendar(firstWeekday: Int = 2, timeZone: String = "Africa/Nairobi", locale: String = "en_GB") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
    calendar.locale = Locale(identifier: locale)
    calendar.firstWeekday = firstWeekday
    return calendar
}

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, calendar: Calendar = makeCalendar()) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
}

func event(
    _ id: String,
    _ start: Date,
    _ end: Date,
    isAllDay: Bool = false
) -> KitoCalendarEvent {
    KitoCalendarEvent(id: id, title: id, start: start, end: end, isAllDay: isAllDay)
}
