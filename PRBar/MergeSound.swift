import AppKit
import CoreGraphics

enum FullscreenDetect {
    static func isActive() -> Bool {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        let sizes = NSScreen.screens.map(\.frame.size)
        let skip: Set<String> = [
            "Window Server", "Dock", "Control Center", "Notification Centre",
            "Notification Center", "SystemUIServer", "Wallpaper", "PRBar"
        ]

        for item in list {
            guard
                let owner = item[kCGWindowOwnerName as String] as? String,
                !skip.contains(owner),
                let layer = item[kCGWindowLayer as String] as? Int,
                layer == 0,
                let bounds = item[kCGWindowBounds as String] as? [String: CGFloat],
                let width = bounds["Width"],
                let height = bounds["Height"]
            else { continue }

            if sizes.contains(where: { abs($0.width - width) < 4 && abs($0.height - height) < 4 }) {
                return true
            }
        }
        return false
    }
}

enum MergeSound {
    static func playTick() {
        play(named: "Tink", volume: 0.12)
    }

    static func playGoal() {
        play(named: "Glass", volume: 0.18)
    }

    private static func play(named name: String, volume: Float) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}
