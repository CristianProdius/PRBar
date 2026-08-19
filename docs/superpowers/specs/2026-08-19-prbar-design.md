# PRBar

Daily merged-PR progress overlay for macOS.

## Goal

A menu-bar companion with an always-on-screen HUD. It counts pull requests **authored by you and merged today** (local timezone) against a configurable daily goal (default 50) and shows how close you are.

## Locked decisions

| Decision | Choice |
|---|---|
| What counts | PRs **merged today** |
| Whose PRs | Authored by the signed-in GitHub user (`CristianProdius` via `gh`) |
| Repo scope | Any repo that user can see — no org/repo allowlist |
| Visual | Compact always-on HUD capsule + menu bar count |
| Auth | Existing `gh` login (token from `gh auth token`) |
| Day boundary | Local calendar midnight, not GitHub UTC date |
| Stack | Native SwiftUI + AppKit `NSPanel` (same overlay pattern as ProWhisper) |
| Persistence | `UserDefaults` for goal and username; Keychain unused (token re-read from `gh`) |
| Shipping | Personal local app, unsandboxed, launch-at-login optional |

## Approaches considered

1. **Native SwiftUI HUD (chosen).** Light, always-on-top, matches ProWhisper overlay, no extra runtime.
2. **Electron / Tauri overlay.** Faster web styling, worse focus/always-on-top behavior, heavier.
3. **Menu bar only.** Simpler, but not an on-screen progress bar.

## Architecture

```
PRBar.app (LSUIElement, no Dock icon)
├── OverlayPanel     NSPanel, non-activating, all Spaces
├── OverlayView      capsule: bar + count; click expands today's PRs
├── MenuBarExtra     "12/50", refresh, goal, quit
├── AppState         source of truth, 3-minute poll + wake + manual refresh
└── GitHubClient     GraphQL search via api.github.com + gh token
```

Units:

- `DayWindow` — start/end of local day; `contains(date)`
- `MergedPR` — title, url, repo, mergedAt
- `GitHubClient` — token, search, decode
- `AppState` — goal, prs, errors, timers
- `OverlayPanel` / `OverlayView` — chrome
- `MenuView` — controls

They talk only through `AppState`. GitHub and date math have no AppKit dependency.

## Data flow

1. Launch → read goal from `UserDefaults` (default 50).
2. Resolve token from `/opt/homebrew/bin/gh auth token` (fallbacks: `/usr/local/bin/gh`, `PATH`).
3. GraphQL `viewer { login }` once; cache username.
4. Search: `is:pr is:merged author:<login> merged:>=<localStart-1day as UTC date>`.
5. Client-filter `mergedAt` into today's `DayWindow`. Paginate if needed (page size 100).
6. Overlay and menu bar render `prs.count / goal`.
7. Repeat every 180s, on Mac wake, and on Refresh.

## UI

- **Collapsed HUD** (~320×36): dark glass capsule, top-center of the main display, 8pt below the menu bar. Track + tabular `12/50`. Draggable.
- **Fill:** amber under 50%, green to 99%, gold at goal.
- **Click:** expand downward to a list of today's merged PRs (repo · title). Click a row to open the PR.
- **Menu bar:** same count; goal stepper; refresh; hide/show HUD; launch at login; quit.
- Does not steal key focus. Lives on all Spaces, including full screen.

## Errors

- No `gh` / no token → HUD shows `—/50` and “Connect GitHub (`gh auth login`)”.
- Network / API error → keep last good count, show a small warning, retry next poll.
- Zero PRs → empty bar, not an error.

## Testing

- Unit tests for `DayWindow` (timezone midnight) and “merged today” filtering.
- No UI tests in v1.

## Out of scope (v1)

- Opened-but-unmerged PRs, reviews, commits, or other metrics
- Org/repo allowlists
- History / streaks / charts
- Multiple GitHub accounts
- Sandbox / App Store
- Windows / Linux
