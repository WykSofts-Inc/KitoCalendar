//
//  KitoDateRangeBar.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A field (or compact chip) that reads "12 – 18 Oct · 6 nights" and opens a range calendar in a
/// sheet, with one-tap presets — This weekend, Next 7 days, This month — and an Apply button.
///
/// ```swift
/// @State private var stay: KitoDateRange?
/// KitoDateRangeBar(range: $stay, title: "Check-in – Check-out")
/// KitoDateRangeBar(range: $trip, unit: .days, style: .chip)
/// ```
public struct KitoDateRangeBar: View {
    /// How the closed control looks.
    public enum Style: Sendable {
        /// A full-width field with a title and the dates underneath.
        case field
        /// A compact capsule with just the dates.
        case chip
    }

    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.self) private var environment

    @Binding private var range: KitoDateRange?
    private let title: String
    private let placeholder: String
    private let unit: KitoRangeUnit?
    private let style: Style
    private let tint: Color?
    private var presets: [KitoDatePreset] = KitoDatePreset.standard
    private var minimum: Date?
    private var maximum: Date?
    private var pastAllowed = false
    private var unavailableRule: ((Date) -> Bool)?

    @State private var isPresented = false

    /// - Parameters:
    ///   - title: the field's label and the sheet's title.
    ///   - unit: `.nights` for stays, `.days` for trips, `nil` to show only the dates.
    public init(
        range: Binding<KitoDateRange?>,
        title: String = "Dates",
        placeholder: String = "Add dates",
        unit: KitoRangeUnit? = .nights,
        style: Style = .field,
        tint: Color? = nil
    ) {
        _range = range
        self.title = title
        self.placeholder = placeholder
        self.unit = unit
        self.style = style
        self.tint = tint
    }

    /// The preset chips in the sheet. Pass `[]` to hide them.
    public func presets(_ presets: [KitoDatePreset]) -> Self {
        var copy = self
        copy.presets = presets
        return copy
    }

    /// The earliest day that can be picked. Past days are blocked unless `allowsPastDates()`.
    public func minimumDate(_ date: Date?) -> Self {
        var copy = self
        copy.minimum = date
        return copy
    }

    /// The latest day that can be picked.
    public func maximumDate(_ date: Date?) -> Self {
        var copy = self
        copy.maximum = date
        return copy
    }

    /// Lets days before today be picked (off by default — most ranges are bookings).
    public func allowsPastDates(_ allows: Bool = true) -> Self {
        var copy = self
        copy.pastAllowed = allows
        return copy
    }

    /// Strikes through days your rule marks unavailable.
    public func unavailableDates(_ isUnavailable: @escaping (Date) -> Bool) -> Self {
        var copy = self
        copy.unavailableRule = isUnavailable
        return copy
    }

    public var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)
        let value = range?.formatted(unit: unit, calendar: calendar, locale: locale)

        Button { isPresented = true } label: {
            switch style {
            case .field: field(value: value, palette: palette)
            case .chip: chip(value: value, palette: palette)
            }
        }
        .buttonStyle(KitoPressStyle(scale: 0.97))
        .accessibilityLabel(title)
        .accessibilityValue(value ?? placeholder)
        .accessibilityHint("Opens the date picker")
        .sheet(isPresented: $isPresented) {
            RangeSheet(
                title: title,
                unit: unit,
                initial: range,
                presets: presets,
                minimum: minimum,
                maximum: maximum,
                pastAllowed: pastAllowed,
                unavailableRule: unavailableRule,
                tint: tint
            ) { picked in
                range = picked
                isPresented = false
            } onCancel: {
                isPresented = false
            }
            .environment(\.kitoTheme, theme)
            .environment(\.calendar, calendar)
            .environment(\.locale, locale)
        }
    }

    private func field(value: String?, palette: CalendarPalette) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "calendar")
                .font(theme.typography.bodyEmphasized)
                .symbolEffect(.bounce, value: range)
                .foregroundStyle(palette.onAccent)
                .frame(width: 40, height: 40)
                .background(palette.accent.gradient, in: Circle())
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                Text(value ?? placeholder)
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(value == nil ? theme.colors.onSurface.opacity(0.45) : theme.colors.onSurface)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.35))
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                .strokeBorder(theme.colors.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        .animation(.snappy, value: value)
    }

    private func chip(value: String?, palette: CalendarPalette) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "calendar")
                .symbolEffect(.bounce, value: range)
            Text(value ?? placeholder)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .font(theme.typography.label.weight(.semibold))
        .foregroundStyle(value == nil ? theme.colors.onSurface : palette.onAccent)
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background {
            if value == nil {
                Capsule().fill(theme.colors.surface).overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
            } else {
                Capsule().fill(palette.accent.gradient)
            }
        }
        .animation(.snappy, value: value)
    }
}

/// The sheet behind `KitoDateRangeBar`: presets, a range calendar and Apply.
private struct RangeSheet: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    let title: String
    let unit: KitoRangeUnit?
    let presets: [KitoDatePreset]
    let minimum: Date?
    let maximum: Date?
    let pastAllowed: Bool
    let unavailableRule: ((Date) -> Bool)?
    let tint: Color?
    let onApply: (KitoDateRange?) -> Void
    let onCancel: () -> Void

    @State private var draft: KitoRangeSelection
    @State private var applied = 0

    init(
        title: String,
        unit: KitoRangeUnit?,
        initial: KitoDateRange?,
        presets: [KitoDatePreset],
        minimum: Date?,
        maximum: Date?,
        pastAllowed: Bool,
        unavailableRule: ((Date) -> Bool)?,
        tint: Color?,
        onApply: @escaping (KitoDateRange?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.unit = unit
        self.presets = presets
        self.minimum = minimum
        self.maximum = maximum
        self.pastAllowed = pastAllowed
        self.unavailableRule = unavailableRule
        self.tint = tint
        self.onApply = onApply
        self.onCancel = onCancel
        _draft = State(initialValue: KitoRangeSelection(initial))
    }

    var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)

        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(title)
                        .font(theme.typography.titleLarge)
                        .foregroundStyle(theme.colors.onBackground)
                    Text(summary)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                        .animation(reduceMotion ? nil : .snappy, value: summary)
                }
                Spacer(minLength: 0)
                CalendarIconButton(systemImage: "xmark", label: "Close", action: onCancel)
            }

            if !presets.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: theme.spacing.sm) {
                        ForEach(presets) { preset in
                            presetChip(preset, palette: palette)
                        }
                    }
                    .padding(.vertical, theme.spacing.xxs)
                }
                .scrollIndicators(.hidden)
            }

            KitoMonthCalendar(range: $draft, tint: tint)
                .minimumDate(effectiveMinimum)
                .maximumDate(maximum)
                .unavailableDates(unavailableRule ?? { _ in false })

            Spacer(minLength: 0)

            HStack(spacing: theme.spacing.md) {
                Button("Clear") {
                    withAnimation(reduceMotion ? nil : .snappy) { draft.clear() }
                }
                .font(theme.typography.button)
                .foregroundStyle(theme.colors.onBackground)
                .underline()
                .disabled(draft.isEmpty)
                .opacity(draft.isEmpty ? 0.4 : 1)

                Spacer(minLength: 0)

                Button {
                    applied += 1
                    onApply(draft.range)
                } label: {
                    Text("Apply")
                        .font(theme.typography.button)
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, theme.spacing.xxl)
                        .frame(minHeight: 50)
                        .background(palette.accent.gradient, in: Capsule())
                        .shadow(color: palette.accent.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(KitoPressStyle())
                .disabled(!draft.isComplete && !draft.isEmpty)
                .opacity(!draft.isComplete && !draft.isEmpty ? 0.45 : 1)
            }
        }
        .padding(theme.spacing.xl)
        .padding(.top, theme.spacing.sm)
        .background(theme.colors.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .sensoryFeedback(.success, trigger: applied)
    }

    private var effectiveMinimum: Date? {
        if pastAllowed { return minimum }
        let today = calendar.startOfDay(for: .now)
        return max(minimum ?? today, today)
    }

    private var summary: String {
        if let range = draft.range { return range.formatted(unit: unit, calendar: calendar, locale: locale) }
        if let start = draft.start {
            return "\(KitoDateRange(start: start, end: start).formattedDates(calendar: calendar, locale: locale)) – pick an end date"
        }
        return "Pick a start date"
    }

    private func presetChip(_ preset: KitoDatePreset, palette: CalendarPalette) -> some View {
        let value = preset.range(relativeTo: .now, calendar: calendar)
        let isOn = draft.range == KitoDateRange(start: calendar.startOfDay(for: value.start), end: calendar.startOfDay(for: value.end))

        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
                draft.set(value, calendar: calendar)
            }
        } label: {
            Label(preset.title, systemImage: preset.systemImage)
                .font(theme.typography.label.weight(.semibold))
                .symbolEffect(.bounce, value: isOn)
                .foregroundStyle(isOn ? palette.onAccent : theme.colors.onSurface)
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
                .background {
                    if isOn {
                        Capsule().fill(palette.accent.gradient)
                    } else {
                        Capsule().fill(theme.colors.surface).overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(KitoPressStyle())
        .accessibilityValue(value.formatted(unit: unit, calendar: calendar, locale: locale))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
