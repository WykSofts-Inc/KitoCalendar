//
//  KitoWeekStrip.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A week of day pills you swipe through, the kind that sits above a schedule or a booking list.
/// The selected pill glides between days; swiping to another week moves the selection to the same
/// weekday there, and a "Today" capsule appears whenever you've wandered off.
///
/// ```swift
/// @State private var day = Date.now
/// KitoWeekStrip(selection: $day)
///     .events(classes)
/// ```
public struct KitoWeekStrip: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    @Binding private var selection: Date
    private let tint: Color?
    private var eventList: [KitoCalendarEvent] = []
    private var pastDisabled = false
    private var showsHeader = true

    @State private var visibleWeek: Date?
    @State private var titleDate: Date
    @State private var titleCountsDown = false
    @State private var programmaticTarget: Date?
    @Namespace private var namespace
    @ScaledMetric(relativeTo: .body) private var pillHeight: CGFloat = 76

    public init(selection: Binding<Date>, tint: Color? = nil) {
        _selection = selection
        self.tint = tint
        let week = KitoCalendarMath.startOfWeek(containing: selection.wrappedValue, calendar: .current)
        _visibleWeek = State(initialValue: week)
        _titleDate = State(initialValue: selection.wrappedValue)
    }

    /// Puts a dot under each day that has events.
    public func events(_ events: [KitoCalendarEvent]) -> Self {
        var copy = self
        copy.eventList = events
        return copy
    }

    /// Fades days before today and stops them being picked.
    public func disablesPastDates(_ disables: Bool = true) -> Self {
        var copy = self
        copy.pastDisabled = disables
        return copy
    }

    /// Hides the month title and "Today" capsule above the strip.
    public func showsHeader(_ shows: Bool) -> Self {
        var copy = self
        copy.showsHeader = shows
        return copy
    }

    public var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let weeks = weekList
        let byDay = KitoCalendarMath.eventsByDay(eventList, calendar: calendar)
        let today = calendar.startOfDay(for: .now)

        VStack(alignment: .leading, spacing: theme.spacing.md) {
            if showsHeader {
                HStack(spacing: theme.spacing.sm) {
                    Text(format.monthTitle(titleDate))
                        .font(theme.typography.titleMedium)
                        .foregroundStyle(theme.colors.onSurface)
                        .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: titleCountsDown))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    if !calendar.isDate(selection, inSameDayAs: today) {
                        TodayCapsule(palette: palette) { select(today, animated: true) }
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: calendar.isDate(selection, inSameDayAs: today))
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { week in
                        HStack(spacing: theme.spacing.xs) {
                            ForEach(KitoCalendarMath.week(containing: week, calendar: calendar), id: \.self) { day in
                                pill(for: day, today: today, events: byDay[day] ?? [], palette: palette, format: format)
                            }
                        }
                        .padding(.horizontal, theme.spacing.xxs)
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visibleWeek)
            .frame(height: pillHeight)
        }
        .onAppear {
            let week = KitoCalendarMath.startOfWeek(containing: selection, calendar: calendar)
            if visibleWeek != week { visibleWeek = week }
        }
        .onChange(of: visibleWeek) { old, new in
            guard let new else { return }
            titleCountsDown = (old ?? new) > new
            if let target = programmaticTarget {
                if target == new { programmaticTarget = nil }
            } else {
                followSwipe(to: new)
            }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { titleDate = selectionIsIn(new) ? selection : new }
        }
        .onChange(of: selection) { _, new in
            let week = KitoCalendarMath.startOfWeek(containing: new, calendar: calendar)
            if week != visibleWeek {
                programmaticTarget = week
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { visibleWeek = week }
            } else {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { titleDate = new }
            }
        }
        .sensoryFeedback(.selection, trigger: calendar.startOfDay(for: selection))
    }

    private func pill(for day: Date, today: Date, events: [KitoCalendarEvent], palette: CalendarPalette, format: CalendarFormat) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = day == today
        let disabled = pastDisabled && day < today
        let foreground: Color = isSelected ? palette.onAccent : (isToday ? palette.accent : theme.colors.onSurface)

        return Button {
            select(day, animated: true)
        } label: {
            VStack(spacing: theme.spacing.xs) {
                Text(format.weekdayShort(day).uppercased())
                    .font(theme.typography.caption.weight(.semibold))
                    .opacity(isSelected ? 0.85 : 0.55)
                Text(format.day(day))
                    .font(theme.typography.titleMedium)
                    .monospacedDigit()
                Circle()
                    .fill(isSelected ? palette.onAccent : (events.first?.color ?? .clear))
                    .frame(width: 5, height: 5)
                    .opacity(events.isEmpty ? 0 : 1)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: theme.radii.pill, style: .continuous)
                        .fill(palette.accent.gradient)
                        .shadow(color: palette.accent.opacity(0.35), radius: 8, y: 4)
                        .matchedGeometryEffect(id: "pill", in: namespace)
                } else if isToday {
                    RoundedRectangle(cornerRadius: theme.radii.pill, style: .continuous)
                        .strokeBorder(palette.accent.opacity(0.45), lineWidth: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: theme.radii.pill, style: .continuous)
                        .fill(theme.colors.surfaceMuted)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.pill, style: .continuous))
            .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(KitoPressStyle(scale: 0.92))
        .disabled(disabled)
        .kitoPop(trigger: isSelected, enabled: !reduceMotion, amount: 0.9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(format.fullDate(day))
        .accessibilityValue([isToday ? "Today" : nil, events.isEmpty ? nil : (events.count == 1 ? "1 event" : "\(events.count) events")].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: State

    private var weekList: [Date] {
        let now = Date.now
        let lower = min(KitoCalendarMath.adding(weeks: -104, to: now, calendar: calendar), selection)
        let upper = max(KitoCalendarMath.adding(weeks: 104, to: now, calendar: calendar), selection)
        return KitoCalendarMath.weeks(from: pastDisabled ? min(now, selection) : lower, to: upper, calendar: calendar)
    }

    private func selectionIsIn(_ week: Date) -> Bool {
        KitoCalendarMath.startOfWeek(containing: selection, calendar: calendar) == week
    }

    private func select(_ day: Date, animated: Bool) {
        withAnimation(animated && !reduceMotion ? .spring(response: 0.4, dampingFraction: 0.78) : nil) {
            selection = calendar.startOfDay(for: day)
        }
    }

    /// After a swipe, keep the same weekday selected in the new week.
    private func followSwipe(to week: Date) {
        guard !selectionIsIn(week) else { return }
        let offset = KitoCalendarMath.nights(from: KitoCalendarMath.startOfWeek(containing: selection, calendar: calendar), to: selection, calendar: calendar)
        var day = KitoCalendarMath.adding(days: offset, to: week, calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        if pastDisabled, day < today { day = today }
        select(day, animated: true)
    }
}
