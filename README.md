# PRBar

A macOS overlay that tracks how many GitHub PRs **you authored and merged today**, races a friend live, and sits on screen as a compact progress card.

## What it does

- Counts your merged PRs since local midnight against a daily goal (default 50)
- Shows open PRs as **in flight**
- Live **you vs rival** scoreboard (another GitHub username)
- Compact strip when idle; hover to open the full card
- `⋯` opens Refresh, hide, sound, launch-at-login, quit
- Polls GitHub every 45 seconds using your existing `gh` login

## Requirements

- macOS 14+
- [Xcode](https://developer.apple.com/xcode/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [GitHub CLI](https://cli.github.com/) signed in (`gh auth login`)

## Run

```bash
git clone git@github.com:CristianProdius/PRBar.git
cd PRBar
xcodegen generate
xcodebuild -scheme PRBar -configuration Release -destination 'platform=macOS'
open build/Build/Products/Release/PRBar.app
```

If you skip `-derivedDataPath`, Xcode writes the app under `~/Library/Developer/Xcode/DerivedData`.

## Use

1. Sign in with `gh auth login` if you have not already.
2. The strip appears near the top of the screen. Drag it if you want.
3. Hover to expand. Set a rival GitHub username and press **Race**.
4. Menu bar extra: goal, rival, hide on fullscreen, sound, launch at login.

The goal counts **your merges only**. A rival’s private PRs appear only if your token can see those repos.

## Demo

Open `demo/index.html` in a browser for a looping mock of the HUD (compact → hover expand). A 6s clip is at `demo/prbar-demo.mp4`.

To record the real app: QuickTime Player → File → New Screen Recording, then hover the strip.

## License

MIT
