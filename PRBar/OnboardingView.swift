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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let goalPresets = [20, 50, 100]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    githubCard
                    goalCard
                    rivalCard
                    if let startError {
                        Text(startError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 16)
            }
            footer
        }
        .frame(width: 460, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            goalDraft = state.goal
            rivalDraft = state.rivalUsername
        }
        .task { await state.probeGitHub() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            islandPreview
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Set up your race")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("PRBar counts the PRs you merge today and pins the score to the MacBook notch. Pick a daily goal and someone to race.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var islandPreview: some View {
        let rival = RivalMath.cleaned(rivalDraft)
        return HStack(spacing: 6) {
            Text("0")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("you")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("vs")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
            Text("0")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            if !rival.isEmpty {
                Text(rival)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Color.black, in: Capsule())
        .accessibilityLabel("Preview of the notch scoreboard")
    }

    private var githubCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("GitHub")
            HStack(alignment: .top, spacing: 10) {
                statusDot
                VStack(alignment: .leading, spacing: 4) {
                    Text(githubTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Text(githubDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if state.githubStatus.isChecking {
                    ProgressView().controlSize(.small)
                }
            }
            if !state.githubStatus.isSignedIn {
                HStack(spacing: 8) {
                    Button(copiedLogin ? "Copied" : "Copy gh auth login") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("gh auth login", forType: .string)
                        copiedLogin = true
                    }
                    Button("Check again") {
                        Task { await state.probeGitHub() }
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Daily goal")
            Text("How many merges you want by midnight.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(goalPresets, id: \.self) { value in
                    Button {
                        if !reduceMotion {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                goalDraft = value
                            }
                        } else {
                            goalDraft = value
                        }
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                goalDraft == value ? Color.accentColor : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .foregroundStyle(goalDraft == value ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Daily goal \(value)")
                    .accessibilityAddTraits(goalDraft == value ? [.isSelected] : [])
                }
            }
            Stepper(value: $goalDraft, in: 1...500, step: 5) {
                Text("Custom  \(goalDraft)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rivalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Who do you want to race?")
            Text("Another GitHub username. Optional — you can add this later in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("@")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                TextField("username", text: $rivalDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .monospaced))
                    .onChange(of: rivalDraft) { _, value in
                        let cleaned = RivalMath.cleaned(value)
                        if cleaned != value {
                            rivalDraft = cleaned
                        }
                        startError = nil
                    }
                    .onSubmit { startTapped() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            Button(action: startTapped) {
                HStack(spacing: 8) {
                    if isStarting {
                        ProgressView().controlSize(.small)
                    }
                    Text(isStarting ? "Starting…" : "Start racing")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart || isStarting)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Start racing")
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var canStart: Bool {
        state.githubStatus.isSignedIn
    }

    private var githubTitle: String {
        switch state.githubStatus {
        case .idle, .checking: return "Checking GitHub CLI…"
        case .signedIn(let login): return "Signed in as @\(login)"
        case .missingCLI: return "GitHub CLI is not installed"
        case .notSignedIn: return "Not signed in to GitHub"
        case .failed: return "Could not reach GitHub"
        }
    }

    private var githubDetail: String {
        switch state.githubStatus {
        case .idle, .checking:
            return "Using your existing gh login."
        case .signedIn:
            return "PRBar will count PRs you authored and merged today."
        case .missingCLI:
            return "Install gh with Homebrew, then run gh auth login."
        case .notSignedIn:
            return "Run gh auth login in Terminal, then check again."
        case .failed(let message):
            return message
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(githubDotColor)
            .frame(width: 9, height: 9)
            .padding(.top, 5)
            .accessibilityHidden(true)
    }

    private var githubDotColor: Color {
        switch state.githubStatus {
        case .signedIn: return Color(red: 0.22, green: 0.78, blue: 0.45)
        case .checking, .idle: return Color.secondary.opacity(0.5)
        case .missingCLI, .notSignedIn, .failed: return Color(red: 1.0, green: 0.45, blue: 0.32)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
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
                        startError = "No GitHub user named @\(rival)."
                        isStarting = false
                        return
                    }
                } catch {
                    // Network blip — still let them race; refresh will retry.
                }
            }
            state.completeOnboarding(goal: goalDraft, rival: rival)
            onFinished()
        }
    }
}
