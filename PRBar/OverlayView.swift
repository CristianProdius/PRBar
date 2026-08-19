import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    private var showFull: Bool {
        state.isHovered || state.isExpanded || state.justMerged || state.celebrating || state.menuOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showFull ? 12 : 0) {
            if showFull {
                fullHeader
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                compactRow
                    .transition(.opacity)
            }

            PulseBar(
                ratio: state.ratio,
                live: showFull,
                celebrating: state.celebrating,
                justMerged: state.justMerged,
                compact: !showFull
            )

            if showFull {
                fullDetails
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, showFull ? 20 : 16)
        .padding(.vertical, showFull ? 16 : 10)
        .frame(width: showFull ? 420 : 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: showFull ? 20 : 16, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: showFull ? 20 : 16, style: .continuous)
                .strokeBorder(Color.white.opacity(showFull ? 0.08 : 0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: showFull ? 20 : 16, style: .continuous))
        .animation(.spring(duration: 0.38, bounce: 0.18), value: showFull)
        .animation(.spring(duration: 0.4, bounce: 0.22), value: state.celebrating)
    }

    private var compactRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(state.count)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
            Text("/\(state.goal)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.35))
            Spacer(minLength: 0)
            overflowButton
        }
    }

    private var fullHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(state.goalMet ? "Goal hit" : "Today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                overflowButton
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 2)

            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(state.count)")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                    Text("/\(state.goal)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.32))
                }

                if let badge = deltaBadge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(badge.up ? 0.95 : 0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                Text("vs yesterday")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.32))
                Spacer(minLength: 0)
            }
        }
    }

    private var fullDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let whisper = state.whisperTitle {
                Text(whisper)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
            }

            WeekStrip(days: state.weekDays, fill: Color.white, onDark: true)

            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else if state.prs.isEmpty {
                Text("No merges yet today")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
            } else {
                ForEach(Array(state.prs.prefix(4).enumerated()), id: \.element.id) { pair in
                    Button {
                        state.open(pair.element)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pair.element.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(1)
                            Text(pair.element.repo)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.32))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    private var overflowButton: some View {
        Button {
            state.requestOverflowMenu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Actions")
    }

    private var subtitle: String {
        if state.celebrating || state.goalMet { return "You hit today’s merge goal" }
        if let whisper = state.whisperTitle { return whisper }
        if let error = state.lastError { return error }
        let remaining = max(0, state.goal - state.count)
        if remaining == 0 { return "You hit today’s merge goal" }
        if onPace { return "On track to hit \(state.goal) today" }
        return "\(remaining) more to hit today’s goal"
    }

    private var onPace: Bool {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(start)
        let day: Double = 16 * 3600
        let expected = ProgressMath.ratio(count: Int((elapsed / day) * Double(state.goal)), goal: state.goal)
        return state.ratio + 0.02 >= min(1, expected)
    }

    private var deltaBadge: (text: String, up: Bool)? {
        guard state.weekDays.count >= 2 else { return nil }
        let yesterday = state.weekDays[state.weekDays.count - 2].count
        let delta = state.count - yesterday
        if delta > 0 { return ("↗ \(delta)", true) }
        if delta < 0 { return ("↘ \(abs(delta))", false) }
        return ("→ 0", false)
    }
}

struct PulseBar: View {
    let ratio: Double
    let live: Bool
    let celebrating: Bool
    let justMerged: Bool
    let compact: Bool

    private let segments = 24

    @State private var revealed = 0
    @State private var hoverIndex: Int?
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: live ? 1.0 / 24.0 : 1.0, paused: !live)) { timeline in
            let time = live ? timeline.date.timeIntervalSinceReferenceDate : 0
            HStack(spacing: compact ? 2.5 : 3.5) {
                ForEach(0..<segments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: compact ? 2 : 3, style: .continuous)
                        .fill(color(for: index, time: time))
                        .frame(width: compact ? 7 : 10, height: height(for: index, time: time))
                        .shadow(color: glow(for: index), radius: hoverIndex == index ? 7 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onContinuousHover { phase in
            guard live else {
                hoverIndex = nil
                return
            }
            switch phase {
            case .active(let location):
                let step: CGFloat = compact ? 9.5 : 13.5
                hoverIndex = min(segments - 1, max(0, Int(location.x / step)))
            case .ended:
                hoverIndex = nil
            }
        }
        .onAppear {
            revealed = compact ? targetFilled : 0
            if live { playReveal() }
        }
        .onChange(of: live) { _, on in
            if on {
                playReveal()
            } else {
                revealTask?.cancel()
                revealed = targetFilled
            }
        }
        .onChange(of: targetFilled) { _, _ in
            if live {
                playReveal()
            } else {
                revealed = targetFilled
            }
        }
    }

    private var targetFilled: Int {
        Int((ratio * Double(segments)).rounded())
    }

    private func playReveal() {
        revealTask?.cancel()
        revealed = 0
        revealTask = Task { @MainActor in
            let total = max(targetFilled, 1)
            for index in 0...total {
                if Task.isCancelled { return }
                withAnimation(.spring(duration: 0.28, bounce: 0.32)) {
                    revealed = index
                }
                try? await Task.sleep(nanoseconds: 24_000_000)
            }
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        index < revealed
    }

    private func height(for index: Int, time: TimeInterval) -> CGFloat {
        let base: CGFloat = compact ? 11 : 28
        if hoverIndex == index { return base + 6 }
        guard live, isFilled(index) else { return base }
        let dist = Double(max(0, revealed - 1 - index))
        let wave = sin(time * 4.2 - dist * 0.55)
        let extra = CGFloat(max(0, wave) * (justMerged || celebrating ? 7 : 5))
        return base + extra
    }

    private func color(for index: Int, time: TimeInterval) -> Color {
        if hoverIndex == index {
            return Color(red: 0.31, green: 0.58, blue: 1.0)
        }
        if celebrating && isFilled(index) {
            return Color(red: 0.98, green: 0.86, blue: 0.42)
        }
        if isFilled(index) {
            if live {
                let dist = Double(max(0, revealed - 1 - index))
                let wave = (sin(time * 4.2 - dist * 0.55) + 1) / 2
                let dim = 0.72 + 0.28 * wave
                return Color.white.opacity(dim)
            }
            return Color.white
        }
        return Color.white.opacity(0.12)
    }

    private func glow(for index: Int) -> Color {
        hoverIndex == index ? Color(red: 0.31, green: 0.58, blue: 1.0).opacity(0.9) : .clear
    }
}

struct WeekStrip: View {
    let days: [WeekDay]
    let fill: Color
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    Capsule()
                        .fill(tickColor(day))
                        .frame(width: day.isToday ? 16 : 12, height: 5)
                        .animation(.spring(duration: 0.35, bounce: 0.2), value: day.count)
                    Text(day.label)
                        .font(.system(size: 8, weight: day.isToday ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(labelColor(day))
                }
                .frame(maxWidth: .infinity)
                .help("\(day.count) merged")
            }
        }
    }

    private func tickColor(_ day: WeekDay) -> Color {
        if day.count == 0 {
            return onDark
                ? Color.white.opacity(day.isToday ? 0.22 : 0.12)
                : Color.primary.opacity(day.isToday ? 0.28 : 0.12)
        }
        if day.count >= 8 { return fill }
        return fill.opacity(0.45 + min(0.55, Double(day.count) / 12))
    }

    private func labelColor(_ day: WeekDay) -> Color {
        if onDark {
            return Color.white.opacity(day.isToday ? 0.7 : 0.32)
        }
        return Color.secondary.opacity(day.isToday ? 1 : 0.7)
    }
}
