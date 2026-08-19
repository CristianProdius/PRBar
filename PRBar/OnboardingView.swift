import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: AppState
    var onFinished: () -> Void

    @State private var goalDraft = 50
    @State private var rivalDraft = ""
    @State private var didPrefill = false
    @State private var isStarting = false
    @State private var startError: String?
    @State private var copiedLogin = false

    var body: some View {
        ZStack {
            ConfigBackdrop()
            VStack(alignment: .leading, spacing: 26) {
                header
                fields
                if let startError {
                    Text(startError)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MoodColors.losing)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                QuietButton(
                    title: isStarting ? "Opening the board…" : "Start the race",
                    prominent: true,
                    enabled: canStart,
                    busy: isStarting,
                    action: startTapped
                )
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.top, 42)
            .padding(.bottom, 26)
        }
        .frame(width: ConfigWindowStyle.onboardingSize.width, height: ConfigWindowStyle.onboardingSize.height)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            goalDraft = state.goal
            rivalDraft = state.rivalUsername
        }
        .task { await state.probeGitHub() }
    }

    private var header: some View {
        VStack(spacing: 18) {
            IslandMini(
                you: 0,
                them: 0,
                rival: RivalMath.cleaned(rivalDraft),
                ratio: ProgressMath.ratio(count: 0, goal: max(goalDraft, 1)),
                fill: .white
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: 7) {
                Text("Make it a race.")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConfigPalette.paper)
                    .multilineTextAlignment(.center)
                Text("A daily goal. One rival. The notch keeps score.")
                    .font(.system(size: 13))
                    .foregroundStyle(ConfigPalette.whisper)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            githubRow
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("Goal")
                    Spacer()
                    GoalStepper(goal: $goalDraft)
                }
                GoalChips(goal: $goalDraft)
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Rival")
                RivalEditor(text: $rivalDraft, placeholder: "someone to beat") {
                    startTapped()
                }
            }
        }
    }

    private var githubRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(githubDot)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(githubTitle)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(ConfigPalette.paper)
                if !state.githubStatus.isSignedIn {
                    Text(githubDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(ConfigPalette.whisper)
                }
            }
            Spacer(minLength: 8)
            if state.githubStatus.isChecking {
                ProgressView().controlSize(.small).tint(.white)
            } else if !state.githubStatus.isSignedIn {
                Button(copiedLogin ? "Copied" : "Copy login") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("gh auth login", forType: .string)
                    copiedLogin = true
                    Task { await state.probeGitHub() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ConfigPalette.paper)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ConfigPalette.fill, in: Capsule())
                .accessibilityLabel(copiedLogin ? "Copied gh auth login" : "Copy gh auth login")
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ConfigPalette.whisper)
    }

    private var canStart: Bool { state.githubStatus.isSignedIn }

    private var githubTitle: String {
        switch state.githubStatus {
        case .idle, .checking: return "Finding GitHub…"
        case .signedIn(let login): return "@\(login)"
        case .missingCLI: return "Install gh, then come back"
        case .notSignedIn: return "Sign in with gh"
        case .failed: return "GitHub is quiet"
        }
    }

    private var githubDetail: String {
        switch state.githubStatus {
        case .idle, .checking: return "Reading your gh session."
        case .signedIn: return ""
        case .missingCLI: return "brew install gh"
        case .notSignedIn: return "gh auth login"
        case .failed(let message): return message
        }
    }

    private var githubDot: Color {
        switch state.githubStatus {
        case .signedIn: return MoodColors.winning
        case .checking, .idle: return ConfigPalette.whisper
        case .missingCLI, .notSignedIn, .failed: return MoodColors.losing
        }
    }

    private func startTapped() {
        guard canStart, !isStarting else { return }
        isStarting = true
        startError = nil
        Task {
            let rival = RivalMath.cleaned(rivalDraft)
            if !rival.isEmpty {
                do {
                    let exists = try await state.userExists(rival)
                    if !exists {
                        startError = "No one on GitHub named @\(rival)."
                        isStarting = false
                        return
                    }
                } catch {
                    // Keep going; the board will retry.
                }
            }
            state.completeOnboarding(goal: goalDraft, rival: rival)
            onFinished()
        }
    }
}
