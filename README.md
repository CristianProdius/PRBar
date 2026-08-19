# PRBar

On-screen daily progress bar for merged GitHub PRs.

Counts PRs **you authored that merged today** (local midnight) against a goal. Default goal is 50.

## Requirements

- macOS 14+
- [GitHub CLI](https://cli.github.com/) signed in (`gh auth login`)

## Run

```bash
cd ~/Development/PRBar
xcodegen generate
xcodebuild -scheme PRBar -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/PRBar.app
```

The capsule sits under the menu bar. Click it for today’s merges. The menu bar extra has the goal stepper, refresh, hide/show, launch at login, and quit.
