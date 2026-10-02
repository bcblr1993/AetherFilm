#if os(iOS)
import Dispatch
import Foundation
import Synchronization
import XCTest
@testable import AetherFilm

@MainActor
final class AudioSessionCoordinatorTests: XCTestCase {
    func testAudioOperationsRunOffMainAndFinishInFIFOOrder() {
        XCTAssertTrue(Thread.isMainThread)
        let firstEntered = expectation(description: "First audio operation entered the background queue")
        let finished = expectation(description: "All queued audio operations finished")
        let driver = RecordingAudioSessionDriver(holdsFirstActivation: true) { event in
            if event == .activateBegan(1) { firstEntered.fulfill() }
        }
        let coordinator = AudioSessionCoordinator(driver: driver)
        let first = UUID()
        let second = UUID()
        let barrierOwner = UUID()
        defer { driver.releaseFirstActivation() }

        coordinator.activate(owner: first) { XCTAssertTrue($0) }
        wait(for: [firstEntered], timeout: 5)
        coordinator.deactivate(owner: first)
        coordinator.activate(owner: second) { XCTAssertTrue($0) }
        coordinator.deactivate(owner: second)
        coordinator.activate(owner: barrierOwner) { success in
            XCTAssertTrue(success)
            finished.fulfill()
        }
        XCTAssertEqual(driver.snapshot.events, [.activateBegan(1)],
                       "Later requests must not overtake an unfinished system operation.")
        driver.releaseFirstActivation()
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(driver.snapshot.events, [
            .activateBegan(1), .activateFinished(1), .deactivated,
            .activateBegan(2), .activateFinished(2), .deactivated,
            .activateBegan(3), .activateFinished(3)
        ])
        XCTAssertFalse(driver.snapshot.ranOnMainThread,
                       "Synchronous audio configuration and activation must leave MainActor.")
    }

    func testOnlyFinalHeldOwnerDeactivatesAndReleaseIsIdempotent() {
        let twoActive = expectation(description: "Both players acquired audio")
        twoActive.expectedFulfillmentCount = 2
        let sharedOwnerSurvived = expectation(description: "Other player retained its audio lease")
        let finished = expectation(description: "Repeated releases processed")
        let driver = RecordingAudioSessionDriver()
        let coordinator = AudioSessionCoordinator(driver: driver)
        let first = UUID()
        let second = UUID()
        let neverActivated = UUID()

        coordinator.activate(owner: first) { success in
            XCTAssertTrue(success)
            twoActive.fulfill()
        }
        coordinator.activate(owner: second) { success in
            XCTAssertTrue(success)
            twoActive.fulfill()
        }
        wait(for: [twoActive], timeout: 5)
        coordinator.deactivate(owner: neverActivated)
        coordinator.deactivate(owner: first)
        coordinator.deactivate(owner: first)
        coordinator.activate(owner: second) { success in
            XCTAssertTrue(success)
            sharedOwnerSurvived.fulfill()
        }
        wait(for: [sharedOwnerSurvived], timeout: 5)
        XCTAssertEqual(driver.snapshot.deactivations, 0,
                       "Unknown and released players must not deactivate another owner.")

        coordinator.deactivate(owner: second)
        coordinator.deactivate(owner: second)
        coordinator.deactivate(owner: neverActivated)
        coordinator.activate(owner: UUID()) { success in
            XCTAssertTrue(success)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(driver.snapshot.deactivations, 1,
                       "The final held lease is released exactly once.")
        XCTAssertEqual(driver.snapshot.activations, 4,
                       "A held owner must still reactivate after an interruption.")
    }

    func testFailedActivationDoesNotAcquireLeaseAndExistingOwnerCanReactivate() {
        let failed = expectation(description: "Activation failure reported")
        let active = expectation(description: "Successful owner acquired audio")
        let failedRetry = expectation(description: "Existing owner's failed reactivation reported")
        let recovered = expectation(description: "Existing owner reactivated")
        let finished = expectation(description: "Failed and repeated owners released")
        let driver = RecordingAudioSessionDriver(failingActivations: [1, 3])
        let coordinator = AudioSessionCoordinator(driver: driver)
        let failedOwner = UUID()
        let activeOwner = UUID()

        coordinator.activate(owner: failedOwner) { success in
            XCTAssertFalse(success)
            failed.fulfill()
        }
        coordinator.deactivate(owner: failedOwner)
        coordinator.activate(owner: activeOwner) { success in
            XCTAssertTrue(success)
            active.fulfill()
        }
        wait(for: [failed, active], timeout: 5)
        XCTAssertEqual(driver.snapshot.deactivations, 0,
                       "A failed activation must not acquire a lease that can deactivate audio.")

        coordinator.activate(owner: activeOwner) { success in
            XCTAssertFalse(success)
            failedRetry.fulfill()
        }
        coordinator.activate(owner: activeOwner) { success in
            XCTAssertTrue(success)
            recovered.fulfill()
        }
        wait(for: [failedRetry, recovered], timeout: 5)
        coordinator.deactivate(owner: failedOwner)
        coordinator.deactivate(owner: activeOwner)
        coordinator.deactivate(owner: activeOwner)
        coordinator.activate(owner: UUID()) { success in
            XCTAssertTrue(success)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(driver.snapshot.activations, 5)
        XCTAssertEqual(driver.snapshot.deactivations, 1)
        XCTAssertFalse(driver.snapshot.ranOnMainThread)
    }

    func testRejectedDeactivationDoesNotBlockLaterPlaybackOrRepeatTheRelease() {
        let active = expectation(description: "First owner acquired audio")
        let nextActive = expectation(description: "Playback continued after rejected deactivation")
        let finished = expectation(description: "Later release completed")
        let driver = RecordingAudioSessionDriver(failingDeactivations: [1])
        let coordinator = AudioSessionCoordinator(driver: driver)
        let first = UUID()
        let second = UUID()

        coordinator.activate(owner: first) { success in
            XCTAssertTrue(success)
            active.fulfill()
        }
        wait(for: [active], timeout: 5)
        coordinator.deactivate(owner: first)
        coordinator.deactivate(owner: first)
        coordinator.activate(owner: second) { success in
            XCTAssertTrue(success)
            nextActive.fulfill()
        }
        wait(for: [nextActive], timeout: 5)
        XCTAssertEqual(driver.snapshot.deactivations, 1)

        coordinator.deactivate(owner: first)
        coordinator.deactivate(owner: second)
        coordinator.deactivate(owner: second)
        coordinator.activate(owner: UUID()) { success in
            XCTAssertTrue(success)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(driver.snapshot.deactivations, 2)
        XCTAssertFalse(driver.snapshot.ranOnMainThread)
    }
}

private nonisolated final class RecordingAudioSessionDriver: AudioSessionDriver {
    enum Event: Equatable, Sendable {
        case activateBegan(Int)
        case activateFinished(Int)
        case deactivated
    }

    struct Snapshot: Sendable {
        var events: [Event] = []
        var activations = 0
        var deactivations = 0
        var ranOnMainThread = false
    }

    private enum Failure: Error { case activationRejected, deactivationRejected, holdTimedOut }
    private let state = Mutex(Snapshot())
    private let firstActivationGate = DispatchSemaphore(value: 0)
    private let holdsFirstActivation: Bool
    private let failingActivations: Set<Int>
    private let failingDeactivations: Set<Int>
    private let observe: @Sendable (Event) -> Void

    init(holdsFirstActivation: Bool = false, failingActivations: Set<Int> = [],
         failingDeactivations: Set<Int> = [],
         observe: @escaping @Sendable (Event) -> Void = { _ in }) {
        self.holdsFirstActivation = holdsFirstActivation
        self.failingActivations = failingActivations
        self.failingDeactivations = failingDeactivations
        self.observe = observe
    }

    var snapshot: Snapshot { state.withLock { $0 } }

    func activate() throws {
        let index = state.withLock { current in
            current.activations += 1
            return current.activations
        }
        record(.activateBegan(index))
        if holdsFirstActivation && index == 1,
           firstActivationGate.wait(timeout: .now() + 5) == .timedOut {
            throw Failure.holdTimedOut
        }
        record(.activateFinished(index))
        if failingActivations.contains(index) { throw Failure.activationRejected }
    }

    func deactivate() throws {
        let index = state.withLock { current in
            current.deactivations += 1
            return current.deactivations
        }
        record(.deactivated)
        if failingDeactivations.contains(index) { throw Failure.deactivationRejected }
    }

    func releaseFirstActivation() {
        firstActivationGate.signal()
    }

    private func record(_ event: Event) {
        state.withLock { current in
            current.events.append(event)
            current.ranOnMainThread = current.ranOnMainThread || Thread.isMainThread
        }
        observe(event)
    }
}
#endif
