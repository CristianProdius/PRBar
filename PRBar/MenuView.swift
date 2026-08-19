import SwiftUI

struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MoodColors.shortLabel(state.paceMood))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MoodColors.fill(state.paceMood))
                    Text("\(state.count)/\(state.goal)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if !state.rivalUsername.isEmpty {
                        Text("you \(state.count)  vs  \(state.rivalCount) @\(state.rivalUsername)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if state.streak > 0 {
                    Label("\(state.streak)d", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                if state.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            Text(state.moodLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            WeekStrip(days: state.weekDays, fill: MoodColors.fill(state.paceMood), onDark: false)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Rival")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("github username", text: $state.rivalDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.setRival(state.rivalDraft) }
            }

            Stepper(value: Binding(
                get: { state.goal },
                set: { state.setGoal($0) }
            ), in: 1...500, step: 5) {
                Text("Daily goal")
            }

            Toggle("On-screen bar", isOn: $state.hudVisible)
            Toggle("Hide on fullscreen spaces", isOn: $state.hideInFullscreen)
            Toggle("Sound on merge", isOn: $state.soundEnabled)
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchesAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))

            Button("Snap to notch") {
                state.resetBarPosition()
            }

            Divider()

            Button("Refresh") {
                Task { await state.refresh() }
            }
            Button("Quit PRBar") {
                state.quit()
            }
        }
        .padding(12)
        .frame(width: 268)
    }
}
