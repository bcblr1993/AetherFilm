#if os(iOS)
import AVFAudio
import Dispatch
import Foundation
import Synchronization

nonisolated protocol AudioSessionDriver: Sendable {
    func activate() throws
    func deactivate() throws
}

/// Serializes the shared audio session without blocking the main actor.
/// Owners are recorded only after activation succeeds; one player's cleanup
/// must not deactivate audio still leased by another player.
nonisolated final class AudioSessionCoordinator: Sendable {
    static let shared = AudioSessionCoordinator(driver: SystemAudioSessionDriver())

    private let queue = DispatchQueue(label: "com.aethernative.film.audio-session", qos: .userInitiated)
    private let driver: any AudioSessionDriver
    private let owners = Mutex<Set<UUID>>([])

    init(driver: any AudioSessionDriver) {
        self.driver = driver
    }

    /// Completion runs on the audio queue. Callers must validate their current
    /// playback request on MainActor before starting or updating a player.
    func activate(owner: UUID, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            dispatchPrecondition(condition: .notOnQueue(.main))
            do {
                // Repeat even for an existing owner: an interruption may have
                // deactivated the system session since the previous request.
                try driver.activate()
                owners.withLock { _ = $0.insert(owner) }
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func deactivate(owner: UUID) {
        queue.async { [self] in
            dispatchPrecondition(condition: .notOnQueue(.main))
            let releasesLastOwner = owners.withLock { heldOwners in
                guard heldOwners.remove(owner) != nil else { return false }
                return heldOwners.isEmpty
            }
            guard releasesLastOwner else { return }
            // Releasing a lease is idempotent even if the system rejects the
            // deactivation. Never expose audio-session errors in logs.
            try? driver.deactivate()
        }
    }
}

private nonisolated struct SystemAudioSessionDriver: AudioSessionDriver {
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
    }

    func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
