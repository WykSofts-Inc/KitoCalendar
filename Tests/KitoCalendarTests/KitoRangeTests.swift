//
//  KitoRangeTests.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoCalendar

final class KitoRangeSelectionTests: XCTestCase {
    private let calendar = makeCalendar()

    func testFirstTapSetsStart() {
        var selection = KitoRangeSelection()
        selection.select(date(2026, 10, 12, 15, 30), calendar: calendar)

        XCTAssertEqual(selection.start, date(2026, 10, 12))
        XCTAssertNil(selection.end)
        XCTAssertTrue(selection.isAwaitingEnd)
        XCTAssertNil(selection.range)
    }

    func testSecondTapLaterCompletesRange() {
        var selection = KitoRangeSelection()
        selection.select(date(2026, 10, 12), calendar: calendar)
        selection.select(date(2026, 10, 18, 9), calendar: calendar)

        XCTAssertTrue(selection.isComplete)
        XCTAssertEqual(selection.range, KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)))
    }

    func testTapBeforeStartMovesStart() {
        var selection = KitoRangeSelection()
        selection.select(date(2026, 10, 12), calendar: calendar)
        selection.select(date(2026, 10, 9), calendar: calendar)

        XCTAssertEqual(selection.start, date(2026, 10, 9))
        XCTAssertNil(selection.end)
        XCTAssertTrue(selection.isAwaitingEnd)
    }

    func testTapOnCompleteRangeStartsOver() {
        var selection = KitoRangeSelection(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)), calendar: calendar)
        selection.select(date(2026, 10, 15), calendar: calendar)

        XCTAssertEqual(selection.start, date(2026, 10, 15))
        XCTAssertNil(selection.end)
    }

    func testTappingStartAgainClears() {
        var selection = KitoRangeSelection()
        selection.select(date(2026, 10, 12), calendar: calendar)
        selection.select(date(2026, 10, 12, 20), calendar: calendar)

        XCTAssertTrue(selection.isEmpty)
    }

    func testTappingStartAgainMakesOneDayRangeWhenAllowed() {
        var selection = KitoRangeSelection(allowsSingleDay: true)
        selection.select(date(2026, 10, 12), calendar: calendar)
        selection.select(date(2026, 10, 12), calendar: calendar)

        XCTAssertEqual(selection.range, KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 12)))
        XCTAssertEqual(selection.range?.nights(calendar: calendar), 0)
    }

    func testSetAndClear() {
        var selection = KitoRangeSelection()
        selection.set(KitoDateRange(start: date(2026, 10, 12, 14), end: date(2026, 10, 14, 10)), calendar: calendar)
        XCTAssertEqual(selection.start, date(2026, 10, 12))
        XCTAssertEqual(selection.end, date(2026, 10, 14))

        selection.clear()
        XCTAssertTrue(selection.isEmpty)
        XCTAssertFalse(selection.isComplete)
    }
}

final class KitoDateRangeTests: XCTestCase {
    private let calendar = makeCalendar()

    func testInitOrdersEnds() {
        let range = KitoDateRange(start: date(2026, 10, 18), end: date(2026, 10, 12))
        XCTAssertEqual(range.start, date(2026, 10, 12))
        XCTAssertEqual(range.end, date(2026, 10, 18))
    }

    func testNightsAndDays() {
        let range = KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18))
        XCTAssertEqual(range.nights(calendar: calendar), 6)
        XCTAssertEqual(range.dayCount(calendar: calendar), 7)
        XCTAssertEqual(KitoRangeUnit.nights.count(for: range, calendar: calendar), 6)
        XCTAssertEqual(KitoRangeUnit.days.count(for: range, calendar: calendar), 7)
    }

    func testNightsIgnoreTimeOfDay() {
        XCTAssertEqual(KitoCalendarMath.nights(from: date(2026, 10, 12, 23, 30), to: date(2026, 10, 13, 0, 15), calendar: calendar), 1)
        XCTAssertEqual(KitoCalendarMath.nights(from: date(2026, 10, 12, 8), to: date(2026, 10, 12, 22), calendar: calendar), 0)
    }

    func testNightsAcrossDaylightSavingChange() {
        // Clocks go back in London on 25 October 2026.
        let london = makeCalendar(timeZone: "Europe/London")
        let start = date(2026, 10, 24, calendar: london)
        let end = date(2026, 10, 27, calendar: london)
        XCTAssertEqual(KitoCalendarMath.nights(from: start, to: end, calendar: london), 3)
    }

    func testNightsAcrossMonthsAndYears() {
        XCTAssertEqual(KitoCalendarMath.nights(from: date(2026, 12, 28), to: date(2027, 1, 3), calendar: calendar), 6)
        XCTAssertEqual(KitoCalendarMath.nights(from: date(2026, 10, 18), to: date(2026, 10, 12), calendar: calendar), -6)
    }

    func testContainsIsInclusiveAndDayBased() {
        let range = KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18))
        XCTAssertTrue(range.contains(date(2026, 10, 12, 0, 1), calendar: calendar))
        XCTAssertTrue(range.contains(date(2026, 10, 18, 23, 59), calendar: calendar))
        XCTAssertFalse(range.contains(date(2026, 10, 19), calendar: calendar))
        XCTAssertFalse(range.contains(date(2026, 10, 11, 23, 59), calendar: calendar))
    }

    func testFormattingDayFirstLocale() {
        let gb = Locale(identifier: "en_GB")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)).formatted(calendar: calendar, locale: gb),
                       "12 – 18 Oct · 6 nights")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 28), end: date(2026, 11, 3)).formatted(calendar: calendar, locale: gb),
                       "28 Oct – 3 Nov · 6 nights")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 13)).formatted(calendar: calendar, locale: gb),
                       "12 – 13 Oct · 1 night")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)).formatted(unit: .days, calendar: calendar, locale: gb),
                       "12 – 18 Oct · 7 days")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)).formatted(unit: nil, calendar: calendar, locale: gb),
                       "12 – 18 Oct")
    }

    func testFormattingMonthFirstLocale() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(KitoDateRange(start: date(2026, 10, 12), end: date(2026, 10, 18)).formatted(calendar: calendar, locale: us),
                       "Oct 12 – 18 · 6 nights")
    }

    func testFormattingAcrossYearsIncludesYears() {
        let text = KitoDateRange(start: date(2026, 12, 30), end: date(2027, 1, 2)).formattedDates(calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text, "30 Dec 2026 – 2 Jan 2027")
    }

    func testFormattingSingleDay() {
        let text = KitoDateRange(start: date(2026, 10, 20), end: date(2026, 10, 20)).formatted(unit: .days, calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text, "20 Oct · 1 day")
    }
}

final class KitoDatePresetTests: XCTestCase {
    private let calendar = makeCalendar()
    // Wednesday 23 September 2026.
    private var wednesday: Date { date(2026, 9, 23, 10, calendar: calendar) }

    func testThisWeekendOnAWeekday() {
        let range = KitoDatePreset.thisWeekend.range(relativeTo: wednesday, calendar: calendar)
        XCTAssertEqual(range, KitoDateRange(start: date(2026, 9, 26), end: date(2026, 9, 27)))
    }

    func testThisWeekendOnSaturdayStartsToday() {
        let range = KitoDatePreset.thisWeekend.range(relativeTo: date(2026, 9, 26, 18), calendar: calendar)
        XCTAssertEqual(range, KitoDateRange(start: date(2026, 9, 26), end: date(2026, 9, 27)))
    }

    func testThisWeekendOnSundayNeverStartsInThePast() {
        let range = KitoDatePreset.thisWeekend.range(relativeTo: date(2026, 9, 27, 9), calendar: calendar)
        XCTAssertEqual(range.start, date(2026, 9, 27))
        XCTAssertGreaterThanOrEqual(range.end, range.start)
    }

    func testNextSevenDays() {
        let range = KitoDatePreset.nextSevenDays.range(relativeTo: wednesday, calendar: calendar)
        XCTAssertEqual(range, KitoDateRange(start: date(2026, 9, 23), end: date(2026, 9, 29)))
        XCTAssertEqual(range.dayCount(calendar: calendar), 7)
    }

    func testThisMonth() {
        let range = KitoDatePreset.thisMonth.range(relativeTo: wednesday, calendar: calendar)
        XCTAssertEqual(range, KitoDateRange(start: date(2026, 9, 23), end: date(2026, 9, 30)))
    }

    func testThisMonthOnLastDay() {
        let range = KitoDatePreset.thisMonth.range(relativeTo: date(2026, 2, 28, 12), calendar: calendar)
        XCTAssertEqual(range, KitoDateRange(start: date(2026, 2, 28), end: date(2026, 2, 28)))
    }

    func testStandardPresetsAndCustomPreset() {
        XCTAssertEqual(KitoDatePreset.standard.map(\.id), ["thisWeekend", "nextSevenDays", "thisMonth"])

        let mashujaa = KitoDatePreset("Mashujaa weekend", systemImage: "star") { _, calendar in
            KitoDateRange(start: date(2026, 10, 17, calendar: calendar), end: date(2026, 10, 20, calendar: calendar))
        }
        XCTAssertEqual(mashujaa.id, "Mashujaa weekend")
        XCTAssertEqual(mashujaa.range(relativeTo: wednesday, calendar: calendar).nights(calendar: calendar), 3)
    }
}
