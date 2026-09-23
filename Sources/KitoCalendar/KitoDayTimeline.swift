//
//  KitoDayTimeline.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A day view: hour lines, events as blocks laid out side by side where they overlap, all-day
/// events in a strip on top, and — on today — a red line at the current time that moves as the
/// minutes pass. Opens scrolled to now (or to the first event).
///
/// ```swift
/// KitoDayTimeline(day: .now, events: meetings) { event in
///     opened = event
/// }
/// .visibleHours(7...22)
/// ```
public struct KitoDayTimeline: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let day: Date
    private let events: [KitoCalendarEvent]
    private let onEventTap: ((KitoCalendarEvent) -> Void)?
    private var customHourHeight: CGFloat?
    private var hours: ClosedRange<Int> = 0...24

    @ScaledMetric(relativeTo: .body) private var defaultHourHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 50
    @ScaledMetric(relativeTo: .caption) private var minimumBlockHeight: CGFloat = 24

    /// - Parameters:
    ///   - day: any time on the day to show.
    ///   - onEventTap: called when an event block is tapped.
    public init(
        day: Date = .now,
        events: [KitoCalendarEvent],
        onEventTap: ((KitoCalendarEvent) -> Void)? = nil
    ) {
        self.day = day
        self.events = events
        self.onEventTap = onEventTap
    }

    /// Points per hour. Defaults to 64, scaled with Dynamic Type.
    public func hourHeight(_ height: CGFloat) -> Self {
        var copy = self
        copy.customHourHeight = max(24, height)
        return copy
    }

    /// The hours drawn, e.g. `7...22` for 07:00 to 22:00. Defaults to the whole day, `0...24`.
    public func visibleHours(_ hours: ClosedRange<Int>) -> Self {
        var copy = self
        let lower = min(max(hours.lowerBound, 0), 23)
        copy.hours = lower...min(max(hours.upperBound, lower + 1), 24)
        return copy
    }

    private var hourHeight: CGFloat { customHourHeight ?? defaultHourHeight }

    public var body: some View {
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let dayStart = calendar.startOfDay(for: day)
        let windowStart = time(hours.lowerBound, on: dayStart)
        let windowEnd = time(hours.upperBound, on: dayStart)
        let dayEnd = KitoCalendarMath.adding(days: 1, to: dayStart, calendar: calendar)
        let allDay = events.filter { $0.isAllDay && $0.start < dayEnd && ($0.end > dayStart || $0.start >= dayStart) }
        let timed = events.filter { !$0.isAllDay && $0.start < windowEnd && ($0.end > windowStart || ($0.end == $0.start && $0.start >= windowStart)) }
        let minimumDuration = TimeInterval(minimumBlockHeight / hourHeight * 3_600)
        let placements = KitoEventLayout.placements(for: timed, minimumDuration: minimumDuration)
        let totalHeight = CGFloat(hours.upperBound - hours.lowerBound) * hourHeight

        VStack(spacing: 0) {
            if !allDay.isEmpty {
                allDayStrip(allDay)
                Divider().overlay(theme.colors.border)
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        hourGrid(format: format)
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            ForEach(placements, id: \.event.id) { placement in
                                let top = offset(for: max(placement.event.start, windowStart), from: windowStart)
                                let bottom = offset(for: min(placement.event.end, windowEnd), from: windowStart)
                                let height = min(max(bottom - top, minimumBlockHeight), totalHeight - top)
                                let columnWidth = width / CGFloat(placement.columnCount)
                                TimelineEventBlock(event: placement.event, height: height, format: format, onTap: onEventTap)
                                    .frame(width: max(columnWidth - 3, 0), height: max(height - 2, 0))
                                    .offset(x: columnWidth * CGFloat(placement.column), y: top + 1)
                                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                        .padding(.leading, labelWidth + theme.spacing.sm)
                        .padding(.trailing, theme.spacing.xs)
                        if calendar.isDate(day, inSameDayAs: .now) {
                            nowIndicator(windowStart: windowStart, totalHeight: totalHeight, format: format)
                        }
                    }
                    .frame(height: totalHeight)
                    .padding(.vertical, theme.spacing.md)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: placements.map(\.event.id))
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(initialHour(timed: timed), anchor: .top) }
                .onChange(of: dayStart) { _, _ in
                    withAnimation(reduceMotion ? nil : .smooth) { proxy.scrollTo(initialHour(timed: timed), anchor: .top) }
                }
            }
        }
    }

    // MARK: Pieces

    private func hourGrid(format: CalendarFormat) -> some View {
        VStack(spacing: 0) {
            ForEach(hours.lowerBound...hours.upperBound, id: \.self) { hour in
                HStack(alignment: .top, spacing: theme.spacing.sm) {
                    Text(hour == 24 ? format.hourLabel(0) : format.hourLabel(hour))
                        .font(theme.typography.caption.monospacedDigit())
                        .foregroundStyle(theme.colors.onSurface.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: labelWidth, alignment: .trailing)
                        .offset(y: -8)
                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 0.5)
                }
                .frame(height: hour == hours.upperBound ? 0 : hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .accessibilityHidden(true)
    }

    private func nowIndicator(windowStart: Date, totalHeight: CGFloat, format: CalendarFormat) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let y = offset(for: context.date, from: windowStart)
            if y >= 0, y <= totalHeight {
                HStack(spacing: 0) {
                    Text(format.time(context.date))
                        .font(theme.typography.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, theme.spacing.xs)
                        .padding(.vertical, theme.spacing.xxs)
                        .background(theme.colors.danger, in: Capsule())
                        .frame(width: labelWidth + theme.spacing.xs, alignment: .trailing)
                    NowDot(color: theme.colors.danger, animates: !reduceMotion)
                    Rectangle()
                        .fill(theme.colors.danger)
                        .frame(height: 1.5)
                }
                .frame(height: 20)
                .offset(y: y - 10)
                .animation(reduceMotion ? nil : .linear(duration: 0.6), value: y)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Now, \(format.time(context.date))")
            }
        }
        .allowsHitTesting(false)
    }

    private func allDayStrip(_ events: [KitoCalendarEvent]) -> some View {
        HStack(alignment: .center, spacing: theme.spacing.sm) {
            Text("All day")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: labelWidth, alignment: .trailing)
            ScrollView(.horizontal) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(events) { event in
                        Button { onEventTap?(event) } label: {
                            HStack(spacing: theme.spacing.xs) {
                                Circle().fill(event.color).frame(width: 7, height: 7)
                                Text(event.title)
                                    .font(theme.typography.caption.weight(.semibold))
                                    .foregroundStyle(theme.colors.onSurface)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, theme.spacing.sm)
                            .padding(.vertical, theme.spacing.xs + 1)
                            .background(event.color.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(KitoPressStyle())
                        .accessibilityLabel("\(event.title), all day")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, theme.spacing.sm)
        .padding(.trailing, theme.spacing.xs)
    }

    // MARK: Geometry

    private func time(_ hour: Int, on dayStart: Date) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart.addingTimeInterval(TimeInterval(hour * 3_600))
    }

    private func offset(for date: Date, from windowStart: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(windowStart) / 3_600) * hourHeight
    }

    private func initialHour(timed: [KitoCalendarEvent]) -> Int {
        let hour: Int
        if calendar.isDate(day, inSameDayAs: .now) {
            hour = calendar.component(.hour, from: .now) - 1
        } else if let first = timed.map(\.start).min(), calendar.isDate(first, inSameDayAs: day) {
            hour = calendar.component(.hour, from: first) - 1
        } else {
            hour = 8
        }
        return min(max(hour, hours.lowerBound), hours.upperBound)
    }
}

/// One event on the timeline, showing as much as its height allows.
private struct TimelineEventBlock: View {
    @Environment(\.kitoTheme) private var theme
    let event: KitoCalendarEvent
    let height: CGFloat
    let format: CalendarFormat
    let onTap: ((KitoCalendarEvent) -> Void)?

    var body: some View {
        let isPast = event.end < .now
        let times = "\(format.time(event.start)) – \(format.time(event.end))"
        let compact = height < 44

        Button { onTap?(event) } label: {
            HStack(alignment: .top, spacing: theme.spacing.sm) {
                Capsule()
                    .fill(event.color)
                    .frame(width: 4)
                    .padding(.vertical, compact ? 1 : 0)
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    if compact {
                        HStack(spacing: theme.spacing.xs) {
                            Text(event.title).font(theme.typography.caption.weight(.semibold))
                            Text(format.time(event.start)).font(theme.typography.caption).opacity(0.7)
                        }
                        .lineLimit(1)
                    } else {
                        Text(event.title)
                            .font(theme.typography.label.weight(.semibold))
                            .lineLimit(height < 72 ? 1 : 2)
                        Text(times)
                            .font(theme.typography.caption.monospacedDigit())
                            .opacity(0.7)
                            .lineLimit(1)
                        if height >= 76, let location = event.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(theme.typography.caption)
                                .opacity(0.7)
                                .lineLimit(1)
                        }
                    }
                }
                .foregroundStyle(theme.colors.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.vertical, compact ? 3 : theme.spacing.sm)
            .padding(.leading, theme.spacing.xs + 2)
            .padding(.trailing, theme.spacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(event.color.opacity(0.16), in: RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                    .strokeBorder(event.color.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous))
            .opacity(isPast ? 0.6 : 1)
        }
        .buttonStyle(KitoPressStyle(scale: 0.97))
        .accessibilityLabel([event.title, times, event.location].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(onTap == nil ? "" : "Opens the event")
    }
}

/// The dot at the start of the now line, with a halo that breathes.
private struct NowDot: View {
    let color: Color
    let animates: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .background {
                if animates {
                    Circle()
                        .fill(color.opacity(0.5))
                        .phaseAnimator([false, true]) { halo, expanded in
                            halo.scaleEffect(expanded ? 2.6 : 1).opacity(expanded ? 0 : 0.8)
                        } animation: { expanded in
                            expanded ? .easeOut(duration: 1.4) : .linear(duration: 0.01)
                        }
                }
            }
    }
}
