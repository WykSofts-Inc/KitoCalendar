//
//  KitoEventLayout.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Where an event sits in a day timeline: which column, out of how many side by side.
public struct KitoEventPlacement: Hashable, Sendable {
    public let event: KitoCalendarEvent
    /// Zero-based column.
    public let column: Int
    /// Columns in this event's overlap group; the event is `1 / columnCount` of the width.
    public let columnCount: Int
}

/// Lays events out in columns so none overlap, the way calendar apps do. Events that overlap —
/// directly or through a chain — form a group; each event takes the leftmost column that's free
/// when it starts, and every event in the group shares the group's column count.
public enum KitoEventLayout {
    /// - Parameter minimumDuration: seconds; shorter events are treated as this long, so blocks
    ///   drawn at a minimum height don't overlap.
    public static func placements(for events: [KitoCalendarEvent], minimumDuration: TimeInterval = 0) -> [KitoEventPlacement] {
        func effectiveEnd(_ event: KitoCalendarEvent) -> Date {
            max(event.end, event.start.addingTimeInterval(minimumDuration))
        }

        let sorted = events.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            let lhsEnd = effectiveEnd(lhs), rhsEnd = effectiveEnd(rhs)
            if lhsEnd != rhsEnd { return lhsEnd > rhsEnd }
            return lhs.id < rhs.id
        }

        var placements: [KitoEventPlacement] = []
        var group: [(event: KitoCalendarEvent, column: Int)] = []
        var columnEnds: [Date] = []
        var groupEnd: Date?

        func closeGroup() {
            let count = max(columnEnds.count, 1)
            placements += group.map { KitoEventPlacement(event: $0.event, column: $0.column, columnCount: count) }
            group.removeAll()
            columnEnds.removeAll()
            groupEnd = nil
        }

        for event in sorted {
            if let end = groupEnd, event.start >= end { closeGroup() }
            let end = effectiveEnd(event)
            let column: Int
            if let free = columnEnds.firstIndex(where: { $0 <= event.start }) {
                columnEnds[free] = end
                column = free
            } else {
                columnEnds.append(end)
                column = columnEnds.count - 1
            }
            group.append((event, column))
            groupEnd = max(groupEnd ?? end, end)
        }
        closeGroup()
        return placements
    }
}
