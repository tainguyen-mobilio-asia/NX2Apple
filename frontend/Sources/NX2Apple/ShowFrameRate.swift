import Foundation

// The frame-rate counter for every Mac game: one Settings switch (Settings > General) that starts each game with DM_SHOW_FPS=1, the
// small badge at the top left of the game's window (front_mac.m). Off adds nothing, so a game's own "Frame-rate counter" row in its
// launch options decides. A game built before the Mac host had the badge ignores the variable until it is rebuilt.

enum ShowFrameRate {
    static let defaultsKey = "showFrameRateInGames"

    /// Off unless switched on in Settings.
    static var enabled: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }

    /// What Play adds to a game's start: the counter on, or nothing.
    static func environment(on: Bool) -> [String: String] { on ? ["DM_SHOW_FPS": "1"] : [:] }
}
