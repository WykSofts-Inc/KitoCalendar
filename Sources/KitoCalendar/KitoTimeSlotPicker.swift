//
//  KitoTimeSlotPicker.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Booking slots grouped into Morning, Afternoon and Evening. Taken slots are struck out, and the
/// selection glides to the slot you tap with a check that bounces in.
///
/// ```swift
/// let slots = KitoSlotSchedule(opens: .init(9), closes: .init(18), duration: 45, interval: 15)
///     .slots(on: day, booked: bookings, notBefore: .now)
/// KitoTimeSlotPicker(slots: slots, selection: $slot)
/// ```
public struct KitoTimeSlotPicker: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    private let slots: [KitoTimeSlot]
    @Binding private var selection: KitoTimeSlot?
    private let tint: Color?
    private var showsEndTime = false

    @Namespace private var namespace
    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var slotHeight: CGFloat = 44

    public init(slots: [KitoTimeSlot], selection: Binding<KitoTimeSlot?>, tint: Color? = nil) {
        self.slots = slots
        _selection = selection
        self.tint = tint
    }

    /// Shows "09:00 – 09:45" on each slot instead of just the start.
    public func showsEndTime(_ shows: Bool = true) -> Self {
        var copy = self
        copy.showsEndTime = shows
        return copy
    }

    public var body: some View {
        let palette = CalendarPalette(theme: theme, tint: tint, environment: environment)
        let format = CalendarFormat(calendar: calendar, locale: locale)
        let grouped = Dictionary(grouping: slots, by: \.period)

        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            if slots.isEmpty {
                emptyState
            }
            ForEach(KitoDayPeriod.allCases.filter { grouped[$0] != nil }) { period in
                let items = grouped[period] ?? []
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    header(period, open: items.filter(\.isAvailable).count)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: showsEndTime ? minimumWidth * 1.6 : minimumWidth), spacing: theme.spacing.sm)],
                        spacing: theme.spacing.sm
                    ) {
                        ForEach(items) { slot in
                            slotButton(slot, palette: palette, format: format)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection?.id)
    }

    private func header(_ period: KitoDayPeriod, open: Int) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: period.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(period == .evening ? Color.indigo : theme.colors.warning)
                .font(theme.typography.bodyEmphasized)
            Text(period.title)
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onSurface)
            Spacer(minLength: 0)
            Text(open == 0 ? "Fully booked" : (open == 1 ? "1 open" : "\(open) open"))
                .font(theme.typography.caption.weight(.medium))
                .foregroundStyle(open == 0 ? theme.colors.danger : theme.colors.onSurface.opacity(0.55))
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, theme.spacing.xxs + 1)
                .background(theme.colors.surfaceMuted, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func slotButton(_ slot: KitoTimeSlot, palette: CalendarPalette, format: CalendarFormat) -> some View {
        let isSelected = selection?.id == slot.id
        let label = showsEndTime ? "\(format.time(slot.start)) – \(format.time(slot.end))" : format.time(slot.start)

        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)) {
                selection = isSelected ? nil : slot
            }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(theme.typography.caption.weight(.bold))
                        .symbolEffect(.bounce, value: selection?.id)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                Text(label)
                    .font(theme.typography.label.weight(isSelected ? .semibold : .medium))
                    .monospacedDigit()
                    .strikethrough(!slot.isAvailable, color: theme.colors.onSurface.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? palette.onAccent : theme.colors.onSurface.opacity(slot.isAvailable ? 1 : 0.4))
            .frame(maxWidth: .infinity)
            .frame(height: slotHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.accent.gradient)
                        .shadow(color: palette.accent.opacity(0.35), radius: 8, y: 4)
                        .matchedGeometryEffect(id: "slot", in: namespace)
                } else if slot.isAvailable {
                    Capsule()
                        .fill(theme.colors.surface)
                        .overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
                } else {
                    Capsule()
                        .strokeBorder(theme.colors.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .background(Capsule().fill(theme.colors.surfaceMuted.opacity(0.5)))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(KitoPressStyle(scale: 0.93))
        .disabled(!slot.isAvailable)
        .accessibilityLabel("\(format.time(slot.start)) to \(format.time(slot.end))")
        .accessibilityValue(slot.isAvailable ? "" : "Unavailable")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            Text("No times on this day")
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onSurface)
            Text("Try another date.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xl)
        .accessibilityElement(children: .combine)
    }
}
