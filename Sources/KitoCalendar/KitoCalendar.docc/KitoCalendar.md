# ``KitoCalendar``

Month, week, year, time slot, timeline and agenda calendars for SwiftUI.

## Overview

KitoCalendar provides a swipeable month grid with single, multiple and range
selection, a week strip, a year overview that zooms into a month, booking time
slots, a day timeline with a live "now" line, an agenda with sticky day headers,
and a date range field with presets.

Every view reads colours, spacing, radii and type from `@Environment(\.kitoTheme)`,
and the first weekday, locale and time zone from `@Environment(\.calendar)` and
`@Environment(\.locale)`. Most views take an optional `tint:` that replaces the
theme's primary colour, and animations fall back to plain changes under Reduce
Motion.

```swift
@State private var stay = KitoRangeSelection()

var body: some View {
    VStack {
        KitoMonthCalendar(range: $stay)
            .disablesPastDates()
            .events(bookings)

        if let range = stay.range {
            Text(range.formatted())   // "12 – 18 Oct · 6 nights"
        }
    }
}
```

The date logic behind the views — month grids, event layout, week and night
calculations — is exposed as pure types such as ``KitoMonthGrid``,
``KitoEventLayout`` and ``KitoCalendarMath``. The kit only shows the events you
pass in and does not read the system calendar, so no Info.plist keys or
capabilities are needed.

## Topics

### Month and Year

- ``KitoMonthCalendar``
- ``KitoYearOverview``
- ``KitoWeekStrip``
- ``KitoWeekdayStyle``

### Date Ranges

- ``KitoDateRangeBar``
- ``KitoDateRange``
- ``KitoRangeSelection``
- ``KitoRangeUnit``
- ``KitoDatePreset``

### Time Slots

- ``KitoTimeSlotPicker``
- ``KitoTimeSlot``
- ``KitoSlotSchedule``
- ``KitoClockTime``
- ``KitoDayPeriod``

### Timeline and Agenda

- ``KitoDayTimeline``
- ``KitoAgendaList``
- ``KitoAgendaDay``
- ``KitoCalendarEvent``

### Calendar Logic

- ``KitoMonthGrid``
- ``KitoEventLayout``
- ``KitoEventPlacement``
- ``KitoCalendarMath``
