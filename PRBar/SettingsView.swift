import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            ConfigBackdrop()
            VStack(alignment: .leading, spacing: 0) {
                header
                ConfigHairline()
                    .padding(.vertical, 16)
                raceFields
                ConfigHairline()
                    .padding(.vertical, 16)
                islandToggles
                Spacer(minLength: 14)
                footer
            }
            .padding(.horizontal, 28)
            .padding(.top, 42)
            .padding(.bottom, 22)
        }
        .frame(width: ConfigWindowStyle.settingsSize.width, height: ConfigWindowStyle.settingsSize.height)
        .preferredColorScheme(.dark)
        .task {
            if case .idle = state.githubStatus {
                await state.probeGitHub()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            IslandMini(
                you: state.count,
                them: state.rivalCount,
                rival: state.rivalUsername,
                ratio: state.ratio,
                fill: MoodColors.fill(state.paceMood)
            )
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Text(state.username.isEmpty ? "Not signed in" : "@\(state.username)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ConfigPalette.mute)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                Text(MoodColors.shortLabel(state.paceMood))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(MoodColors.fill(state.paceMood))
            }
            if case .failed(let message) = state.githubStatus {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(MoodColors.losing)
            }
        }
    }

    private var raceFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("Goal")
                    Spacer()
                    GoalStepper(goal: Binding(
                        get: { state.goal },
                        set: { state.setGoal($0) }
                    ))
                }
                GoalChips(goal: Binding(
                    get: { state.goal },
                    set: { state.setGoal($0) }
                ))
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("Rival")
                    Spacer()
                    if RivalMath.cleaned(state.rivalDraft) != state.rivalUsername {
                        Button("Save") {
                            state.setRival(state.rivalDraft)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ConfigPalette.paper)
                    }
                }
                RivalEditor(text: $state.rivalDraft, placeholder: "someone to beat") {
                    state.setRival(state.rivalDraft)
                }
            }
        }
    }

    private var islandToggles: some View {
        VStack(spacing: 12) {
            QuietToggle(title: "On-screen island", detail: "Pin to the notch", isOn: $state.hudVisible)
            QuietToggle(title: "Hide on fullscreen", isOn: $state.hideInFullscreen)
            QuietToggle(title: "Sound on merge", isOn: $state.soundEnabled)
            QuietToggle(
                title: "Launch at login",
                isOn: Binding(
                    get: { state.launchesAtLogin },
                    set: { _ in state.toggleLaunchAtLogin() }
                )
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerLink("Snap") { state.resetBarPosition() }
            footerDot
            footerLink("Refresh") { Task { await state.refresh() } }
            footerDot
            footerLink("Quit", destructive: true) { state.quit() }
        }
        .frame(maxWidth: .infinity)
    }

    private var footerDot: some View {
        Text("·")
            .foregroundStyle(Color.white.opacity(0.22))
            .padding(.horizontal, 10)
    }

    private func footerLink(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(destructive ? MoodColors.losing.opacity(0.85) : ConfigPalette.mute)
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ConfigPalette.whisper)
    }
}
