//
//  KitoMonthGridTests.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoCalendar

final class KitoMonthGridTests: XCTestCase {
    // September 2026 starts on a Tuesday and has 30 days.

    func testMondayFirstWeekPadsOneLeadingDay() {
        let calendar = makeCalendar(firstWeekday: 2)
        let grid = KitoMonthGrid(month: date(2026, 9, 17, calendar: calendar), calendar: calendar)

        XCTAssertEqual(grid.month, date(2026, 9, 1, calendar: calendar))
        XCTAssertEqual(grid.leadingCount, 1)
        XCTAssertEqual(grid.days.first?.date, date(2026, 8, 31, calendar: calendar))
        XCTAssertEqual(grid.days.first?.isInMonth, false)
        XCTAssertEqual(grid.days.count, 35)
        XCTAssertEqual(grid.trailingCount, 4)
        XCTAssertEqual(grid.days.last?.date, date(2026, 10, 4, calendar: calendar))
        XCTAssertEqual(grid.daysInMonth.count, 30)
    }

    func testSundayFirstWeekPadsTwoLeadingDays() {
        let calendar = makeCalendar(firstWeekday: 1)
        let grid = KitoMonthGrid(month: date(2026, 9, 1, calendar: calendar), calendar: calendar)

        XCTAssertEqual(grid.leadingCount, 2)
        XCTAssertEqual(grid.days.prefix(2).map(\.date), [date(2026, 8, 30, calendar: calendar), date(2026, 8, 31, calendar: calendar)])
        XCTAssertEqual(grid.days[2].date, date(2026, 9, 1, calendar: calendar))
        XCTAssertTrue(grid.days[2].isInMonth)
        XCTAssertEqual(grid.days.count, 35)
        XCTAssertEqual(grid.trailingCount, 3)
    }

    func testMonthStartingOnFirstWeekdayHasNoLeadingDays() {
        // February 2026 starts on a Sunday and has exactly four weeks.
        let calendar = makeCalendar(firstWeekday: 1)
        let grid = KitoMonthGrid(month: date(2026, 2, 10, calendar: calendar), calendar: calendar)

        XCTAssertEqual(grid.leadingCount, 0)
        XCTAssertEqual(grid.trailingCount, 0)
        XCTAssertEqual(grid.days.count, 28)
        XCTAssertEqual(grid.weeks.count, 4)
        XCTAssertTrue(grid.days.allSatisfy(\.isInMonth))
    }

    func testMonthNeedingSixRows() {
        // August 2026 starts on a Saturday: with Monday first it needs six rows.
        let calendar = makeCalendar(firstWeekday: 2)
        let grid = KitoMonthGrid(month: date(2026, 8, 1, calendar: calendar), calendar: calendar)

        XCTAssertEqual(grid.leadingCount, 5)
        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.weeks.count, 6)
    }

    func testFixedSixWeeksPadsShortMonths() {
        let calendar = makeCalendar(firstWeekday: 1)
        let grid = KitoMonthGrid(month: date(2026, 2, 1, calendar: calendar), calendar: calendar, fixedSixWeeks: true)

        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertEqual(grid.trailingCount, 14)
        XCTAssertEqual(grid.days.last?.date, date(2026, 3, 14, calendar: calendar))
    }

    func testWeeksAreRowsOfSevenInOrder() {
        let calendar = makeCalendar()
        let grid = KitoMonthGrid(month: date(2026, 10, 1, calendar: calendar), calendar: calendar)

        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(grid.weeks.flatMap { $0 }, grid.days)
        XCTAssertTrue(grid.weeks.allSatisfy { calendar.component(.weekday, from: $0[0].date) == 2 })
        XCTAssertEqual(Set(grid.days.map(\.date)).count, grid.days.count)
    }

    func testLeapYearFebruary() {
        let calendar = makeCalendar()
        let grid = KitoMonthGrid(month: date(2028, 2, 1, calendar: calendar), calendar: calendar)
        XCTAssertEqual(grid.daysInMonth.count, 29)
    }

    func testWeekdaySymbolsFollowFirstWeekday() {
        XCTAssertEqual(KitoCalendarMath.weekdaySymbols(calendar: makeCalendar(firstWeekday: 2), style: .short),
                       ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(KitoCalendarMath.weekdaySymbols(calendar: makeCalendar(firstWeekday: 1), style: .short),
                       ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        XCTAssertEqual(KitoCalendarMath.weekdaySymbols(calendar: makeCalendar(firstWeekday: 7), style: .veryShort).first, "S")
        XCTAssertEqual(KitoCalendarMath.weekdaySymbols(calendar: makeCalendar(firstWeekday: 2), style: .full).last, "Sunday")
    }

    func testWeekdaySymbolsUseLocale() {
        let symbols = KitoCalendarMath.weekdaySymbols(calendar: makeCalendar(firstWeekday: 2), locale: Locale(identifier: "sw_KE"), style: .full)
        XCTAssertEqual(symbols.count, 7)
        XCTAssertEqual(symbols.first, "Jumatatu")
    }
}
