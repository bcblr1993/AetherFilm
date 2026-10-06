import XCTest
@testable import AetherFilm

/// Adversarial sequences exercise the same pure predicate used by actual
/// SMB/decoder tests. Synthetic inputs are never counted as playback evidence.
final class TailPhaseOracleTests: XCTestCase {
    func testTypedLifecycleSnapshotMatchesRecordedJSONIncludingEviction() throws {
        let trace = PlaybackLifecycleTrace(origin: .now, capacity: 128)
        for index in 0..<160 {
            trace.record(.callbackClock, generation: 3, time: Int64(index) * 100_000,
                         systemDate: Int64(index) + 1, displayed: UInt64(index), played: UInt64(index + 4))
        }
        let typed = TailPhaseTrace.from(trace.snapshot())
        let json = try JSONDecoder().decode(TailPhaseTrace.self, from: XCTUnwrap(trace.snapshotData()))
        XCTAssertEqual(typed.evictedEvents, 32)
        XCTAssertEqual(typed.evictedEvents, json.evictedEvents)
        XCTAssertEqual(typed.totalEvents, json.totalEvents)
        XCTAssertEqual(typed.records, json.records)
    }
    func testTailReadGateOnlyExemptsValidatedFinalByteProbe() {
        let fileBytes: Int64 = 796257
        XCTAssertTrue(TailReadGate.isFinalByteProbe(796256..<796257, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(796255..<796257, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(795866..<796257, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(796256..<796256, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(796255..<796256, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(796256..<796258, fileBytes: fileBytes))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(0..<1, fileBytes: 0))
        XCTAssertFalse(TailReadGate.isFinalByteProbe(796256..<796257, fileBytes: fileBytes + 1))
    }

    private func context() -> TailPhaseOracle.Context {
        .init(markerSequence: 100, generation: 3, target: 10, duration: 12,
              displayedBeforeSeek: 14, playedBeforeSeek: 108)
    }

    private func trace() -> TailPhaseTrace {
        .init(evictedEvents: 0, totalEvents: 106, records: [
            .init(sequence: 100, eventCode: 17, generation: 3, targetSeconds: 10),
            .init(sequence: 101, eventCode: 30, generation: 3, timeMicroseconds: 10_001_876,
                  systemDateMicroseconds: Int64.max),
            .init(sequence: 102, eventCode: 31, generation: 3, sourceSequence: 101,
                  timeMicroseconds: 10_001_876, systemDateMicroseconds: Int64.max,
                  displayedVideoFrames: 16, playedAudioBuffers: 112),
            .init(sequence: 103, eventCode: 40, generation: 3, timeMicroseconds: 10_384_105),
            .init(sequence: 104, eventCode: 41, generation: 3, sourceSequence: 103,
                  timeMicroseconds: 10_384_105),
            .init(sequence: 105, eventCode: 30, generation: 3, timeMicroseconds: 11_006_417,
                  systemDateMicroseconds: 54_755_444_957),
            .init(sequence: 106, eventCode: 31, generation: 3, sourceSequence: 105,
                  timeMicroseconds: 11_006_417, systemDateMicroseconds: 54_755_444_957,
                  displayedVideoFrames: 24, playedAudioBuffers: 190)
        ])
    }

    private func sample() -> TailPhaseObservation {
        .init(currentGeneration: 3, rawClock: 11.006417, rawClockIsRunning: true,
              displayed: 30, played: 194, cache: 12, isPlaying: true,
              activeTailPending: true, ended: 0, validatorCalls: 0,
              hasPlayerError: false, hasSourceFailure: false, stoppingReason: nil)
    }

    func testAcceptsCompoundPhaseAndPreservesFirstNormalBoundary() {
        var oracle = TailPhaseOracle(context: context())
        XCTAssertTrue(oracle.observe(trace(), sample()))
        XCTAssertEqual(oracle.boundary?.sourceSequence, 101)
        XCTAssertEqual(oracle.boundary?.systemDateMicroseconds, Int64.max)
        XCTAssertEqual(oracle.runningPoint?.sourceSequence, 105)
        XCTAssertTrue(oracle.observe(trace(), sample()))
        XCTAssertEqual(oracle.boundary?.sourceSequence, 101, "Repeated polls cannot move the baseline to the latest point.")
    }

    func testRejectsOldCallbackWithNewDeliverySequence() {
        let original = trace()
        let queued: [TailPhaseTrace.Record] = [
            .init(sequence: 90, eventCode: 30, generation: 3, timeMicroseconds: 10_001_876,
                  systemDateMicroseconds: Int64.max),
            .init(sequence: 91, eventCode: 30, generation: 3, timeMicroseconds: 11_006_417,
                  systemDateMicroseconds: 54_755_444_957),
            original.records[0],
            .init(sequence: 102, eventCode: 31, generation: 3, sourceSequence: 90,
                  timeMicroseconds: 10_001_876, systemDateMicroseconds: Int64.max,
                  displayedVideoFrames: 16, playedAudioBuffers: 112),
            original.records[3], original.records[4],
            .init(sequence: 106, eventCode: 31, generation: 3, sourceSequence: 91,
                  timeMicroseconds: 11_006_417, systemDateMicroseconds: 54_755_444_957,
                  displayedVideoFrames: 24, playedAudioBuffers: 190)
        ]
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(.init(evictedEvents: 0, totalEvents: 106, records: queued), sample()))
        XCTAssertNil(oracle.boundary)
    }

    func testRejectsCachedLatePositionWithoutNormalCallback() {
        var oracle = TailPhaseOracle(context: context())
        var cached = sample()
        cached.rawClock = nil
        cached.rawClockIsRunning = false
        cached.cache = 11.99
        let requests = TailPhaseTrace(evictedEvents: 0, totalEvents: 100, records: [trace().records[0]])
        XCTAssertFalse(oracle.observe(requests, cached))
        XCTAssertNil(oracle.boundary)
    }

    func testRejectsSeekRequestDisguisedAsNormalDelivery() {
        let request = TailPhaseTrace.Record(sequence: 101, eventCode: 17, generation: 3,
                                           timeMicroseconds: 10_001_876, systemDateMicroseconds: Int64.max,
                                           targetSeconds: 10)
        var records = trace().records
        records[1] = request
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(.init(evictedEvents: 0, totalEvents: 106, records: records), sample()))
        XCTAssertNotEqual(oracle.boundary?.sourceSequence, 101)
    }

    func testRejectsOldSessionAndEngineReplacement() {
        var changedGeneration = sample()
        changedGeneration.currentGeneration = 4
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(trace(), changedGeneration))
        var changedEngine = sample()
        changedEngine.engineIdentityMatches = false
        XCTAssertFalse(oracle.observe(trace(), changedEngine))
        XCTAssertNil(oracle.boundary)
    }

    func testAcceptsOutputEnqueuedBeforeFirstTargetNormalPoint() {
        // Input and output can precede a normal timer point with an asynchronous
        // display queue. The common freshness boundary remains the actual seek.
        let original = trace()
        let reordered = TailPhaseTrace(evictedEvents: 0, totalEvents: 106, records: [
            original.records[0],
            .init(sequence: 101, eventCode: 40, generation: 3, timeMicroseconds: 10_384_105),
            .init(sequence: 102, eventCode: 41, generation: 3, sourceSequence: 101,
                  timeMicroseconds: 10_384_105),
            .init(sequence: 103, eventCode: 30, generation: 3, timeMicroseconds: 10_984_075,
                  systemDateMicroseconds: Int64.max),
            .init(sequence: 104, eventCode: 31, generation: 3, sourceSequence: 103,
                  timeMicroseconds: 10_984_075, systemDateMicroseconds: Int64.max,
                  displayedVideoFrames: 33, playedAudioBuffers: 168),
            .init(sequence: 105, eventCode: 30, generation: 3, timeMicroseconds: 11_984_097,
                  systemDateMicroseconds: 54_755_444_957),
            .init(sequence: 106, eventCode: 31, generation: 3, sourceSequence: 105,
                  timeMicroseconds: 11_984_097, systemDateMicroseconds: 54_755_444_957,
                  displayedVideoFrames: 33, playedAudioBuffers: 168)
        ])
        var enqueued = sample()
        enqueued.rawClock = 11.984097
        enqueued.displayed = 33
        enqueued.played = 168
        var oracle = TailPhaseOracle(context: context())
        XCTAssertTrue(oracle.observe(reordered, enqueued))
        XCTAssertEqual(oracle.boundary?.sourceSequence, 103)
        XCTAssertEqual(oracle.runningPoint?.sourceSequence, 105)
    }

    func testRejectsPreSeekOnlyOutput() {
        var oldOutput = sample()
        oldOutput.displayed = context().displayedBeforeSeek
        oldOutput.played = context().playedBeforeSeek
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(trace(), oldOutput))
        oldOutput.displayed += 5
        oldOutput.played += 5
        XCTAssertFalse(oracle.observe(trace(), oldOutput), "Both original output deltas must exceed five.")
        oldOutput.displayed += 1
        XCTAssertFalse(oracle.observe(trace(), oldOutput), "New video cannot replace missing new audio.")
        XCTAssertNotNil(oracle.boundary)
        XCTAssertNotNil(oracle.runningPoint)
    }

    func testRejectsPausedClockMissingInputOrEarlyCompletion() {
        var paused = sample()
        paused.rawClockIsRunning = false
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(trace(), paused))
        let noInput = trace().records.filter { $0.eventCode != 40 && $0.eventCode != 41 }
        XCTAssertFalse(oracle.observe(.init(evictedEvents: 0, totalEvents: 106, records: noInput), sample()))
        let futureInput = noInput + [
            .init(sequence: 107, eventCode: 40, generation: 3, timeMicroseconds: 10_384_105),
            .init(sequence: 108, eventCode: 41, generation: 3, sourceSequence: 107,
                  timeMicroseconds: 10_384_105)
        ]
        XCTAssertFalse(oracle.observe(.init(evictedEvents: 0, totalEvents: 108, records: futureInput), sample()),
                       "An input callback after the selected running point cannot prove that earlier point.")
        var premature = sample()
        premature.validatorCalls = 1
        XCTAssertFalse(oracle.observe(trace(), premature))
        premature = sample()
        premature.ended = 1
        XCTAssertFalse(oracle.observe(trace(), premature))
        premature = sample()
        premature.hasSourceFailure = true
        XCTAssertFalse(oracle.observe(trace(), premature))
    }

    func testRejectsCancelledHistoricalTailAndEvictedTrace() {
        let http = TailHTTPTrace(omittedEvents: 0, events: [
            .init(sequence: 1, requestID: 7, phase: "readerSubmit", offset: 795866, count: 391),
            .init(sequence: 2, requestID: 7, phase: "cancelRequested", offset: 0, count: 0),
            .init(sequence: 3, requestID: 7, phase: "readerCancelled", offset: 795866, count: 391)
        ])
        XCTAssertTrue(http.activeTailRequests(holdAt: 795866).isEmpty)
        var historical = sample()
        historical.activeTailPending = false
        var oracle = TailPhaseOracle(context: context())
        XCTAssertFalse(oracle.observe(trace(), historical))
        let evicted = TailPhaseTrace(evictedEvents: 1, totalEvents: 107, records: trace().records)
        XCTAssertFalse(oracle.observe(evicted, sample()))
    }
}
