//
//  CalendarStyling.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// MARK: - Colour

/// The accent a view draws selection in, and the label colour that reads on top of it.
struct CalendarPalette {
    let accent: Color
    let onAccent: Color

    init(theme: KitoTheme, tint: Color?, environment: EnvironmentValues) {
        guard let tint else {
            accent = theme.colors.primary
            onAccent = theme.colors.onPrimary
            return
        }
        accent = tint
        onAccent = tint.kitoContrastingLabel(in: environment)
    }
}

extension Color {
    /// Black or white, whichever reads better on this colour once resolved for the current
    /// appearance — so `.primary` (black in light mode, white in dark) gets the right label too.
    func kitoContrastingLabel(in environment: EnvironmentValues) -> Color {
        let resolved = resolve(in: environment)
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Formatting

/// Date strings in the view's calendar, locale and time zone.
struct CalendarFormat {
    let calendar: Calendar
    let locale: Locale

    private func style(_ base: Date.FormatStyle) -> Date.FormatStyle {
        var style = base
        style.calendar = calendar
        style.locale = locale
        style.timeZone = calendar.timeZone
        return style
    }

    func monthTitle(_ date: Date) -> String { date.formatted(style(.dateTime.month(.wide).year())) }
    func monthName(_ date: Date) -> String { date.formatted(style(.dateTime.month(.wide))) }
    func shortMonth(_ date: Date) -> String { date.formatted(style(.dateTime.month(.abbreviated))) }
    func year(_ date: Date) -> String { date.formatted(style(.dateTime.year())) }
    func day(_ date: Date) -> String { date.formatted(style(.dateTime.day())) }
    func time(_ date: Date) -> String { date.formatted(style(Date.FormatStyle(date: .omitted, time: .shortened))) }
    func weekdayShort(_ date: Date) -> String { date.formatted(style(.dateTime.weekday(.abbreviated))) }
    func fullDate(_ date: Date) -> String { date.formatted(style(.dateTime.weekday(.wide).day().month(.wide).year())) }
    func dayHeading(_ date: Date) -> String { date.formatted(style(.dateTime.weekday(.wide).day().month(.wide))) }

    func hourLabel(_ hour: Int) -> String {
        let midnight = calendar.startOfDay(for: .now)
        let date = calendar.date(byAdding: .hour, value: hour, to: midnight) ?? midnight
        return date.formatted(style(.dateTime.hour()))
    }
}

// MARK: - Motion

extension View {
    /// A quick squash-and-spring when `trigger` changes. Skipped under Reduce Motion.
    @ViewBuilder
    func kitoPop<T: Equatable>(trigger: T, enabled: Bool, amount: CGFloat = 0.84) -> some View {
        if enabled {
            keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(amount, duration: 0.08)
                SpringKeyframe(1.06, duration: 0.18, spring: .snappy)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
        } else {
            self
        }
    }
}

/// Springy scale on press.
struct KitoPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A round, tinted icon button used for chevrons and close buttons.
struct CalendarIconButton: View {
    @Environment(\.kitoTheme) private var theme
    let systemImage: String
    let label: String
    var bounce: Int = 0
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 34

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(theme.typography.label.weight(.semibold))
                .symbolEffect(.bounce, value: bounce)
                .foregroundStyle(theme.colors.onSurface)
                .frame(width: size, height: size)
                .background(theme.colors.surfaceMuted, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(KitoPressStyle(scale: 0.88))
        .accessibilityLabel(label)
    }
}

/// The "Today" capsule that jumps back to the current date.
struct TodayCapsule: View {
    @Environment(\.kitoTheme) private var theme
    let palette: CalendarPalette
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Label("Today", systemImage: "arrow.uturn.backward")
                .font(theme.typography.caption.weight(.semibold))
                .symbolEffect(.bounce, value: taps)
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.xs + 2)
                .background(palette.accent, in: Capsule())
        }
        .buttonStyle(KitoPressStyle())
        .accessibilityHint("Jumps back to today")
    }
}
