import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    private var showWide: Bool {
        state.isHovered || state.isExpanded || state.justMerged || state.celebrating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            islandBar
            if let whisper = state.whisperTitle, !state.isExpanded {
                Text(whisper)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            WeekStrip(days: state.weekDays, fill: fillColor)
            if state.isExpanded {
                expandedList
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, state.isExpanded ? 10 : 8)
        .frame(width: state.isExpanded ? 300 : (showWide ? 268 : 200), alignment: .leading)
        .background { IslandBackground(expanded: state.isExpanded, celebrating: state.celebrating) }
        .clipShape(islandShape)
        .overlay(
            islandShape.strokeBorder(
                state.celebrating ? Color(red: 0.98, green: 0.82, blue: 0.32).opacity(0.95) : Color.white.opacity(0.18),
                lineWidth: state.celebrating ? 1.4 : 0.8
            )
        )
        .scaleEffect(state.celebrating ? 1.06 : (state.justMerged ? 1.03 : 1))
        .animation(.spring(duration: 0.42, bounce: 0.34), value: state.justMerged)
        .animation(.spring(duration: 0.5, bounce: 0.28), value: state.celebrating)
        .animation(.snappy(duration: 0.22), value: showWide)
        .animation(.snappy(duration: 0.22), value: state.isExpanded)
        .animation(.snappy(duration: 0.22), value: state.whisperTitle)
    }

    private var islandShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: state.isExpanded ? 18 : 18, style: .continuous)
    }

    private var islandBar: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                state.isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(state.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fillColor)
                Text("/\(state.goal)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.55))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(7, geo.size.width * state.ratio))
                            .shadow(color: fillColor.opacity(0.55), radius: 4, y: 0)
                            .animation(.spring(duration: 0.5, bounce: 0.18), value: state.ratio)
                    }
                }
                .frame(height: 5)

                if state.celebrating {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.32))
                        .transition(.scale.combined(with: .opacity))
                } else if state.justMerged {
                    Text("+1")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(fillColor)
                        .transition(.scale.combined(with: .opacity))
                } else if state.goalMet {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.32))
                } else if state.lastError != nil {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var expandedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.top, 4)

            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.prs.isEmpty {
                Text("No merges yet today")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
            } else {
                ForEach(state.prs.prefix(6)) { pr in
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
                                .foregroundStyle(Color.white.opacity(0.38))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if state.prs.count > 6 {
                    Text("+\(state.prs.count - 6) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
        }
    }

    private var fillColor: Color {
        if state.goalMet || state.celebrating { return Color(red: 0.98, green: 0.82, blue: 0.32) }
        if state.ratio < 0.5 { return Color(red: 1.0, green: 0.68, blue: 0.28) }
        return Color(red: 0.46, green: 0.90, blue: 0.52)
    }

    private var helpText: String {
        if let error = state.lastError { return error }
        if let latest = state.prs.first {
            return "\(state.count)/\(state.goal) · last: \(latest.title)"
        }
        return "\(state.count) merged today · goal \(state.goal)"
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

private struct IslandBackground: NSViewRepresentable {
    var expanded: Bool
    var celebrating: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.cornerCurve = .continuous
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = expanded ? 18 : 18
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(celebrating ? 0.12 : 0.22).cgColor
    }
}
