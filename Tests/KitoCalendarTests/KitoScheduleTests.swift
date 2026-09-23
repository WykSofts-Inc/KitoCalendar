//
//  KitoScheduleTests.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoCalendar

final class KitoSlotScheduleTests: XCTestCase {
    private let calendar = makeCalendar()
    private var day: Date { date(2026, 9, 24, 13, calendar: calendar) }

    func testBackToBackSlots() {
        let slots = KitoSlotSchedule(opens: .init(9), closes: .init(12), duration: 30).slots(on: day, calendar: calendar)

        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(slots.first?.start, date(2026, 9, 24, 9))
        XCTAssertEqual(slots.first?.end, date(2026, 9, 24, 9, 30))
        XCTAssertEqual(slots.last?.start, date(2026, 9, 24, 11, 30))
        XCTAssertEqual(slots.last?.end, date(2026, 9, 24, 12))
        XCTAssertTrue(slots.allSatisfy(\.isAvailable))
    }

    func testOverlappingIntervalNeverRunsPastClosing() {
        let slots = KitoSlotSchedule(opens: .init(9), closes: .init(12), duration: 45, interval: 15).slots(on: day, calendar: calendar)

        XCTAssertEqual(slots.count, 10)
        XCTAssertEqual(slots[1].start, date(2026, 9, 24, 9, 15))
        XCTAssertEqual(slots.last?.start, date(2026, 9, 24, 11, 15))
        XCTAssertTrue(slots.allSatisfy { $0.end <= date(2026, 9, 24, 12) })
    }

    func testHalfHourOpeningAndGap() {
        let slots = KitoSlotSchedule(opens: .init(8, 30), closes: .init(10), duration: 30, interval: 45).slots(on: day, calendar: calendar)
        XCTAssertEqual(slots.map(\.start), [date(2026, 9, 24, 8, 30), date(2026, 9, 24, 9, 15)])
    }

    func testBookedSlotsAreUnavailable() {
        let booked = [DateInterval(start: date(2026, 9, 24, 10), end: date(2026, 9, 24, 10, 45))]
        let slots = KitoSlotSchedule(opens: .init(9), closes: .init(12), duration: 30).slots(on: day, booked: booked, calendar: calendar)
        let unavailable = slots.filter { !$0.isAvailable }.map(\.start)

        XCTAssertEqual(unavailable, [date(2026, 9, 24, 10), date(2026, 9, 24, 10, 30)])
    }

    func testTouchingBookingDoesNotBlockNeighbours() {
        let booked = [DateInterval(start: date(2026, 9, 24, 9, 30), end: date(2026, 9, 24, 10))]
        let slots = KitoSlotSchedule(opens: .init(9), closes: .init(11), duration: 30).slots(on: day, booked: booked, calendar: calendar)
        XCTAssertEqual(slots.map(\.isAvailable), [true, false, true, true])
    }

    func testPastSlotsAreUnavailable() {
        let slots = KitoSlotSchedule(opens: .init(9), closes: .init(12), duration: 60)
            .slots(on: day, notBefore: date(2026, 9, 24, 10, 5), calendar: calendar)
        XCTAssertEqual(slots.map(\.isAvailable), [false, false, true])
    }

    func testClosingAtMidnight() {
        let slots = KitoSlotSchedule(opens: .init(22), closes: .init(24), duration: 60).slots(on: day, calendar: calendar)
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots.last?.end, date(2026, 9, 25))
        XCTAssertEqual(slots.first?.period, .evening)
    }

    func testInvalidSchedulesProduceNoSlots() {
        XCTAssertTrue(KitoSlotSchedule(duration: 0).slots(on: day, calendar: calendar).isEmpty)
        XCTAssertTrue(KitoSlotSchedule(duration: 30, interval: 0).slots(on: day, calendar: calendar).isEmpty)
        XCTAssertTrue(KitoSlotSchedule(opens: .init(17), closes: .init(9)).slots(on: day, calendar: calendar).isEmpty)
        XCTAssertTrue(KitoSlotSchedule(opens: .init(9), closes: .init(9, 20), duration: 30).slots(on: day, calendar: calendar).isEmpty)
    }

    func testPeriods() {
        XCTAssertEqual(KitoDayPeriod(hour: 0), .morning)
        XCTAssertEqual(KitoDayPeriod(hour: 11), .morning)
        XCTAssertEqual(KitoDayPeriod(hour: 12), .afternoon)
        XCTAssertEqual(KitoDayPeriod(hour: 16), .afternoon)
        XCTAssertEqual(KitoDayPeriod(hour: 17), .evening)
        XCTAssertEqual(KitoDayPeriod(hour: 23), .evening)

        let slots = KitoSlotSchedule(opens: .init(11), closes: .init(18), duration: 60).slots(on: day, calendar: calendar)
        XCTAssertEqual(slots.map(\.period), [.morning, .afternoon, .afternoon, .afternoon, .afternoon, .afternoon, .evening])
    }

    func testClockTimeOrdering() {
        XCTAssertLessThan(KitoClockTime(8, 30), KitoClockTime(9))
        XCTAssertEqual(KitoClockTime(9, 15).minutesSinceMidnight, 555)
    }
}

final class KitoEventLayoutTests: XCTestCase {
    private func t(_ hour: Int, _ minute: Int = 0) -> Date { date(2026, 9, 23, hour, minute) }

    private func columns(_ placements: [KitoEventPlacement]) -> [String: (Int, Int)] {
        Dictionary(uniqueKeysWithValues: placements.map { ($0.event.id, ($0.column, $0.columnCount)) })
    }

    func testSeparateEventsTakeFullWidth() {
        let result = columns(KitoEventLayout.placements(for: [event("a", t(9), t(10)), event("b", t(10), t(11))]))
        XCTAssertEqual(result["a"]?.0, 0); XCTAssertEqual(result["a"]?.1, 1)
        XCTAssertEqual(result["b"]?.0, 0); XCTAssertEqual(result["b"]?.1, 1)
    }

    func testTwoOverlappingEventsSplit() {
        let result = columns(KitoEventLayout.placements(for: [event("a", t(9), t(10)), event("b", t(9, 30), t(11))]))
        XCTAssertEqual(result["a"]?.0, 0); XCTAssertEqual(result["a"]?.1, 2)
        XCTAssertEqual(result["b"]?.0, 1); XCTAssertEqual(result["b"]?.1, 2)
    }

    func testFreedColumnIsReused() {
        // a 9–12 spans; b 9–10 then c 10–11 share the second column.
        let result = columns(KitoEventLayout.placements(for: [event("c", t(10), t(11)), event("a", t(9), t(12)), event("b", t(9), t(10))]))
        XCTAssertEqual(result["a"]?.0, 0)
        XCTAssertEqual(result["b"]?.0, 1)
        XCTAssertEqual(result["c"]?.0, 1)
        XCTAssertTrue(result.values.allSatisfy { $0.1 == 2 })
    }

    func testChainedOverlapsShareOneGroup() {
        // a overlaps b, b overlaps c, a and c don't touch: still one group of two columns.
        let result = columns(KitoEventLayout.placements(for: [event("a", t(9), t(10)), event("b", t(9, 30), t(10, 30)), event("c", t(10), t(11))]))
        XCTAssertEqual(result["a"]?.0, 0)
        XCTAssertEqual(result["b"]?.0, 1)
        XCTAssertEqual(result["c"]?.0, 0)
        XCTAssertTrue(result.values.allSatisfy { $0.1 == 2 })
    }

    func testThreeWayOverlapThenNewGroup() {
        let result = columns(KitoEventLayout.placements(for: [
            event("a", t(9), t(11)), event("b", t(9), t(10)), event("c", t(9, 30), t(10, 30)),
            event("d", t(13), t(14)),
        ]))
        XCTAssertEqual(Set(["a", "b", "c"].compactMap { result[$0]?.0 }), [0, 1, 2])
        XCTAssertTrue(["a", "b", "c"].allSatisfy { result[$0]?.1 == 3 })
        XCTAssertEqual(result["d"]?.0, 0)
        XCTAssertEqual(result["d"]?.1, 1)
    }

    func testLongerEventGoesLeftWhenStartsTie() {
        let result = columns(KitoEventLayout.placements(for: [event("short", t(9), t(9, 30)), event("long", t(9), t(12))]))
        XCTAssertEqual(result["long"]?.0, 0)
        XCTAssertEqual(result["short"]?.0, 1)
    }

    func testMinimumDurationSeparatesShortEvents() {
        let zero = event("zero", t(9), t(9))
        let next = event("next", t(9, 10), t(10))
        XCTAssertEqual(columns(KitoEventLayout.placements(for: [zero, next]))["next"]?.1, 1)
        XCTAssertEqual(columns(KitoEventLayout.placements(for: [zero, next], minimumDuration: 20 * 60))["next"]?.1, 2)
    }

    func testEveryEventIsPlacedOnce() {
        let events = (0..<20).map { event("e\($0)", t(8 + $0 % 6, ($0 * 7) % 60), t(9 + $0 % 6, ($0 * 11) % 60)) }
        let placements = KitoEventLayout.placements(for: events)
        XCTAssertEqual(placements.count, events.count)
        XCTAssertEqual(Set(placements.map(\.event.id)).count, events.count)
        XCTAssertTrue(placements.allSatisfy { $0.column < $0.columnCount })
        XCTAssertTrue(KitoEventLayout.placements(for: []).isEmpty)
    }

    func testNoTwoOverlappingEventsShareAColumn() {
        let events = (0..<30).map { event("e\($0)", t(8 + ($0 * 5) % 9, ($0 * 13) % 60), t(9 + ($0 * 5) % 9, ($0 * 17) % 60)) }
        let placements = KitoEventLayout.placements(for: events)
        for a in placements {
            for b in placements where a.event.id < b.event.id && a.column == b.column {
                let overlaps = a.event.start < b.event.end && b.event.start < a.event.end
                XCTAssertFalse(overlaps, "\(a.event.id) and \(b.event.id) overlap in column \(a.column)")
            }
        }
    }
}

final class KitoCalendarMathTests: XCTestCase {
    func testStartOfWeekHonoursFirstWeekday() {
        let wednesday = date(2026, 9, 23, 15)
        XCTAssertEqual(KitoCalendarMath.startOfWeek(containing: wednesday, calendar: makeCalendar(firstWeekday: 1)), date(2026, 9, 20))
        XCTAssertEqual(KitoCalendarMath.startOfWeek(containing: wednesday, calendar: makeCalendar(firstWeekday: 2)), date(2026, 9, 21))
        XCTAssertEqual(KitoCalendarMath.startOfWeek(containing: wednesday, calendar: makeCalendar(firstWeekday: 7)), date(2026, 9, 19))
    }

    func testStartOfWeekOnFirstWeekdayIsSameDay() {
        let monday = date(2026, 9, 21, 8)
        XCTAssertEqual(KitoCalendarMath.startOfWeek(containing: monday, calendar: makeCalendar(firstWeekday: 2)), date(2026, 9, 21))
    }

    func testWeekAcrossMonthAndYear() {
        let week = KitoCalendarMath.week(containing: date(2027, 1, 1), calendar: makeCalendar(firstWeekday: 2))
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, date(2026, 12, 28))
        XCTAssertEqual(week.last, date(2027, 1, 3))
    }

    func testStartOfMonth() {
        XCTAssertEqual(KitoCalendarMath.startOfMonth(for: date(2026, 9, 23, 18), calendar: makeCalendar()), date(2026, 9, 1))
    }

    func testMonthsAndWeeksLists() {
        let calendar = makeCalendar()
        let months = KitoCalendarMath.months(from: date(2026, 11, 20), to: date(2027, 2, 3), calendar: calendar)
        XCTAssertEqual(months, [date(2026, 11, 1), date(2026, 12, 1), date(2027, 1, 1), date(2027, 2, 1)])

        let weeks = KitoCalendarMath.weeks(from: date(2026, 9, 23), to: date(2026, 10, 7), calendar: calendar)
        XCTAssertEqual(weeks, [date(2026, 9, 21), date(2026, 9, 28), date(2026, 10, 5)])
    }

    func testDaysSpannedByEvent() {
        let calendar = makeCalendar()
        XCTAssertEqual(KitoCalendarMath.days(spannedBy: event("a", date(2026, 9, 23, 9), date(2026, 9, 23, 10)), calendar: calendar), [date(2026, 9, 23)])
        XCTAssertEqual(KitoCalendarMath.days(spannedBy: event("b", date(2026, 9, 23, 22), date(2026, 9, 25, 1)), calendar: calendar),
                       [date(2026, 9, 23), date(2026, 9, 24), date(2026, 9, 25)])
        // Ends exactly at midnight: doesn't touch the next day.
        XCTAssertEqual(KitoCalendarMath.days(spannedBy: event("c", date(2026, 9, 23), date(2026, 9, 24), isAllDay: true), calendar: calendar), [date(2026, 9, 23)])
        // Zero length: the day it starts.
        XCTAssertEqual(KitoCalendarMath.days(spannedBy: event("d", date(2026, 9, 23, 12), date(2026, 9, 23, 12)), calendar: calendar), [date(2026, 9, 23)])
    }

    func testAgendaGroupsSortsAndRepeatsMultiDayEvents() {
        let calendar = makeCalendar()
        let safari = event("Maasai Mara safari", date(2026, 9, 24), date(2026, 9, 26), isAllDay: true)
        let standup = event("Standup", date(2026, 9, 24, 9), date(2026, 9, 24, 9, 15))
        let breakfast = event("Breakfast", date(2026, 9, 24, 7), date(2026, 9, 24, 8))
        let flight = event("Flight", date(2026, 9, 23, 18), date(2026, 9, 23, 20))

        let days = KitoCalendarMath.agenda(for: [standup, safari, flight, breakfast], calendar: calendar)
        XCTAssertEqual(days.map(\.date), [date(2026, 9, 23), date(2026, 9, 24), date(2026, 9, 25)])
        XCTAssertEqual(days[0].events.map(\.id), ["Flight"])
        XCTAssertEqual(days[1].events.map(\.id), ["Maasai Mara safari", "Breakfast", "Standup"])
        XCTAssertEqual(days[2].events.map(\.id), ["Maasai Mara safari"])
        XCTAssertTrue(KitoCalendarMath.agenda(for: [], calendar: calendar).isEmpty)
    }

    func testEventsByDay() {
        let calendar = makeCalendar()
        let byDay = KitoCalendarMath.eventsByDay([
            event("a", date(2026, 9, 23, 9), date(2026, 9, 23, 10)),
            event("b", date(2026, 9, 23, 11), date(2026, 9, 24, 2)),
        ], calendar: calendar)
        XCTAssertEqual(byDay[date(2026, 9, 23)]?.map(\.id), ["a", "b"])
        XCTAssertEqual(byDay[date(2026, 9, 24)]?.map(\.id), ["b"])
        XCTAssertNil(byDay[date(2026, 9, 25)])
    }

    func testEventClampsEndAndReportsOngoing() {
        let e = KitoCalendarEvent(title: "Backwards", start: date(2026, 9, 23, 10), end: date(2026, 9, 23, 9))
        XCTAssertEqual(e.end, e.start)
        XCTAssertEqual(e.duration, 0)

        let meeting = event("m", date(2026, 9, 23, 10), date(2026, 9, 23, 11))
        XCTAssertTrue(meeting.isOngoing(at: date(2026, 9, 23, 10, 30)))
        XCTAssertFalse(meeting.isOngoing(at: date(2026, 9, 23, 11)))
    }
}
