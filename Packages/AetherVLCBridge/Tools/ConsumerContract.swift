import Foundation
import VLCKit
import AetherVLCBridge

@MainActor
final class TypedDelegate: NSObject, AetherVLCMediaPlayerDelegate {
    var snapshot = ""

    nonisolated func mediaPlayerStopping(
        reason: AetherVLCMediaStoppingReason,
        inputTime: Int64,
        hadError: Bool
    ) {
        let rawReason = reason.rawValue
        Task { @MainActor [weak self] in
            self?.snapshot = "\(rawReason):\(inputTime):\(hadError)"
        }
    }

    nonisolated func mediaPlayerClockPoint(time: Int64, position: Double, systemDate: Int64) {
        Task { @MainActor [weak self] in
            self?.snapshot = "\(time):\(position):\(systemDate)"
        }
    }

    nonisolated func mediaPlayerInputPositionChanged(time: Int64, position: Double) {
        Task { @MainActor [weak self] in
            self?.snapshot = "\(time):\(position)"
        }
    }

    nonisolated func mediaPlayerSeekingChanged(_ seeking: Bool, targetTime: Int64, sequence: UInt64) {
        Task { @MainActor [weak self] in
            self?.snapshot = "\(seeking):\(targetTime):\(sequence)"
        }
    }
}

@main
struct ContractConsumer {
    @MainActor static func main() {
        let player = AetherVLCMediaPlayer()
        let receiver = TypedDelegate()
        player.delegate = receiver
        // Referencing the optional protocol requirements is necessary: a method
        // with the wrong Swift spelling can otherwise silently miss conformance.
        player.delegate?.mediaPlayerStopping?(reason: .endOfStream, inputTime: 1, hadError: false)
        player.delegate?.mediaPlayerClockPoint?(time: 1, position: 0.5, systemDate: 1)
        player.delegate?.mediaPlayerInputPositionChanged?(time: 1, position: 0.5)
        player.delegate?.mediaPlayerSeekingChanged?(true, targetTime: 1, sequence: 1)
        _ = #selector(TypedDelegate.mediaPlayerStopping(reason:inputTime:hadError:))
        _ = #selector(TypedDelegate.mediaPlayerClockPoint(time:position:systemDate:))
        _ = #selector(TypedDelegate.mediaPlayerInputPositionChanged(time:position:))
        _ = #selector(TypedDelegate.mediaPlayerSeekingChanged(_:targetTime:sequence:))
        let _: UInt64 = player.seekCallbackSequence
        let _: Int64 = player.diagnosticCoreTimeMicroseconds
        print(player.state.rawValue)
    }
}
