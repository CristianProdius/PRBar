import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    private var showFull: Bool {
        state.isHovered || state.menuOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showFull ? 10 : 5) {
            if showFull {
                fullHeader
            } else {
                compactRow
            }

            if showFull {
                raceTrack
                ScrollView(.vertical, showsIndicators: false) {
                    fullDetails
                }
                .frame(maxHeight: 168)
            } else {
                PulseBar(
                    ratio: state.ratio,
                    live: false,
                    celebrating: state.celebrating,
                    justMerged: state.justMerged,
                    compact: true
                )
                .frame(height: 7)
            }
        }
        .padding(.horizontal, showFull ? 14 : 10)
        .padding(.vertical, showFull ? 12 : 7)
        .frame(width: OverlayPanel.cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: showFull ? 16 : 12, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: showFull ? 16 : 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: showFull)
    }

    private var compactRow: some View {
        HStack(spacing: 6) {
            Text("\(state.count)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
            Text("you")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))

            Text("vs")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.2))

            Text(rivalShort)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
                .lineLimit(1)
            Text(state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)

            Spacer(minLength: 4)
            overflowButton
        }
    }

    private var youLabel: String { "you" }

    private var rivalLabel: String {
        state.rivalUsername.isEmpty ? "rival" : state.rivalUsername
    }

    private var rivalShort: String {
        let name = rivalLabel
        return name.count > 10 ? String(name.prefix(9)) + "…" : name
    }

    private var fullHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(state.goalMet ? "Goal hit" : "Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                Text(state.raceHeadline)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .lineLimit(1)
                Spacer(minLength: 0)
                overflowButton
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(state.count)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                Text("/\(state.goal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.3))
                if let badge = deltaBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                Text("vs yesterday")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
                Spacer(minLength: 0)
            }
        }
    }

    private var fullDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            WeekStrip(days: state.weekDays, fill: Color.white, onDark: true)

            rivalField

            if !state.openPRs.isEmpty {
                sectionLabel("In flight")
                ForEach(state.openPRs.prefix(3)) { pr in
                    prRow(pr)
                }
            }

            sectionLabel("Merged today")
            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else if state.prs.isEmpty {
                Text("None yet")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
            } else {
                ForEach(state.prs.prefix(3)) { pr in
                    prRow(pr)
                }
            }
        }
    }

    private var raceTrack: some View {
        VStack(alignment: .leading, spacing: 5) {
            labeledBar(name: youLabel, score: "\(state.count)", ratio: state.ratio, gold: state.celebrating)
            labeledBar(
                name: rivalLabel,
                score: state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)",
                ratio: state.rivalUsername.isEmpty ? 0 : state.rivalRatio,
                gold: state.rivalCount > state.count && !state.rivalUsername.isEmpty
            )
        }
    }

    private func labeledBar(name: String, score: String, ratio: Double, gold: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text(score)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            PulseBar(ratio: ratio, live: false, celebrating: gold, justMerged: false, compact: true)
                .frame(height: 8)
        }
    }

    private var rivalField: some View {
        HStack(spacing: 6) {
            Text("@")
                .foregroundStyle(Color.white.opacity(0.3))
            TextField("friend’s GitHub", text: $state.rivalDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .onSubmit { state.setRival(state.rivalDraft) }
            Button("Race") {
                state.setRival(state.rivalDraft)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.white.opacity(0.3))
    }

    private func prRow(_ pr: MergedPR) -> some View {
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Actions")
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

    private let segments = 22

    @State private var revealed = 0
    @State private var hoverIndex: Int?
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: live ? 1.0 / 24.0 : 1.0, paused: !live)) { timeline in
                let time = live ? timeline.date.timeIntervalSinceReferenceDate : 0
                let spacing: CGFloat = 2
                let tickWidth = max(3, (geo.size.width - spacing * CGFloat(segments - 1)) / CGFloat(segments))
                HStack(spacing: spacing) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.6, style: .continuous)
                            .fill(color(for: index, time: time))
                            .frame(width: tickWidth, height: geo.size.height)
                            .scaleEffect(y: scale(for: index, time: time), anchor: .center)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
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
            revealed = targetFilled
            if live { playReveal() }
        }
        .onChange(of: live) { _, on in
            if on { playReveal() } else {
                revealTask?.cancel()
                revealed = targetFilled
            }
        }
        .onChange(of: targetFilled) { _, value in
            if !live { revealed = value }
        }
    }

    private var targetFilled: Int {
        Int((ratio * Double(segments)).rounded())
    }

    private func playReveal() {
        revealTask?.cancel()
        revealed = 0
        revealTask = Task { @MainActor in
            for index in 0...max(targetFilled, 0) {
                if Task.isCancelled { return }
                revealed = index
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        index < revealed
    }

    private func scale(for index: Int, time: TimeInterval) -> CGFloat {
        if hoverIndex == index { return 1.12 }
        guard live, isFilled(index) else { return 1 }
        let dist = Double(max(0, revealed - 1 - index))
        let wave = sin(time * 4.2 - dist * 0.55)
        return 1 + CGFloat(max(0, wave) * 0.1)
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
                return Color.white.opacity(0.75 + 0.25 * wave)
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
        Grid(horizontalSpacing: 0, verticalSpacing: 4) {
            GridRow {
                ForEach(days) { day in
                    Capsule()
                        .fill(tickColor(day))
                        .frame(width: 12, height: 4)
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
