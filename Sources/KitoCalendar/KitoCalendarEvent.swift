//
//  KitoCalendarEvent.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// Something on the calendar — a meeting, a booking, a trip. `end` is exclusive: an event from
/// 9:00 to 10:00 is over the moment 10:00 begins, and an all-day event on the 12th runs from the
/// start of the 12th to the start of the 13th. Month grids show it as a dot, the week strip as a
/// dot under the day, the timeline as a block and the agenda as a row.
public struct KitoCalendarEvent: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var color: Color
    public var location: String?
    public var isAllDay: Bool

    /// An `end` earlier than `start` is clamped to `start`.
    public init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        color: Color = .blue,
        location: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = max(start, end)
        self.color = color
        self.location = location
        self.isAllDay = isAllDay
    }

    /// Length in seconds.
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    /// Whether the event is running at `date`.
    public func isOngoing(at date: Date = .now) -> Bool {
        start <= date && date < end
    }
}
