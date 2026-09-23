//
//  KitoAgendaList.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Events as a scrolling list grouped by day, each day's header sticking to the top while its
/// events pass under it. Today is flagged, and an event happening right now gets a live badge.
///
/// ```swift
/// KitoAgendaList(events: trips) { event in
///     selected = event
/// }
/// ```
public struct KitoAgendaList: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    private let events: [KitoCalendarEvent]
    private let tint: Color?
    private let onEventTap: ((KitoCalendarEvent) -> Void)?
    private var emptyTitle = "Nothing planned"
    private var emptyMessage = "Events you add will show up here."

    @ScaledMetric(relativeTo: .body) private var timeColumnWidth: CGFloat = 56

    public init(events: [KitoCalendarEvent], tint: Color? = nil, onEventTap: ((KitoCalendarEvent) -> Void)? = nil) {
        self.events = events
        self.tint = tint
        self.onEventTap = onEventTap
    }

    /// What to show when there are no events.
    public func emptyState(title: String, message: String) -> Self {
        var copy = self
        copy.emptyTitle = title
        copy.emptyMessage = message
        return copy
    }

    public var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let days = KitoCalendarMath.agenda(for: events, calendar: calendar)

        ScrollViewReader { proxy in
            ScrollView {
                if days.isEmpty {
                    empty
                } else {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.sm, pinnedViews: [.sectionHeaders]) {
                        ForEach(days) { day in
                            Section {
                                ForEach(day.events) { event in
                                    row(event, on: day.date, palette: palette, format: format)
                                        .padding(.horizontal, theme.spacing.lg)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            } header: {
                                header(for: day, palette: palette, format: format)
                            }
                            .id(day.date)
                        }
                    }
                    .padding(.bottom, theme.spacing.xl)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: events.map(\.id))
                }
            }
            .background(theme.colors.background)
            .onAppear {
                // Open on today, or the next day with plans, rather than on the oldest event.
                let today = calendar.startOfDay(for: .now)
                if let first = days.first(where: { $0.date >= today }), first.date != days.first?.date {
                    proxy.scrollTo(first.date, anchor: .top)
                }
            }
        }
    }

    // MARK: Pieces

    private func header(for day: KitoAgendaDay, palette: CalendarPalette, format: CalendarFormat) -> some View {
        let relative: String? = calendar.isDateInToday(day.date) ? "Today" : (calendar.isDateInTomorrow(day.date) ? "Tomorrow" : (calendar.isDateInYesterday(day.date) ? "Yesterday" : nil))
        let isToday = calendar.isDateInToday(day.date)

        return HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
            if let relative {
                Text(relative.uppercased())
                    .font(theme.typography.caption.weight(.bold))
                    .foregroundStyle(isToday ? palette.onAccent : palette.accent)
                    .padding(.horizontal, theme.spacing.sm)
                    .padding(.vertical, theme.spacing.xxs + 1)
                    .background {
                        if isToday { Capsule().fill(palette.accent) } else { Capsule().strokeBorder(palette.accent.opacity(0.5)) }
                    }
            }
            Text(format.dayHeading(day.date))
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onBackground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(day.events.count == 1 ? "1 event" : "\(day.events.count) events")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onBackground.opacity(0.5))
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func row(_ event: KitoCalendarEvent, on day: Date, palette: CalendarPalette, format: CalendarFormat) -> some View {
        let dayEnd = KitoCalendarMath.adding(days: 1, to: day, calendar: calendar)
        let coversDay = event.isAllDay || (event.start <= day && event.end >= dayEnd)
        let startsEarlier = event.start < day
        let top = coversDay ? "All day" : (startsEarlier ? "Until" : format.time(event.start))
        let bottom: String? = coversDay ? nil : (event.end <= dayEnd ? format.time(event.end) : "Next day")

        return Button { onEventTap?(event) } label: {
            HStack(alignment: .top, spacing: theme.spacing.md) {
                VStack(alignment: .trailing, spacing: theme.spacing.xxs) {
                    Text(top)
                        .font(theme.typography.label.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.colors.onSurface)
                    if let bottom {
                        Text(bottom)
                            .font(theme.typography.caption.monospacedDigit())
                            .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: timeColumnWidth, alignment: .trailing)

                Capsule()
                    .fill(event.color.gradient)
                    .frame(width: 4)
                    .frame(minHeight: 36)

                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(event.title)
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)
                    if let location = event.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if TimelineOngoing.isOngoing(event) {
                    LiveBadge(color: theme.colors.danger, animates: !reduceMotion)
                }
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                    .strokeBorder(theme.colors.border.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(KitoPressStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([event.title, coversDay ? "All day" : "\(top)\(bottom.map { " to \($0)" } ?? "")", event.location].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(TimelineOngoing.isOngoing(event) ? "Happening now" : "")
    }

    private var empty: some View {
        VStack(spacing: theme.spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(theme.typography.displayMedium)
                .foregroundStyle(theme.colors.onBackground.opacity(0.35))
                .symbolEffect(.bounce, options: .nonRepeating, value: events.isEmpty)
            Text(emptyTitle)
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onBackground)
            Text(emptyMessage)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl * 2)
        .padding(.horizontal, theme.spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

private enum TimelineOngoing {
    static func isOngoing(_ event: KitoCalendarEvent) -> Bool {
        !event.isAllDay && event.isOngoing(at: .now)
    }
}

/// "LIVE" with a breathing dot, for an event under way.
private struct LiveBadge: View {
    @Environment(\.kitoTheme) private var theme
    let color: Color
    let animates: Bool

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .phaseAnimator(animates ? [false, true] : [false]) { dot, dim in
                    dot.opacity(dim ? 0.3 : 1)
                } animation: { _ in .easeInOut(duration: 0.8) }
            Text("Now")
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xxs + 1)
        .background(color.opacity(0.12), in: Capsule())
    }
}
