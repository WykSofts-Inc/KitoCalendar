//
//  KitoYearOverview.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Twelve mini months for a year at a glance. Tap one and it grows into a full month you can pick
/// a day from, with that day's events underneath; the back button shrinks it into place again.
///
/// ```swift
/// KitoYearOverview(selection: $day)
///     .events(holidays)
/// ```
public struct KitoYearOverview: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    @Binding private var selection: Date?
    private let tint: Color?
    private var eventList: [KitoCalendarEvent] = []

    @State private var year: Int
    @State private var focusedMonth: Date?
    @Namespace private var namespace
    @ScaledMetric(relativeTo: .caption) private var miniRowHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 44

    /// - Parameter year: the year shown first; defaults to the selection's year, or this year.
    public init(year: Int? = nil, selection: Binding<Date?>, tint: Color? = nil) {
        _selection = selection
        self.tint = tint
        let initial = year ?? Calendar.current.component(.year, from: selection.wrappedValue ?? .now)
        _year = State(initialValue: initial)
    }

    /// Marks days with events in the mini months and lists them under the zoomed month.
    public func events(_ events: [KitoCalendarEvent]) -> Self {
        var copy = self
        copy.eventList = events
        return copy
    }

    public var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let byDay = KitoCalendarMath.eventsByDay(eventList, calendar: calendar)

        ZStack(alignment: .top) {
            if let focusedMonth {
                detail(for: focusedMonth, palette: palette, format: format, byDay: byDay)
                    .transition(.opacity)
            } else {
                overview(palette: palette, format: format, byDay: byDay)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: focusedMonth)
    }

    // MARK: Year

    private func overview(palette: CalendarPalette, format: CalendarFormat, byDay: [Date: [KitoCalendarEvent]]) -> some View {
        let months = monthsOfYear
        let thisMonth = KitoCalendarMath.startOfMonth(for: .now, calendar: calendar)

        return VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(spacing: theme.spacing.sm) {
                Text(String(year))
                    .font(theme.typography.displayMedium)
                    .foregroundStyle(theme.colors.onSurface)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(year)))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                CalendarIconButton(systemImage: "chevron.backward", label: "Previous year", bounce: year) { changeYear(by: -1) }
                CalendarIconButton(systemImage: "chevron.forward", label: "Next year", bounce: year) { changeYear(by: 1) }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.sm), count: 3), spacing: theme.spacing.sm) {
                ForEach(months, id: \.self) { month in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)) { focusedMonth = month }
                    } label: {
                        miniMonth(month, isCurrent: month == thisMonth, palette: palette, format: format, byDay: byDay)
                    }
                    .buttonStyle(KitoPressStyle(scale: 0.95))
                    .accessibilityLabel(format.monthTitle(month))
                    .accessibilityValue(eventDaysDescription(in: month, byDay: byDay))
                    .accessibilityHint("Opens the month")
                }
            }
        }
    }

    private func miniMonth(_ month: Date, isCurrent: Bool, palette: CalendarPalette, format: CalendarFormat, byDay: [Date: [KitoCalendarEvent]]) -> some View {
        let grid = KitoMonthGrid(month: month, calendar: calendar, fixedSixWeeks: true)
        let today = calendar.startOfDay(for: .now)
        let selectedDay = selection.map { calendar.startOfDay(for: $0) }

        return VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(format.shortMonth(month))
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(isCurrent ? palette.accent : theme.colors.onSurface)
                .lineLimit(1)
            VStack(spacing: 1) {
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week) { day in
                            miniDay(day, today: today, selected: selectedDay, events: byDay[day.date] ?? [], palette: palette, format: format)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacing.xs + 2)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .fill(theme.colors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                        .strokeBorder(isCurrent ? palette.accent.opacity(0.5) : theme.colors.border, lineWidth: isCurrent ? 1.5 : 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                .matchedGeometryEffect(id: month, in: namespace)
        }
    }

    @ViewBuilder
    private func miniDay(_ day: KitoMonthGrid.Day, today: Date, selected: Date?, events: [KitoCalendarEvent], palette: CalendarPalette, format: CalendarFormat) -> some View {
        if day.isInMonth {
            let isToday = day.date == today
            let isSelected = day.date == selected
            // One uniform scale for every number (minimumScaleFactor would shrink "28" more
            // than "8"); scaleEffect leaves the cell size alone.
            Text(format.day(day.date))
                .font(theme.typography.caption.weight(isToday ? .bold : .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .scaleEffect(0.72)
                .foregroundStyle(isToday ? palette.onAccent : theme.colors.onSurface.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: miniRowHeight)
                .background {
                    if isToday {
                        Circle().fill(palette.accent).padding(-1)
                    } else if let color = events.first?.color {
                        Circle().fill(color.opacity(0.28)).padding(-1)
                    }
                }
                .overlay {
                    if isSelected, !isToday {
                        Circle().strokeBorder(palette.accent, lineWidth: 1).padding(-1)
                    }
                }
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: miniRowHeight)
        }
    }

    // MARK: Month

    private func detail(for month: Date, palette: CalendarPalette, format: CalendarFormat, byDay: [Date: [KitoCalendarEvent]]) -> some View {
        let context = DayContext(
            calendar: calendar,
            format: format,
            palette: palette,
            today: calendar.startOfDay(for: .now),
            eventsByDay: byDay,
            heat: [:],
            selection: .single(selection.map { calendar.startOfDay(for: $0) }),
            isOutOfBounds: { _ in false },
            isUnavailable: { _ in false },
            namespace: namespace,
            reduceMotion: reduceMotion,
            onTap: { date in
                withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) { selection = date }
            }
        )
        let selectedEvents = selection.flatMap { byDay[calendar.startOfDay(for: $0)] } ?? []

        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.sm) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) { focusedMonth = nil }
                } label: {
                    Label(String(year), systemImage: "chevron.backward")
                        .font(theme.typography.label.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.vertical, theme.spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(KitoPressStyle())
                .accessibilityLabel("Back to \(year)")
                Spacer(minLength: 0)
                CalendarIconButton(systemImage: "chevron.backward", label: "Previous month") { moveFocus(by: -1) }
                CalendarIconButton(systemImage: "chevron.forward", label: "Next month") { moveFocus(by: 1) }
            }
            Text(format.monthName(month))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.onSurface)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .accessibilityAddTraits(.isHeader)
            WeekdayHeader(calendar: calendar, locale: locale)
            MonthPage(
                grid: KitoMonthGrid(month: month, calendar: calendar, fixedSixWeeks: true),
                context: context,
                isActive: true,
                cellHeight: cellHeight,
                rowSpacing: theme.spacing.xxs
            )
            if !selectedEvents.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    ForEach(selectedEvents.prefix(3)) { event in
                        HStack(spacing: theme.spacing.sm) {
                            Capsule().fill(event.color).frame(width: 4, height: 18)
                            Text(event.title)
                                .font(theme.typography.label)
                                .foregroundStyle(theme.colors.onSurface)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(event.isAllDay ? "All day" : format.time(event.start))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(theme.spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                .fill(theme.colors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                        .strokeBorder(theme.colors.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                .matchedGeometryEffect(id: month, in: namespace)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: selectedEvents.map(\.id))
    }

    // MARK: State

    private var monthsOfYear: [Date] {
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        return (0..<12).map { KitoCalendarMath.adding(months: $0, to: first, calendar: calendar) }
    }

    private func changeYear(by delta: Int) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { year += delta }
    }

    private func moveFocus(by delta: Int) {
        guard let focusedMonth else { return }
        let next = KitoCalendarMath.adding(months: delta, to: focusedMonth, calendar: calendar)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
            self.focusedMonth = next
            year = calendar.component(.year, from: next)
        }
    }

    private func eventDaysDescription(in month: Date, byDay: [Date: [KitoCalendarEvent]]) -> String {
        let count = byDay.keys.filter { KitoCalendarMath.startOfMonth(for: $0, calendar: calendar) == month }.count
        switch count {
        case 0: return ""
        case 1: return "1 day with events"
        default: return "\(count) days with events"
        }
    }
}
