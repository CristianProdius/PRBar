import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedBar
            if state.isExpanded {
                expandedList
            }
        }
        .frame(width: 328)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .padding(2)
    }

    private var collapsedBar: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                state.isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text("\(state.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fillColor)
                + Text("/\(state.goal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(6, geo.size.width * state.ratio))
                    }
                }
                .frame(height: 7)

                if state.goalMet {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.28))
                        .imageScale(.small)
                } else if state.lastError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.lastError ?? "\(state.count) merged today · goal \(state.goal)")
    }

    private var expandedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.35)

            if let error = state.lastError, state.prs.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else if state.prs.isEmpty {
                Text("No merges yet today")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(state.prs) { pr in
                            Button {
                                state.open(pr)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pr.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(pr.repo)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private var fillColor: Color {
        if state.goalMet { return Color(red: 0.98, green: 0.80, blue: 0.28) }
        if state.ratio < 0.5 { return Color(red: 0.96, green: 0.62, blue: 0.22) }
        return Color(red: 0.42, green: 0.86, blue: 0.48)
    }
}
