import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            if !state.hasCompletedOnboarding {
                Section {
                    Text("Finish setup to pin the island to your notch.")
                        .foregroundStyle(.secondary)
                    Button("Start racing") {
                        state.completeOnboarding(goal: state.goal, rival: state.rivalDraft)
                    }
                }
            }

            Section("GitHub") {
                LabeledContent("Account") {
                    Text(state.username.isEmpty ? "Not connected" : "@\(state.username)")
                        .font(.body.monospaced())
                        .foregroundStyle(state.username.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                if case .failed(let message) = state.githubStatus {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Recheck GitHub") {
                    Task { await state.probeGitHub() }
                }
            }

            Section("Race") {
                Stepper(value: Binding(
                    get: { state.goal },
                    set: { state.setGoal($0) }
                ), in: 1...500, step: 5) {
                    LabeledContent("Daily goal") {
                        Text("\(state.goal)")
                            .font(.body.monospacedDigit())
                    }
                }
                HStack {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("Rival GitHub username", text: $state.rivalDraft)
                        .onChange(of: state.rivalDraft) { _, value in
                            let cleaned = RivalMath.cleaned(value)
                            if cleaned != value { state.rivalDraft = cleaned }
                        }
                        .onSubmit { state.setRival(state.rivalDraft) }
                }
                Button("Update rival") {
                    state.setRival(state.rivalDraft)
                }
                .disabled(RivalMath.cleaned(state.rivalDraft) == state.rivalUsername)
            }

            Section("Island") {
                Toggle("On-screen island", isOn: $state.hudVisible)
                Toggle("Hide on fullscreen spaces", isOn: $state.hideInFullscreen)
                Toggle("Sound on merge", isOn: $state.soundEnabled)
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchesAtLogin },
                    set: { _ in state.toggleLaunchAtLogin() }
                ))
                Button("Snap to notch") {
                    state.resetBarPosition()
                }
            }

            Section {
                Button("Refresh counts") {
                    Task { await state.refresh() }
                }
                Button("Quit PRBar", role: .destructive) {
                    state.quit()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 440, minHeight: 460)
        .task {
            if case .idle = state.githubStatus {
                await state.probeGitHub()
            }
        }
    }
}
