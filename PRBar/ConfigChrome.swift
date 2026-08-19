import AppKit
import SwiftUI

enum ConfigPalette {
    static let ink = Color.black
    static let inkNS = NSColor.black
    static let line = Color.white.opacity(0.08)
    static let whisper = Color.white.opacity(0.42)
    static let mute = Color.white.opacity(0.55)
    static let paper = Color.white.opacity(0.88)
    static let fill = Color.white.opacity(0.07)
    static let fillStrong = Color.white.opacity(0.12)
    static let gold = Color(red: 0.96, green: 0.82, blue: 0.38)
}

struct ConfigBackdrop: View {
    var body: some View {
        ConfigPalette.ink
            .ignoresSafeArea()
    }
}

struct IslandMini: View {
    let you: Int
    let them: Int
    let rival: String
    let ratio: Double
    var fill: Color = .white

    private var rivalName: String {
        rival.count > 16 ? String(rival.prefix(15)) + "…" : rival
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Text("\(you)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fill)
                Text("you")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConfigPalette.whisper)
                Text("vs")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.28))
                Text(rival.isEmpty ? "–" : "\(them)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                if !rival.isEmpty {
                    Text(rivalName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ConfigPalette.whisper)
                        .lineLimit(1)
                }
            }
            PulseBar(
                ratio: ratio,
                live: false,
                celebrating: false,
                justMerged: false,
                compact: true,
                fill: fill
            )
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 280)
        .background(Color.black, in: Capsule())
        .overlay(Capsule().strokeBorder(ConfigPalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scoreboard preview, \(you) versus \(rival.isEmpty ? "no rival" : rival)")
    }
}

struct GoalStepper: View {
    @Binding var goal: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            step("minus", -5)
            Text("\(goal)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ConfigPalette.paper)
                .frame(minWidth: 28)
            step("plus", 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily goal \(goal)")
    }

    private func step(_ system: String, _ delta: Int) -> some View {
        Button {
            nudge(delta)
        } label: {
            Image(systemName: system)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ConfigPalette.mute)
                .frame(width: 22, height: 22)
                .background(ConfigPalette.fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Increase goal" : "Decrease goal")
    }

    private func nudge(_ delta: Int) {
        let next = ProgressMath.clampGoal(goal + delta)
        if reduceMotion {
            goal = next
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                goal = next
            }
        }
    }
}

struct GoalChips: View {
    @Binding var goal: Int
    var presets: [Int] = [20, 50, 100]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { value in
                chip(value)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily goal \(goal)")
    }

    private func chip(_ value: Int) -> some View {
        let selected = goal == value
        return Button {
            setGoal(value)
        } label: {
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selected ? Color.white : ConfigPalette.fill,
                    in: Capsule()
                )
                .foregroundStyle(selected ? Color.black : ConfigPalette.mute)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily goal \(value)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func stepperButton(system: String, delta: Int) -> some View {
        Button {
            setGoal(goal + delta)
        } label: {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ConfigPalette.paper)
                .frame(width: 26, height: 26)
                .background(ConfigPalette.fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Increase goal" : "Decrease goal")
    }

    private func setGoal(_ value: Int) {
        let next = ProgressMath.clampGoal(value)
        if reduceMotion {
            goal = next
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                goal = next
            }
        }
    }
}

struct RivalEditor: View {
    @Binding var text: String
    var placeholder: String = "someone to beat"
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Text("@")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(ConfigPalette.whisper)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.white.opacity(0.28)))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ConfigPalette.paper)
                .onChange(of: text) { _, value in
                    let cleaned = RivalMath.cleaned(value)
                    if cleaned != value { text = cleaned }
                }
                .onSubmit(onCommit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(ConfigPalette.fill, in: Capsule())
    }
}

struct QuietToggle: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if reduceMotion {
                isOn.toggle()
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isOn.toggle()
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(ConfigPalette.paper)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(ConfigPalette.whisper)
                    }
                }
                Spacer(minLength: 8)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.white : ConfigPalette.fillStrong)
                    Circle()
                        .fill(isOn ? Color.black : Color.white.opacity(0.72))
                        .padding(2)
                }
                .frame(width: 36, height: 22)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

struct QuietButton: View {
    let title: String
    var prominent: Bool = false
    var destructive: Bool = false
    var enabled: Bool = true
    var busy: Bool = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(prominent ? .black : .white)
                }
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
            .opacity(hovered && enabled ? 0.88 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
        .onHover { hovered = $0 && enabled }
        .accessibilityLabel(title)
    }

    private var background: Color {
        if !enabled { return ConfigPalette.fill }
        if prominent { return Color.white }
        if destructive { return Color.white.opacity(0.06) }
        return ConfigPalette.fill
    }

    private var foreground: Color {
        if !enabled { return ConfigPalette.whisper }
        if prominent { return .black }
        if destructive { return MoodColors.losing.opacity(0.9) }
        return ConfigPalette.paper
    }
}

struct ConfigHairline: View {
    var body: some View {
        ConfigPalette.line
            .frame(height: 1)
    }
}

enum ConfigWindowStyle {
    static let onboardingSize = NSSize(width: 400, height: 508)
    static let settingsSize = NSSize(width: 400, height: 528)

    static func apply(_ window: NSWindow) {
        window.backgroundColor = ConfigPalette.inkNS
        window.isOpaque = true
        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.cornerRadius = 26
            content.layer?.masksToBounds = true
            content.layer?.backgroundColor = ConfigPalette.inkNS.cgColor
            content.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
