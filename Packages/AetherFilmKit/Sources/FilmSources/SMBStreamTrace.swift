#if DEBUG
import Foundation

enum SMBStreamTracePhase: String, Encodable, Sendable {
    case listenerConnection, requestAccepted, requestRejected, rangeReceived, headersSent
    case readerSubmit, readerComplete, readerFailed, readerCancelled, chunkSendComplete
    case sendCallbackComplete, sendCallbackFailed, consumerTransportError, consumerWriteEOF
    case connectionFailed, connectionCancelled, cancelRequested, requestFinished
    case sourceReadFailure, stop, stopComplete, serverDeinit
}

/// This scope follows the request task without adding a diagnostic actor hop.
enum SMBStreamTraceScope {
    @TaskLocal static var request: SMBStreamTraceRequest?
}

struct SMBStreamTraceRequest: Sendable {
    let recorder: SMBStreamTraceRecorder
    let requestID: UInt64

    func record(_ phase: SMBStreamTracePhase, offset: Int64 = 0, count: Int64 = 0, httpStatus: Int = 0) {
        recorder.record(phase, requestID: requestID, offset: offset, count: count, httpStatus: httpStatus)
    }
}

/// Only bounded primitive values are retained. No endpoint, header, file or error text enters this recorder.
final class SMBStreamTraceRecorder: @unchecked Sendable {
    private struct Event: Encodable {
        let sequence: UInt64
        let requestID: UInt64
        let elapsedSeconds: Double
        let phase: SMBStreamTracePhase
        let offset: Int64
        let count: Int64
        let httpStatus: Int
    }

    private struct Snapshot: Encodable {
        let schemaVersion = 1
        let capacity: Int
        let omittedEvents: UInt64
        let events: [Event]
    }

    private let lock = NSLock()
    private var origin: ContinuousClock.Instant?
    private var capacity = 0
    private var nextRequestID: UInt64 = 0
    private var nextSequence: UInt64 = 0
    private var events: [Event] = []
    private var writeIndex = 0
    private var omittedEvents: UInt64 = 0

    func enable(origin: ContinuousClock.Instant, capacity: Int) {
        lock.withLock {
            guard self.origin == nil else { return }
            self.origin = origin
            self.capacity = max(1, min(capacity, 4_096))
        }
    }

    func beginRequest() -> SMBStreamTraceRequest? {
        let id = lock.withLock { () -> UInt64? in
            guard origin != nil else { return nil }
            nextRequestID += 1
            return nextRequestID
        }
        guard let id else { return nil }
        let request = SMBStreamTraceRequest(recorder: self, requestID: id)
        request.record(.listenerConnection)
        return request
    }

    func record(_ phase: SMBStreamTracePhase, requestID: UInt64 = 0,
                offset: Int64 = 0, count: Int64 = 0, httpStatus: Int = 0) {
        let instant = ContinuousClock.now
        lock.withLock {
            guard let origin else { return }
            let elapsed = origin.duration(to: instant).components
            nextSequence += 1
            let event = Event(sequence: nextSequence, requestID: requestID,
                              elapsedSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                              phase: phase, offset: offset, count: count, httpStatus: httpStatus)
            if events.count < capacity { events.append(event) }
            else {
                events[writeIndex] = event
                writeIndex = (writeIndex + 1) % capacity
                omittedEvents += 1
            }
        }
    }

    func data() -> Data? {
        let snapshot = lock.withLock { () -> Snapshot? in
            guard origin != nil else { return nil }
            let ordered = omittedEvents == 0 ? events : Array(events[writeIndex...]) + Array(events[..<writeIndex])
            return Snapshot(capacity: capacity, omittedEvents: omittedEvents, events: ordered)
        }
        guard let snapshot else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(snapshot)
    }
}
#endif
