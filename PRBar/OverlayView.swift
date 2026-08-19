import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    private var showFull: Bool {
        state.isHovered || state.menuOpen
    }

    private var paceColor: Color { MoodColors.fill(state.paceMood) }
    private var raceColor: Color { MoodColors.race(state.raceMood) }

    private var islandShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: showFull ? 22 : 18,
            bottomTrailingRadius: showFull ? 22 : 18,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showFull ? 12 : 6) {
            if showFull {
                fullHeader
                raceTrack
                ScrollView(.vertical, showsIndicators: false) {
                    fullDetails
                }
                .frame(maxHeight: 156)
            } else {
                compactRow
                PulseBar(
                    ratio: state.ratio,
                    live: state.paceMood == .critical || state.raceMood == .losing,
                    celebrating: state.paceMood == .done,
                    justMerged: state.justMerged,
                    compact: true,
                    fill: paceColor
                )
                .frame(height: 5)
            }
        }
        .padding(.horizontal, showFull ? 16 : 12)
        .padding(.top, showFull ? 10 : 4)
        .padding(.bottom, showFull ? 14 : 7)
        .frame(width: OverlayPanel.cardWidth, alignment: .leading)
        .background(Color.black, in: islandShape)
        .overlay(islandShape.strokeBorder(paceColor.opacity(state.paceMood == .onTrack ? 0.08 : 0.4), lineWidth: 1))
        .clipShape(islandShape)
        .animation(.easeInOut(duration: 0.2), value: showFull)
        .animation(.easeInOut(duration: 0.35), value: state.paceMood)
        .animation(.easeInOut(duration: 0.35), value: state.raceMood)
    }

    private var compactRow: some View {
        HStack(spacing: 6) {
            Text("\(state.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(paceColor)
            Text("you")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("vs")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(raceColor.opacity(0.6))
            Text(state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.raceMood == .losing ? MoodColors.losing : Color.white)
            Text(rivalShort)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
            Spacer(minLength: 0)
            overflowButton
        }
    }

    private var youLabel: String { "you" }

    private var rivalLabel: String {
        state.rivalUsername.isEmpty ? "rival" : state.rivalUsername
    }

    private var rivalShort: String {
        let name = rivalLabel
        return name.count > 16 ? String(name.prefix(15)) + "…" : name
    }

    private var fullHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(MoodColors.shortLabel(state.paceMood))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(paceColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(paceColor.opacity(0.14), in: Capsule())
                Spacer(minLength: 8)
                overflowButton
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(state.count)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(paceColor)
                Text("/\(state.goal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.28))
                if let badge = deltaBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.leading, 4)
                }
                Spacer(minLength: 0)
            }

            Text(state.moodLine)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
        }
    }

    private var fullDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeekStrip(days: state.weekDays, fill: paceColor, onDark: true)

            if !state.openPRs.isEmpty {
                prSection(title: "In flight", items: Array(state.openPRs.prefix(3)))
            }
            prSection(title: "Merged today", items: Array(state.prs.prefix(3)), empty: state.lastError ?? "None yet")

            rivalField
        }
    }

    private func prSection(title: String, items: [MergedPR], empty: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionLabel(title)
            if items.isEmpty {
                Text(empty ?? "None yet")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.32))
            } else {
                ForEach(items) { pr in
                    prRow(pr)
                }
            }
        }
    }

    private var raceTrack: some View {
        VStack(alignment: .leading, spacing: 5) {
            labeledBar(name: youLabel, score: "\(state.count)", ratio: state.ratio, fill: paceColor)
            labeledBar(
                name: rivalLabel,
                score: state.rivalUsername.isEmpty ? "–" : "\(state.rivalCount)",
                ratio: state.rivalUsername.isEmpty ? 0 : state.rivalRatio,
                fill: state.raceMood == .losing ? MoodColors.losing : Color.white
            )
        }
    }

    private func labeledBar(name: String, score: String, ratio: Double, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text(score)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fill.opacity(0.9))
            }
            PulseBar(ratio: ratio, live: false, celebrating: false, justMerged: false, compact: true, fill: fill)
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(pr.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(1)
                Text(pr.repo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.28))
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

enum MoodColors {
    static let losing = Color(red: 1.0, green: 0.38, blue: 0.36)
    static let winning = Color(red: 0.45, green: 0.92, blue: 0.62)
    static let danger = Color(red: 1.0, green: 0.72, blue: 0.22)
    static let critical = Color(red: 1.0, green: 0.36, blue: 0.32)
    static let gold = Color(red: 0.96, green: 0.82, blue: 0.38)
    static let ahead = Color(red: 0.52, green: 0.94, blue: 0.72)

    static func fill(_ mood: PaceMood) -> Color {
        switch mood {
        case .done: return gold
        case .ahead: return ahead
        case .onTrack: return .white
        case .danger: return danger
        case .critical: return critical
        }
    }

    static func race(_ mood: RaceMood) -> Color {
        switch mood {
        case .winning: return winning
        case .losing: return losing
        case .tied, .none: return .white
        }
    }

    static func shortLabel(_ mood: PaceMood) -> String {
        switch mood {
        case .done: return "Goal hit"
        case .ahead: return "Ahead"
        case .onTrack: return "On pace"
        case .danger: return "Off pace"
        case .critical: return "Danger"
        }
    }
}

struct PulseBar: View {
    let ratio: Double
    let live: Bool
    let celebrating: Bool
    let justMerged: Bool
    let compact: Bool
    var fill: Color = .white

    private let segments = 22

    @State private var revealed = 0
    @State private var hoverIndex: Int?

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
        }
        .onChange(of: targetFilled) { _, value in
            withAnimation(.easeOut(duration: 0.35)) {
                revealed = value
            }
        }
    }

    private var targetFilled: Int {
        Int((ratio * Double(segments)).rounded())
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
            return MoodColors.gold
        }
        if isFilled(index) {
            if live {
                let dist = Double(max(0, revealed - 1 - index))
                let wave = (sin(time * 4.2 - dist * 0.55) + 1) / 2
                return fill.opacity(0.72 + 0.28 * wave)
            }
            return fill
        }
        return fill.opacity(0.14)
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
