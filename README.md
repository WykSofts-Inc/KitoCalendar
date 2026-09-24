# KitoCalendar

**[Documentation](https://wyksofts-inc.github.io/KitoCalendar/documentation/kitocalendar/)**

Calendars for SwiftUI: a month grid you swipe through, with single, multiple and range selection,
a week strip, a year overview that zooms into a month, booking time slots, a day timeline with a
live "now" line, an agenda with sticky day headers, and a date range field with presets. Part of the
[Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

Everything reads colours, spacing, radii and type from `@Environment(\.kitoTheme)`, and the first
weekday, locale and time zone from `@Environment(\.calendar)` and `@Environment(\.locale)`. Most
views take an optional `tint:` that replaces the theme's primary colour. Animations fall back to
plain changes under Reduce Motion.

## Month calendar

```swift
@State private var day: Date?
@State private var days: Set<Date> = []
@State private var stay = KitoRangeSelection()

KitoMonthCalendar(selection: $day)                  // one day
KitoMonthCalendar(selection: $days, tint: .green)   // several days
KitoMonthCalendar(range: $stay)                     // a range with start and end caps
    .disablesPastDates()

if let range = stay.range {
    Text(range.formatted())                         // "12 – 18 Oct · 6 nights"
}
```

Swipe or use the chevrons to change month; the title rolls to the new one and a "Today" capsule
brings you back. Set the selection from outside (a preset, a "tomorrow" button) and the calendar
pages to it.

```swift
KitoMonthCalendar(selection: $day)
    .events(events)                         // up to three coloured dots per day
    .heatmap(kilometresByDay)               // or shade days by intensity, 0…1
    .minimumDate(.now)
    .maximumDate(in45Days)
    .unavailableDates { soldOut.contains($0) }   // struck through
    .onMonthChange { month in load(month) }
```

Range taps follow the booking-app rules: the first tap sets the start, a later day sets the end, a
day before the start moves the start, tapping the start again clears it, and a tap on a finished
range starts a new one. `KitoRangeSelection(allowsSingleDay: true)` lets the second tap on the start
pick a one-day range.

## Date range field

```swift
@State private var stay: KitoDateRange?

KitoDateRangeBar(range: $stay, title: "Check-in – Check-out")
KitoDateRangeBar(range: $trip, placeholder: "Any week", unit: .days, style: .chip)
```

Tapping opens a sheet with preset chips, a range calendar and Apply. Past days are blocked unless you
add `.allowsPastDates()`. Presets are resolved when they're tapped, so they stay right tomorrow:

```swift
let mashujaa = KitoDatePreset("Mashujaa weekend", systemImage: "star.fill") { now, calendar in
    KitoDateRange(start: oct19, end: oct21)
}
KitoDateRangeBar(range: $weekend)
    .presets([.thisWeekend, mashujaa, .nextSevenDays, .thisMonth])
```

## Week strip and year overview

```swift
@State private var day = Date.now
KitoWeekStrip(selection: $day)
    .events(classes)
    .disablesPastDates()
    .showsHeader(false)

KitoYearOverview(selection: $picked)     // 12 mini months; tap one to zoom in
    .events(holidays)
```

Swiping the week strip keeps the same weekday selected in the new week.

## Time slots

```swift
let slots = KitoSlotSchedule(opens: .init(8, 30), closes: .init(18), duration: 45, interval: 15)
    .slots(on: day, booked: bookings, notBefore: .now)

KitoTimeSlotPicker(slots: slots, selection: $slot)
    .showsEndTime()
```

Slots are grouped into Morning, Afternoon and Evening. A slot that overlaps a booking or starts
before `notBefore` is struck out and can't be picked.

## Day timeline and agenda

```swift
KitoDayTimeline(day: .now, events: meetings) { event in opened = event }
    .visibleHours(7...22)
    .hourHeight(56)

KitoAgendaList(events: events) { event in opened = event }
    .emptyState(title: "Hakuna matata", message: "Nothing planned this week.")
```

The timeline puts overlapping events side by side and draws a red line at the current time that
moves as the minutes pass. The agenda groups events by day under sticky headers, repeats multi-day
events on each day and marks the ones happening now.

## Models and logic

```swift
KitoCalendarEvent(title: "Chama meeting", start: start, end: end, color: .green, location: "Lavington")

KitoMonthGrid(month: date, calendar: calendar, fixedSixWeeks: true).weeks   // leading/trailing days
KitoEventLayout.placements(for: events)          // column and column count per event
KitoCalendarMath.startOfWeek(containing: date, calendar: calendar)
KitoCalendarMath.nights(from: checkIn, to: checkOut, calendar: calendar)
KitoCalendarMath.agenda(for: events, calendar: calendar)
```

All of it is pure and covered by unit tests.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoCalendar.git", from: "0.1.0")
```

No Info.plist keys or capabilities are needed: the kit shows the events you pass in and doesn't read
the system calendar.

## License

MIT — see [LICENSE](LICENSE).
