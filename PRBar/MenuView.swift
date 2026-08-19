import SwiftUI

struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(state.count)/\(state.goal)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if !state.rivalUsername.isEmpty {
                        Text("you \(state.count)  vs  \(state.rivalCount) @\(state.rivalUsername)")
                            .font(.caption.weight(.medium))
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

            WeekStrip(days: state.weekDays, fill: Color.accentColor, onDark: false)
                .padding(.vertical, 2)

            if !state.openPRs.isEmpty {
                Text("\(state.openPRs.count) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let latest = state.prs.first {
                Text(latest.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let error = state.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No merges yet today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let username = Optional(state.username), !username.isEmpty {
                Text("@\(username)" + (state.lastUpdated.map { " · \($0.formatted(date: .omitted, time: .shortened))" } ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack {
                Text("Rival")
                TextField("github username", text: $state.rivalDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.setRival(state.rivalDraft) }
            }
            if !state.rivalUsername.isEmpty {
                Text(state.raceHeadline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Button("Bring bar here") {
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
