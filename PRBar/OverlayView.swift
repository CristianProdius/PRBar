import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    private var showFull: Bool {
        state.isHovered || state.menuOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: showFull ? 12 : 6) {
                if showFull {
                    fullHeader
                } else {
                    compactRow
                }

                PulseBar(
                    ratio: state.ratio,
                    live: showFull,
                    celebrating: state.celebrating,
                    justMerged: state.justMerged,
                    compact: !showFull
                )
                .frame(height: showFull ? 32 : 8)

                if showFull {
                    fullDetails
                }
            }
            .padding(.horizontal, showFull ? 18 : 12)
            .padding(.vertical, showFull ? 14 : 8)
            .frame(width: 400, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: showFull ? 20 : 16, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: showFull ? 20 : 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .frame(width: 400, height: 340, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.22), value: showFull)
    }

    private var compactRow: some View {
        HStack(spacing: 8) {
            Text("\(state.count)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
            Text("you")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))

            Text("vs")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.22))

            Text(rivalShort)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
            Text(state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)

            Spacer(minLength: 8)

            overflowButton
        }
    }

    private var youLabel: String { "you" }

    private var rivalLabel: String {
        state.rivalUsername.isEmpty ? "rival" : state.rivalUsername
    }

    private var rivalShort: String {
        let name = rivalLabel
        return name.count > 12 ? String(name.prefix(11)) + "…" : name
    }

    private var fullHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.goalMet ? "Goal hit" : "Today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                overflowButton
            }

            Text(state.raceHeadline)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(state.count)")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                    Text("/\(state.goal)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.32))
                }

                if let badge = deltaBadge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
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
        VStack(alignment: .leading, spacing: 12) {
            raceTrack

            WeekStrip(days: state.weekDays, fill: Color.white, onDark: true)

            rivalField

            if !state.openPRs.isEmpty {
                sectionLabel("In flight")
                ForEach(state.openPRs.prefix(4)) { pr in
                    prRow(pr, dim: false)
                }
            }

            sectionLabel(state.prs.isEmpty ? "Merged today" : "Merged today")
            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else if state.prs.isEmpty {
                Text("None yet — open PRs still count as in flight")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
            } else {
                ForEach(state.prs.prefix(4)) { pr in
                    prRow(pr, dim: false)
                }
            }
        }
    }

    private var raceTrack: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(youLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("\(state.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            PulseBar(
                ratio: state.ratio,
                live: false,
                celebrating: state.celebrating && state.count >= state.rivalCount,
                justMerged: false,
                compact: true
            )
            .frame(height: 10)

            HStack {
                Text(rivalLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text(state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            PulseBar(
                ratio: state.rivalUsername.isEmpty ? 0 : state.rivalRatio,
                live: false,
                celebrating: state.rivalCount > state.count,
                justMerged: false,
                compact: true
            )
            .frame(height: 10)
        }
    }

    private var rivalField: some View {
        HStack(spacing: 8) {
            Text("@")
                .foregroundStyle(Color.white.opacity(0.3))
            TextField("friend’s GitHub username", text: $state.rivalUsername)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .onSubmit { state.setRival(state.rivalUsername) }
            Button("Race") {
                state.setRival(state.rivalUsername)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Color.white.opacity(0.32))
    }

    private func prRow(_ pr: MergedPR, dim: Bool) -> some View {
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
    }

    private var subtitle: String {
        if state.goalMet { return "You hit today’s merge goal" }
        if let error = state.lastError { return error }
        let remaining = max(0, state.goal - state.count)
        let open = state.openPRs.count
        if open > 0 {
            return "\(open) open · \(remaining) more merges to goal"
        }
        return "\(remaining) more to hit today’s goal"
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
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: live ? 1.0 / 24.0 : 1.0, paused: !live)) { timeline in
                let time = live ? timeline.date.timeIntervalSinceReferenceDate : 0
                let spacing: CGFloat = compact ? 2 : 3
                let tickWidth = max(3, (geo.size.width - spacing * CGFloat(segments - 1)) / CGFloat(segments))
                let tickHeight = compact ? max(6, geo.size.height) : max(18, geo.size.height - 4)
                HStack(spacing: spacing) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: compact ? 1.5 : 2.5, style: .continuous)
                            .fill(color(for: index, time: time))
                            .frame(width: tickWidth, height: tickHeight)
                            .scaleEffect(y: scale(for: index, time: time), anchor: .bottom)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .onContinuousHover { phase in
                guard live else {
                    hoverIndex = nil
                    return
                }
                switch phase {
                case .active(let location):
                    let step = max(1, geo.size.width / CGFloat(segments))
                    hoverIndex = min(segments - 1, max(0, Int(location.x / step)))
                case .ended:
                    hoverIndex = nil
                }
            }
        }
        .onAppear {
            revealed = compact ? targetFilled : 0
            if live { playReveal() }
        }
        .onChange(of: live) { _, on in
            if on { playReveal() } else {
                revealTask?.cancel()
                revealed = targetFilled
            }
        }
        .onChange(of: targetFilled) { _, _ in
            if !live { revealed = targetFilled }
        }
    }

    private var targetFilled: Int {
        Int((ratio * Double(segments)).rounded())
    }

    private func playReveal() {
        revealTask?.cancel()
        revealed = 0
        revealTask = Task { @MainActor in
            let total = max(targetFilled, 0)
            for index in 0...total {
                if Task.isCancelled { return }
                revealed = index
                try? await Task.sleep(nanoseconds: 22_000_000)
            }
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        index < revealed
    }

    private func scale(for index: Int, time: TimeInterval) -> CGFloat {
        if hoverIndex == index { return 1.18 }
        guard live, isFilled(index) else { return 1 }
        let dist = Double(max(0, revealed - 1 - index))
        let wave = sin(time * 4.2 - dist * 0.55)
        return 1 + CGFloat(max(0, wave) * 0.16)
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
                return Color.white.opacity(0.72 + 0.28 * wave)
            }
            return Color.white
        }
        return Color.white.opacity(0.12)
    }
}

struct WeekStrip: View {
    let days: [WeekDay]
    let fill: Color
    var onDark: Bool = true

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 5) {
            GridRow {
                ForEach(days) { day in
                    Capsule()
                        .fill(tickColor(day))
                        .frame(width: 14, height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            GridRow {
                ForEach(days) { day in
                    Text(day.label)
                        .font(.system(size: 9, weight: day.isToday ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(labelColor(day))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func tickColor(_ day: WeekDay) -> Color {
        if day.count == 0 {
            return onDark
                ? Color.white.opacity(day.isToday ? 0.28 : 0.12)
                : Color.primary.opacity(day.isToday ? 0.28 : 0.12)
        }
        if day.count >= 8 { return fill }
        return fill.opacity(0.45 + min(0.55, Double(day.count) / 12))
    }

    private func labelColor(_ day: WeekDay) -> Color {
        if onDark {
            return Color.white.opacity(day.isToday ? 0.78 : 0.38)
        }
        return Color.secondary.opacity(day.isToday ? 1 : 0.7)
    }
}
