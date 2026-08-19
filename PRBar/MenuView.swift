import SwiftUI

struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Button("Settings…") {
                state.openSettings()
            }
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
