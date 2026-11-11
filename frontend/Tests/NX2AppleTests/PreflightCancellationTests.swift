import XCTest
@testable import NX2Apple
@testable import NXCore
@testable import NXModel

@MainActor final class PreflightCancellationTests: IsolatedDefaultsTestCase {
    private final class FakeRunningApp: RunningPreflightApp {
        var terminated = false
        var pollChecks = 0
        var terminateCalls = 0
        var forceTerminateCalls = 0
        var terminateSucceeds = false

        var isTerminated: Bool {
            pollChecks += 1
            return terminated
        }

        func terminate() -> Bool {
            terminateCalls += 1
            if terminateSucceeds { terminated = true }
            return terminateSucceeds
        }

        func forceTerminate() -> Bool {
            forceTerminateCalls += 1
            terminated = true
            return true
        }
    }

    func testTaskCancellationInvalidatesTimerAndTerminatesPreflightProcess() async {
        let fakeApp = FakeRunningApp()
        let url = URL(fileURLWithPath: "/tmp/FakeGame.app")
        let task = Task { @MainActor in
            await LauncherStores.preflight(url, timeout: 600, pollInterval: 0.01) { _, completion in
                completion(fakeApp, nil)
            }
        }
        // Let the repeating timer tick at least once before cancelling.
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertGreaterThanOrEqual(fakeApp.pollChecks, 2)

        task.cancel()
        let result = await task.value
        guard case MacPreflight.Failure.stopped? = result else {
            return XCTFail("expected MacPreflight.Failure.stopped, got \(String(describing: result))")
        }
        XCTAssertEqual(fakeApp.terminateCalls, 1)
        XCTAssertEqual(fakeApp.forceTerminateCalls, 1)

        let checksAtCancel = fakeApp.pollChecks
        try? await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(fakeApp.pollChecks, checksAtCancel, "the 0.5s timer must be invalidated immediately on cancellation")
    }

    func testTimeoutInvalidatesTimerAndTerminatesOrphanPreflightProcess() async {
        let fakeApp = FakeRunningApp()
        let url = URL(fileURLWithPath: "/tmp/HungGame.app")
        let result = await LauncherStores.preflight(url, timeout: 0.04, pollInterval: 0.01) { _, completion in
            completion(fakeApp, nil)
        }
        guard case MacPreflight.Failure.timedOut? = result else {
            return XCTFail("expected MacPreflight.Failure.timedOut, got \(String(describing: result))")
        }
        XCTAssertEqual(fakeApp.terminateCalls, 1)
        XCTAssertEqual(fakeApp.forceTerminateCalls, 1)

        let checksAtTimeout = fakeApp.pollChecks
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(fakeApp.pollChecks, checksAtTimeout, "the poll timer must not keep firing after timeout")
    }

    func testBuildStoreStopCancelsWiredPreflightAndTerminatesLateLaunch() async {
        let stores = LauncherStores(defaults: testDefaults)
        let fakeApp = FakeRunningApp()
        var lateCompletion: (@MainActor (RunningPreflightApp?, Error?) -> Void)?
        stores.build.preflightSupported = { _ in true }
        stores.build.runPreflight = { app, timeout in
            await LauncherStores.preflight(app, timeout: timeout, pollInterval: 0.01) { _, completion in
                lateCompletion = completion
            }
        }
        stores.build.running = true
        stores.build.stages = [Stage(id: 1, name: "Pack", state: .done)]

        let runTask = Task { @MainActor in
            await stores.build.preflight(URL(fileURLWithPath: "/tmp/SlowScan.app"))
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        stores.build.stop()
        await runTask.value

        XCTAssertEqual(stores.build.stages.last?.state, .failed)
        XCTAssertEqual(stores.build.stages.last?.detail, stores.build.t("msg.stopped"))

        // When LaunchServices finishes scanning later and delivers the running process, it must be terminated at once.
        lateCompletion?(fakeApp, nil)
        XCTAssertEqual(fakeApp.terminateCalls, 1)
        XCTAssertEqual(fakeApp.forceTerminateCalls, 1)
        let checks = fakeApp.pollChecks
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(fakeApp.pollChecks, checks, "no poll timer should start for an already-cancelled preflight")
    }
}
