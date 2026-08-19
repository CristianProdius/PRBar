import SwiftUI

struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                if state.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            Text("\(state.count) / \(state.goal) merged")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()

            if let updated = state.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let username = Optional(state.username), !username.isEmpty {
                Text("@\(username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = state.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Stepper(value: Binding(
                get: { state.goal },
                set: { state.setGoal($0) }
            ), in: 1...500, step: 5) {
                Text("Daily goal: \(state.goal)")
            }

            Toggle("Show on-screen bar", isOn: $state.hudVisible)
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchesAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))

            Divider()

            Button("Refresh") {
                Task { await state.refresh() }
            }
            Button("Quit PRBar") {
                state.quit()
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
