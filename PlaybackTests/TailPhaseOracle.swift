import Foundation

/// The fixture must not deadlock libVLC's file-length probe. Only the exact
/// final byte of the already size-validated file may bypass the held tail.
enum TailReadGate {
    static func isFinalByteProbe(_ range: Range<Int64>, fileBytes: Int64) -> Bool {
        fileBytes > 0 && range.lowerBound == fileBytes - 1 && range.upperBound == fileBytes
    }
}

/// Test-only decoding of immutable numeric observations. This type performs
/// no engine calls and never turns a cached estimate into a normal clock point.
struct TailPhaseTrace: Decodable {
    struct Record: Codable, Equatable {
        let sequence: Int
        let eventCode: Int
        let generation: Int
        var sourceSequence: Int? = nil
        var timeMicroseconds: Int64? = nil
        var systemDateMicroseconds: Int64? = nil
        var targetSeconds: Double? = nil
        var displayedVideoFrames: UInt64? = nil
        var playedAudioBuffers: UInt64? = nil
    }

    let evictedEvents: Int
    let totalEvents: Int
    let records: [Record]

    func latestSeekMarker() -> Record? {
        records.last { $0.eventCode == 17 }
    }

    /// Pair the delivery with its actual normal delegate callback, not an
    /// optimistic seek request or a newly assigned main-thread sequence.
    func pairedCallback(for delivery: Record, callbackCode: Int) -> Record? {
        guard let source = delivery.sourceSequence, source < delivery.sequence,
              let callback = records.first(where: { $0.sequence == source }),
              callback.eventCode == callbackCode,
              callback.generation == delivery.generation,
              callback.timeMicroseconds == delivery.timeMicroseconds else { return nil }
        if callbackCode == 30 {
            guard callback.systemDateMicroseconds == delivery.systemDateMicroseconds else { return nil }
        }
        return callback
    }
}

struct TailPhaseObservation: Codable {
    var engineIdentityMatches = true
    var currentGeneration: Int
    var rawClock: Double?
    var rawClockIsRunning: Bool
    var displayed: UInt64
    var played: UInt64
    var cache: Double?
    var isPlaying: Bool
    var activeTailPending: Bool
    var ended: Int
    var validatorCalls: Int
    var hasPlayerError: Bool
    var hasSourceFailure: Bool
    var stoppingReason: Int?
}

struct TailPhaseOracle {
    struct Context: Codable {
        let markerSequence: Int
        let generation: Int
        let target: Double
        let duration: Double
        let displayedBeforeSeek: UInt64
        let playedBeforeSeek: UInt64
    }

    let context: Context
    private(set) var boundary: TailPhaseTrace.Record?
    private(set) var runningPoint: TailPhaseTrace.Record?

    mutating func observe(_ trace: TailPhaseTrace, _ sample: TailPhaseObservation) -> Bool {
        guard trace.evictedEvents == 0, sample.engineIdentityMatches,
              sample.currentGeneration == context.generation,
              context.target.isFinite, context.duration.isFinite,
              context.duration > context.target,
              trace.records.contains(where: {
                  $0.eventCode == 17 && $0.sequence == context.markerSequence
                      && $0.generation == context.generation
              }) else { return false }

        let freshNormals = trace.records.filter { record in
            guard record.eventCode == 31, record.generation == context.generation,
                  let callback = trace.pairedCallback(for: record, callbackCode: 30),
                  callback.sequence > context.markerSequence,
                  let time = record.timeMicroseconds,
                  Double(time) / 1_000_000 >= context.target - 0.05,
                  Double(time) / 1_000_000 < context.duration,
                  record.displayedVideoFrames != nil, record.playedAudioBuffers != nil else { return false }
            return true
        }.sorted { ($0.sourceSequence ?? 0) < ($1.sourceSequence ?? 0) }

        // The first target-region normal update may have INT64_MAX date. It is
        // a real on_update boundary but is insufficient as the running point.
        if boundary == nil { boundary = freshNormals.first }
        guard let boundary, let boundaryTime = boundary.timeMicroseconds,
              let boundarySource = boundary.sourceSequence else { return false }

        runningPoint = freshNormals.last { record in
            guard let source = record.sourceSequence, source > boundarySource,
                  let time = record.timeMicroseconds, time > boundaryTime,
                  let date = record.systemDateMicroseconds, date > 0, date != Int64.max else { return false }
            return true
        }
        guard let runningPoint, let runningTime = runningPoint.timeMicroseconds,
              let runningSource = runningPoint.sourceSequence,
              let raw = sample.rawClock, raw.isFinite,
              abs(raw - Double(runningTime) / 1_000_000) < 0.000002,
              sample.rawClockIsRunning else { return false }

        // Input and output queues need not report in the same order as normal
        // clock points. Use the actual seek as their common boundary, while an
        // input arriving after this running point cannot prove that point.
        let freshInput = trace.records.contains { record in
            guard record.eventCode == 41, record.generation == context.generation,
                  let callback = trace.pairedCallback(for: record, callbackCode: 40),
                  callback.sequence > context.markerSequence,
                  callback.sequence <= runningSource,
                  let time = record.timeMicroseconds else { return false }
            return Double(time) / 1_000_000 >= context.target - 0.05
                && Double(time) / 1_000_000 < context.duration
        }

        // Subtraction avoids overflowing test counters supplied by adversarial
        // sequence inputs. All original pre-seek output conditions remain;
        // an asynchronous display queue may have enqueued those outputs before
        // the first target-region normal point. Statistics do not prove its PTS.
        func moreThanFive(_ current: UInt64, after baseline: UInt64) -> Bool {
            current > baseline && current - baseline > 5
        }
        guard freshInput, sample.isPlaying,
              sample.displayed > 5, sample.played > 5,
              moreThanFive(sample.displayed, after: context.displayedBeforeSeek),
              moreThanFive(sample.played, after: context.playedBeforeSeek),
              let cache = sample.cache, cache.isFinite, cache > 11.85, cache < 12.05,
              sample.activeTailPending, sample.ended == 0, sample.validatorCalls == 0,
              !sample.hasPlayerError, !sample.hasSourceFailure,
              sample.stoppingReason == nil else { return false }
        return true
    }
}

struct TailHTTPTrace: Decodable {
    struct Event: Codable {
        let sequence: UInt64
        let requestID: UInt64
        let phase: String
        let offset: Int64
        let count: Int64
    }
    let omittedEvents: UInt64
    let events: [Event]

    func activeTailRequests(holdAt: Int64) -> Set<UInt64> {
        guard omittedEvents == 0 else { return [] }
        let terminal = Set(["readerComplete", "readerFailed", "readerCancelled",
                            "requestFinished", "connectionFailed", "connectionCancelled",
                            "cancelRequested", "consumerTransportError", "consumerWriteEOF"])
        let submitted = events.filter { $0.phase == "readerSubmit" && $0.offset >= holdAt && $0.count > 0 }
        return Set(submitted.compactMap { request in
            let ended = events.contains { event in
                event.requestID == request.requestID && event.sequence > request.sequence
                    && terminal.contains(event.phase)
                    && (event.phase != "readerComplete" || event.offset == request.offset)
            }
            return ended ? nil : request.requestID
        })
    }
}
