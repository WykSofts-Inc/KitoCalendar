//
//  KitoMonthGrid.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The days a month grid shows, in reading order: the tail of the previous month, the month
/// itself, and the head of the next, padded to whole weeks. Which weekday a row starts on comes
/// from `calendar.firstWeekday`.
public struct KitoMonthGrid: Equatable, Sendable {
    /// One square of the grid.
    public struct Day: Identifiable, Hashable, Sendable {
        /// Midnight on this day.
        public let date: Date
        /// `false` for the leading and trailing days borrowed from neighbouring months.
        public let isInMonth: Bool
        public var id: Date { date }
    }

    /// Midnight on the first day of the month.
    public let month: Date
    /// Every square, a multiple of seven long.
    public let days: [Day]
    /// How many days of the previous month open the grid.
    public let leadingCount: Int
    /// How many days of the next month close it.
    public let trailingCount: Int

    /// - Parameter fixedSixWeeks: pad every month to six rows, so grids for different months are
    ///   the same height (what a paging calendar wants).
    public init(month date: Date, calendar: Calendar = .current, fixedSixWeeks: Bool = false) {
        let first = KitoCalendarMath.startOfMonth(for: date, calendar: calendar)
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekday = calendar.component(.weekday, from: first)
        let leading = ((weekday - calendar.firstWeekday) % 7 + 7) % 7
        let used = leading + dayCount
        let wholeWeeks = Int((Double(used) / 7).rounded(.up)) * 7
        let total = fixedSixWeeks ? max(42, wholeWeeks) : wholeWeeks

        month = first
        leadingCount = leading
        trailingCount = total - used
        days = (0..<total).map { index in
            Day(
                date: KitoCalendarMath.adding(days: index - leading, to: first, calendar: calendar),
                isInMonth: index >= leading && index < used
            )
        }
    }

    /// The days split into rows of seven.
    public var weeks: [[Day]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    /// Only the days that belong to the month.
    public var daysInMonth: [Day] { days.filter(\.isInMonth) }
}
