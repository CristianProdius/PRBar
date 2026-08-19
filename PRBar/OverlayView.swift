import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let whisper = state.whisperTitle, !state.isExpanded {
                Text(whisper)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
                    .transition(.opacity)
            }
            PulseBar(
                ratio: state.ratio,
                celebrating: state.celebrating,
                justMerged: state.justMerged
            )
            if state.isExpanded {
                expandedList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: state.isExpanded ? 320 : 292, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    state.celebrating
                        ? Color.white.opacity(0.28)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(state.celebrating ? 1.02 : 1)
        .animation(.spring(duration: 0.45, bounce: 0.28), value: state.celebrating)
        .animation(.snappy(duration: 0.22), value: state.isExpanded)
        .animation(.snappy(duration: 0.22), value: state.whisperTitle)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.goalMet ? "Goal hit" : "Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.38))
                .lineLimit(1)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        state.isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(state.count)")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                        Text("/\(state.goal)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.32))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let badge = deltaBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(badge.up ? Color.white : Color.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                Text("vs yesterday")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.32))

                Spacer(minLength: 0)
            }
        }
    }

    private var expandedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeekStrip(days: state.weekDays, fill: Color.white, onDark: true)
                .padding(.top, 2)

            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.prs.isEmpty {
                Text("No merges yet today")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.38))
            } else {
                ForEach(state.prs.prefix(5)) { pr in
                    Button {
                        state.open(pr)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(1)
                            Text(pr.repo)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.32))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
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
    let celebrating: Bool
    let justMerged: Bool

    private let segments = 22

    @State private var pulse = false
    @State private var hoverIndex: Int?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(color(for: index))
                    .frame(width: 8, height: height(for: index))
                    .opacity(opacity(for: index))
                    .shadow(color: glow(for: index), radius: hoverIndex == index ? 6 : 0)
                    .animation(.easeInOut(duration: 0.18), value: hoverIndex)
                    .animation(.easeInOut(duration: 1.05), value: pulse)
                    .animation(.spring(duration: 0.45, bounce: 0.2), value: filledCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let width: CGFloat = 11
                hoverIndex = min(segments - 1, max(0, Int(location.x / width)))
            case .ended:
                hoverIndex = nil
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var filledCount: Int {
        Int((ratio * Double(segments)).rounded())
    }

    private func isFilled(_ index: Int) -> Bool {
        index < filledCount
    }

    private func color(for index: Int) -> Color {
        if hoverIndex == index {
            return Color(red: 0.31, green: 0.58, blue: 1.0)
        }
        if celebrating && isFilled(index) {
            return Color(red: 0.98, green: 0.86, blue: 0.42)
        }
        if isFilled(index) {
            return Color.white
        }
        return Color.white.opacity(0.12)
    }

    private func height(for index: Int) -> CGFloat {
        if hoverIndex == index { return 26 }
        if index == filledCount - 1 && pulse { return 24 }
        return 22
    }

    private func opacity(for index: Int) -> Double {
        if hoverIndex == index { return 1 }
        if !isFilled(index) { return 1 }
        if index == filledCount - 1 {
            return pulse ? 1 : 0.45
        }
        if justMerged && index >= filledCount - 3 {
            return pulse ? 1 : 0.6
        }
        return 1
    }

    private func glow(for index: Int) -> Color {
        hoverIndex == index ? Color(red: 0.31, green: 0.58, blue: 1.0).opacity(0.85) : .clear
    }
}

struct WeekStrip: View {
    let days: [WeekDay]
    let fill: Color
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                VStack(spacing: 2) {
                    Capsule()
                        .fill(tickColor(day))
                        .frame(width: day.isToday ? 14 : 11, height: 4)
                    Text(day.label)
                        .font(.system(size: 7, weight: day.isToday ? .semibold : .medium, design: .rounded))
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
