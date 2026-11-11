import XCTest
import NXCore
@testable import NX2Apple

/// Settings' "Show the frame rate in games" (ShowFrameRate.swift): on starts every Mac game with DM_SHOW_FPS=1, off adds nothing.
@MainActor final class ShowFrameRateTests: XCTestCase {
    func testTheSwitchAddsTheCounterToAGamesStart() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShowFrameRateTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = GameLibrary(file: dir.appendingPathComponent("library.json"))
        let layout = ControlLayout(defaults: TestDefaults.make("ShowFrameRateTests"))
        let game = LibraryGame(titleID: "01001A9012345000", name: "X", appPath: dir.appendingPathComponent("X.app").path)
        func environment(_ on: Bool) -> [String: String] {
            GameStart.environment(for: game, library: library, controls: layout, repo: "", labels: { $0 }, showFPS: on)
        }
        XCTAssertEqual(environment(true)["DM_SHOW_FPS"], "1")
        XCTAssertNil(environment(false)["DM_SHOW_FPS"], "off: the game's own Frame-rate counter row decides")
        XCTAssertEqual(ShowFrameRate.environment(on: true), ["DM_SHOW_FPS": "1"])
        XCTAssertEqual(ShowFrameRate.environment(on: false), [:])
    }
}
