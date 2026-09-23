//
//  KitoMonthCalendar.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A month grid you swipe through, with a today ring and a selection that glides between days.
/// Pick one day, several, or a range with start and end caps and a band that runs across weeks.
///
/// ```swift
/// KitoMonthCalendar(selection: $day)                 // one day
/// KitoMonthCalendar(selection: $days)                // Set<Date>
/// KitoMonthCalendar(range: $stay)                    // KitoRangeSelection
///     .disablesPastDates()
///     .events(bookings)
/// ```
///
/// The first weekday, locale and time zone come from `@Environment(\.calendar)` and
/// `@Environment(\.locale)`. Selected dates are always midnight in that calendar.
public struct KitoMonthCalendar: View {
    enum Mode {
        case single(Binding<Date?>)
        case multiple(Binding<Set<Date>>)
        case range(Binding<KitoRangeSelection>)
    }

    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    private let mode: Mode
    private let tint: Color?
    private var eventList: [KitoCalendarEvent] = []
    private var heatValues: [Date: Double] = [:]
    private var minimum: Date?
    private var maximum: Date?
    private var pastDisabled = false
    private var unavailableRule: ((Date) -> Bool)?
    private var monthChanged: ((Date) -> Void)?

    @State private var visibleMonth: Date?
    @State private var titleMonth: Date
    @State private var titleCountsDown = false
    @State private var backTaps = 0
    @State private var forwardTaps = 0
    @Namespace private var namespace
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 46

    /// Pick one day.
    public init(selection: Binding<Date?>, tint: Color? = nil) {
        self.init(mode: .single(selection), anchor: selection.wrappedValue, tint: tint)
    }

    /// Pick any number of days; tap again to remove one.
    public init(selection: Binding<Set<Date>>, tint: Color? = nil) {
        self.init(mode: .multiple(selection), anchor: selection.wrappedValue.min(), tint: tint)
    }

    /// Pick a range: tap a start, then an end. See `KitoRangeSelection` for the rules.
    public init(range: Binding<KitoRangeSelection>, tint: Color? = nil) {
        self.init(mode: .range(range), anchor: range.wrappedValue.start, tint: tint)
    }

    private init(mode: Mode, anchor: Date?, tint: Color?) {
        self.mode = mode
        self.tint = tint
        let month = KitoCalendarMath.startOfMonth(for: anchor ?? .now, calendar: .current)
        _visibleMonth = State(initialValue: month)
        _titleMonth = State(initialValue: month)
    }

    // MARK: Configuration

    /// Shows up to three coloured dots under each day that has events.
    public func events(_ events: [KitoCalendarEvent]) -> Self {
        var copy = self
        copy.eventList = events
        return copy
    }

    /// Shades each day by intensity (0…1), like a contribution graph. Keys can be any time on
    /// the day. Draws instead of dots on days that have a value.
    public func heatmap(_ values: [Date: Double]) -> Self {
        var copy = self
        copy.heatValues = values
        return copy
    }

    /// Days before this are faded and can't be picked; you can't page before its month.
    public func minimumDate(_ date: Date?) -> Self {
        var copy = self
        copy.minimum = date
        return copy
    }

    /// Days after this are faded and can't be picked; you can't page past its month.
    public func maximumDate(_ date: Date?) -> Self {
        var copy = self
        copy.maximum = date
        return copy
    }

    /// Fades days before today and stops them being picked.
    public func disablesPastDates(_ disables: Bool = true) -> Self {
        var copy = self
        copy.pastDisabled = disables
        return copy
    }

    /// Strikes through days your rule marks unavailable — sold out, closed, fully booked.
    public func unavailableDates(_ isUnavailable: @escaping (Date) -> Bool) -> Self {
        var copy = self
        copy.unavailableRule = isUnavailable
        return copy
    }

    /// Called with the first day of the month whenever the visible month changes.
    public func onMonthChange(_ action: @escaping (Date) -> Void) -> Self {
        var copy = self
        copy.monthChanged = action
        return copy
    }

    // MARK: Body

    private var rowSpacing: CGFloat { theme.spacing.xs }
    private var gridHeight: CGFloat { cellHeight * 6 + rowSpacing * 5 }

    public var body: some View {
        let months = monthList
        let context = makeContext()
        let shown = visibleMonth ?? titleMonth

        VStack(spacing: theme.spacing.md) {
            header(months: months, shown: shown)
            WeekdayHeader(calendar: calendar, locale: locale)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        MonthPage(
                            grid: KitoMonthGrid(month: month, calendar: calendar, fixedSixWeeks: true),
                            context: context,
                            isActive: month == shown,
                            cellHeight: cellHeight,
                            rowSpacing: rowSpacing
                        )
                        .containerRelativeFrame(.horizontal)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(context.format.monthTitle(month))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visibleMonth)
            .frame(height: gridHeight)
        }
        .onAppear { settleInitialMonth(months) }
        .onChange(of: visibleMonth) { old, new in
            guard let new else { return }
            titleCountsDown = (old ?? new) > new
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { titleMonth = new }
            monthChanged?(new)
        }
        .onChange(of: anchorMonth) { _, month in
            guard let month, month != visibleMonth, months.contains(month) else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { visibleMonth = month }
        }
        .sensoryFeedback(.selection, trigger: context.selection.fingerprint)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: titleMonth)
    }

    private func header(months: [Date], shown: Date) -> some View {
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let thisMonth = KitoCalendarMath.startOfMonth(for: .now, calendar: calendar)
        let index = months.firstIndex(of: shown)
        let canGoBack = index.map { $0 > 0 } ?? false
        let canGoForward = index.map { $0 < months.count - 1 } ?? false
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)

        return HStack(spacing: theme.spacing.sm) {
            Text(format.monthTitle(titleMonth))
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onSurface)
                .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: titleCountsDown))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if titleMonth != thisMonth, months.contains(thisMonth) {
                TodayCapsule(palette: palette) { scroll(to: thisMonth) }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            CalendarIconButton(systemImage: "chevron.left", label: "Previous month", bounce: backTaps) {
                guard let index, index > 0 else { return }
                backTaps += 1
                scroll(to: months[index - 1])
            }
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.35)
            CalendarIconButton(systemImage: "chevron.right", label: "Next month", bounce: forwardTaps) {
                guard let index, index < months.count - 1 else { return }
                forwardTaps += 1
                scroll(to: months[index + 1])
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.35)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: titleMonth)
    }

    // MARK: State

    private var snapshot: SelectionSnapshot {
        switch mode {
        case .single(let binding):
            return .single(binding.wrappedValue.map { calendar.startOfDay(for: $0) })
        case .multiple(let binding):
            return .multiple(Set(binding.wrappedValue.map { calendar.startOfDay(for: $0) }))
        case .range(let binding):
            let value = binding.wrappedValue
            return .range(start: value.start.map { calendar.startOfDay(for: $0) }, end: value.end.map { calendar.startOfDay(for: $0) })
        }
    }

    /// The month the selection lives in, so setting it from outside (a preset, a "tomorrow"
    /// button) brings that month into view.
    private var anchorMonth: Date? {
        let anchor: Date?
        switch mode {
        case .single(let binding): anchor = binding.wrappedValue
        case .multiple: anchor = nil
        case .range(let binding): anchor = binding.wrappedValue.start
        }
        return anchor.map { KitoCalendarMath.startOfMonth(for: $0, calendar: calendar) }
    }

    private var monthList: [Date] {
        let now = Date.now
        let anchor = anchorMonth ?? now
        let lower = minimum ?? min(KitoCalendarMath.adding(months: -60, to: now, calendar: calendar), anchor)
        let upper = maximum ?? max(KitoCalendarMath.adding(months: 60, to: now, calendar: calendar), anchor)
        let months = KitoCalendarMath.months(from: lower, to: max(lower, upper), calendar: calendar)
        return months.isEmpty ? [KitoCalendarMath.startOfMonth(for: lower, calendar: calendar)] : months
    }

    private func makeContext() -> DayContext {
        let today = calendar.startOfDay(for: .now)
        let minDay = minimum.map { calendar.startOfDay(for: $0) }
        let maxDay = maximum.map { calendar.startOfDay(for: $0) }
        let pastDisabled = pastDisabled
        let heat = Dictionary(
            heatValues.map { (calendar.startOfDay(for: $0.key), min(max($0.value, 0), 1)) },
            uniquingKeysWith: { max($0, $1) }
        )
        return DayContext(
            calendar: calendar,
            format: CalendarFormat(calendar: calendar, locale: locale),
            palette: CalendarPalette(theme: theme, tint: tint, environment: environment),
            today: today,
            eventsByDay: KitoCalendarMath.eventsByDay(eventList, calendar: calendar),
            heat: heat,
            selection: snapshot,
            isOutOfBounds: { day in
                (pastDisabled && day < today) || (minDay.map { day < $0 } ?? false) || (maxDay.map { day > $0 } ?? false)
            },
            isUnavailable: unavailableRule ?? { _ in false },
            namespace: namespace,
            reduceMotion: reduceMotion,
            onTap: tap
        )
    }

    private func tap(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) {
            switch mode {
            case .single(let binding):
                binding.wrappedValue = day
            case .multiple(let binding):
                var dates = binding.wrappedValue
                let existing = dates.filter { calendar.isDate($0, inSameDayAs: day) }
                if existing.isEmpty { dates.insert(day) } else { dates.subtract(existing) }
                binding.wrappedValue = dates
            case .range(let binding):
                var selection = binding.wrappedValue
                selection.select(day, calendar: calendar)
                binding.wrappedValue = selection
            }
        }
    }

    private func scroll(to month: Date) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { visibleMonth = month }
    }

    /// Lines the first page up with the environment's calendar and the date bounds.
    private func settleInitialMonth(_ months: [Date]) {
        let wanted = KitoCalendarMath.startOfMonth(for: anchorMonth ?? visibleMonth ?? .now, calendar: calendar)
        let target = months.contains(wanted) ? wanted : (months.first { $0 >= wanted } ?? months.last ?? wanted)
        if visibleMonth != target { visibleMonth = target }
        titleMonth = target
    }
}
