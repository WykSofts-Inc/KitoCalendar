//
//  MonthPage.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// What's selected, with every date at midnight.
enum SelectionSnapshot: Equatable {
    case single(Date?)
    case multiple(Set<Date>)
    case range(start: Date?, end: Date?)

    /// Ordered dates, used to fire haptics when the selection changes.
    var fingerprint: [Date] {
        switch self {
        case .single(let date): return date.map { [$0] } ?? []
        case .multiple(let dates): return dates.sorted()
        case .range(let start, let end): return [start, end].compactMap { $0 }
        }
    }
}

/// How a day is drawn relative to the selection.
enum DayFill: Equatable {
    case none
    case single
    case multiple
    case rangeStart
    case rangeEnd

    var isFilled: Bool { self != .none }

    /// The matched-geometry identity, so a fill glides between days instead of popping.
    var geometryID: String? {
        switch self {
        case .single: return "single"
        case .rangeStart: return "rangeStart"
        case .rangeEnd: return "rangeEnd"
        case .none, .multiple: return nil
        }
    }
}

/// Everything a month page needs to draw and handle its days.
struct DayContext {
    let calendar: Calendar
    let format: CalendarFormat
    let palette: CalendarPalette
    let today: Date
    let eventsByDay: [Date: [KitoCalendarEvent]]
    let heat: [Date: Double]
    let selection: SelectionSnapshot
    /// Out of bounds or in the past: faded.
    let isOutOfBounds: (Date) -> Bool
    /// Unavailable by the caller's rule: struck through.
    let isUnavailable: (Date) -> Bool
    let namespace: Namespace.ID
    let reduceMotion: Bool
    let onTap: (Date) -> Void

    func fill(for date: Date) -> DayFill {
        switch selection {
        case .single(let selected):
            return selected == date ? .single : .none
        case .multiple(let dates):
            return dates.contains(date) ? .multiple : .none
        case .range(let start, let end):
            if start == date { return .rangeStart }
            if end == date { return .rangeEnd }
            return .none
        }
    }

    func isInBand(_ date: Date) -> Bool {
        guard case .range(let start?, let end?) = selection else { return false }
        return date > start && date < end
    }

    var completedRange: (start: Date, end: Date)? {
        guard case .range(let start?, let end?) = selection, start < end else { return nil }
        return (start, end)
    }
}

/// Six rows of days for one month, with the continuous band behind a range.
struct MonthPage: View {
    @Environment(\.kitoTheme) private var theme
    let grid: KitoMonthGrid
    let context: DayContext
    /// Only the page on screen takes part in matched geometry.
    let isActive: Bool
    let cellHeight: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / 7
            let diameter = max(22, min(cellWidth, cellHeight) - 4)
            VStack(spacing: rowSpacing) {
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week) { day in
                            DayCell(day: day, context: context, diameter: diameter, isActive: isActive)
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                    .background(alignment: .leading) {
                        band(for: week, cellWidth: cellWidth, height: diameter)
                    }
                }
            }
        }
        .frame(height: cellHeight * CGFloat(grid.weeks.count) + rowSpacing * CGFloat(max(grid.weeks.count - 1, 0)))
    }

    /// The fill that runs from the start cap to the end cap, broken per week row with rounded
    /// ends where it wraps.
    @ViewBuilder
    private func band(for week: [KitoMonthGrid.Day], cellWidth: CGFloat, height: CGFloat) -> some View {
        if let range = context.completedRange {
            let covered = week.indices.filter { week[$0].isInMonth && week[$0].date >= range.start && week[$0].date <= range.end }
            if let first = covered.first, let last = covered.last {
                let startX = CGFloat(first) * cellWidth + (week[first].date == range.start ? cellWidth / 2 : 0)
                let endX = CGFloat(last + 1) * cellWidth - (week[last].date == range.end ? cellWidth / 2 : 0)
                if endX > startX {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(context.palette.accent.opacity(0.14))
                        .frame(width: endX - startX, height: height)
                        .offset(x: startX)
                        .transition(.scale(scale: 0.1, anchor: .leading).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

/// One day: number, today ring, selection fill, event dots or heat.
struct DayCell: View {
    @Environment(\.kitoTheme) private var theme
    let day: KitoMonthGrid.Day
    let context: DayContext
    let diameter: CGFloat
    let isActive: Bool

    var body: some View {
        let date = day.date
        let isToday = context.calendar.isDate(date, inSameDayAs: context.today)
        let outOfBounds = context.isOutOfBounds(date)
        let unavailable = day.isInMonth && !outOfBounds && context.isUnavailable(date)
        let fill = day.isInMonth ? context.fill(for: date) : .none
        let inBand = day.isInMonth && context.isInBand(date)
        let events = day.isInMonth ? context.eventsByDay[date] ?? [] : []
        let heat = day.isInMonth ? context.heat[date] : nil

        Button {
            context.onTap(date)
        } label: {
            ZStack {
                if let heat, !fill.isFilled {
                    RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                        .fill(context.palette.accent.opacity(0.06 + 0.8 * heat))
                        .padding(2)
                }
                if fill.isFilled {
                    selectionShape(fill)
                } else if isToday {
                    Circle()
                        .strokeBorder(context.palette.accent, lineWidth: 1.5)
                        .frame(width: diameter, height: diameter)
                }
                Text(context.format.day(date))
                    .font(fill.isFilled || isToday ? theme.typography.bodyEmphasized : theme.typography.body)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .strikethrough(unavailable, color: theme.colors.onSurface.opacity(0.5))
                    .foregroundStyle(textColor(fill: fill, isToday: isToday, heat: heat, inBand: inBand))
                    .contentTransition(.interpolate)
                if !events.isEmpty {
                    dots(for: events, filled: fill.isFilled)
                        .offset(y: diameter * 0.32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .opacity(opacity(outOfBounds: outOfBounds, unavailable: unavailable))
        }
        .buttonStyle(KitoPressStyle(scale: 0.88))
        .disabled(!day.isInMonth || outOfBounds || unavailable)
        .kitoPop(trigger: fill, enabled: !context.reduceMotion)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.format.fullDate(date))
        .accessibilityValue(accessibilityValue(isToday: isToday, fill: fill, inBand: inBand, events: events.count, unavailable: unavailable, heat: heat))
        .accessibilityAddTraits(fill.isFilled ? [.isButton, .isSelected] : .isButton)
        .accessibilityHidden(!day.isInMonth)
    }

    @ViewBuilder
    private func selectionShape(_ fill: DayFill) -> some View {
        let circle = Circle()
            .fill(context.palette.accent.gradient)
            .frame(width: diameter, height: diameter)
            .shadow(color: context.palette.accent.opacity(0.35), radius: 6, y: 3)
        if isActive, let id = fill.geometryID {
            circle.matchedGeometryEffect(id: id, in: context.namespace)
        } else {
            circle.transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    private func dots(for events: [KitoCalendarEvent], filled: Bool) -> some View {
        var seen: [Color] = []
        for event in events where !seen.contains(event.color) {
            seen.append(event.color)
            if seen.count == 3 { break }
        }
        return HStack(spacing: 3) {
            ForEach(Array(seen.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(filled ? context.palette.onAccent : color)
                    .frame(width: 5, height: 5)
            }
        }
    }

    private func textColor(fill: DayFill, isToday: Bool, heat: Double?, inBand: Bool) -> Color {
        if fill.isFilled { return context.palette.onAccent }
        if let heat, heat > 0.55 { return context.palette.onAccent }
        if isToday { return context.palette.accent }
        return theme.colors.onSurface
    }

    private func opacity(outOfBounds: Bool, unavailable: Bool) -> Double {
        if !day.isInMonth { return 0.22 }
        if outOfBounds { return 0.3 }
        if unavailable { return 0.45 }
        return 1
    }

    private func accessibilityValue(isToday: Bool, fill: DayFill, inBand: Bool, events: Int, unavailable: Bool, heat: Double?) -> String {
        var parts: [String] = []
        if isToday { parts.append("Today") }
        switch fill {
        case .single, .multiple: parts.append("Selected")
        case .rangeStart: parts.append("Start date")
        case .rangeEnd: parts.append("End date")
        case .none: if inBand { parts.append("In selected range") }
        }
        if unavailable { parts.append("Unavailable") }
        if events > 0 { parts.append(events == 1 ? "1 event" : "\(events) events") }
        if let heat { parts.append("Activity \(Int((heat * 100).rounded())) percent") }
        return parts.joined(separator: ", ")
    }
}

/// The row of weekday initials above a grid, starting on the calendar's first weekday.
struct WeekdayHeader: View {
    @Environment(\.kitoTheme) private var theme
    let calendar: Calendar
    let locale: Locale
    var style: KitoWeekdayStyle = .veryShort

    var body: some View {
        let symbols = KitoCalendarMath.weekdaySymbols(calendar: calendar, locale: locale, style: style)
        let week = KitoCalendarMath.week(containing: .now, calendar: calendar)
        HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                let weekend = index < week.count && calendar.isDateInWeekend(week[index])
                Text(symbol)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(weekend ? 0.38 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
