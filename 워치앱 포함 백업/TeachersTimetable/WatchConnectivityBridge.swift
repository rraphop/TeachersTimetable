import Foundation
import WatchConnectivity

enum WatchSyncResult {
    case sent
    case queued
    case activating
    case watchNotPaired
    case watchAppNotInstalled
    case unsupported
    case failed
}

@MainActor
final class WatchConnectivityBridge: NSObject {
    static let shared = WatchConnectivityBridge()

    private static let hasCommunicatedWithWatchKey = "TimetableTeacher.hasCommunicatedWithWatch"

    private var snapshotProvider: (() -> TimetableSnapshot)?
    private var pendingSnapshot: TimetableSnapshot?

    private var session: WCSession? {
        guard WCSession.isSupported() else { return nil }
        return .default
    }

    private override init() {
        super.init()
    }

    func configure(snapshotProvider: @escaping () -> TimetableSnapshot) {
        self.snapshotProvider = snapshotProvider

        guard let session else { return }
        session.delegate = self

        switch session.activationState {
        case .activated:
            send(snapshot: snapshotProvider())
        case .inactive, .notActivated:
            pendingSnapshot = snapshotProvider()
            session.activate()
        @unknown default:
            session.activate()
        }
    }

    func send(snapshot: TimetableSnapshot, completion: ((WatchSyncResult) -> Void)? = nil) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            completion?(.failed)
            return
        }

        guard let session else {
            completion?(.unsupported)
            return
        }

        pendingSnapshot = snapshot

        guard session.activationState == .activated else {
            session.activate()
            completion?(.activating)
            return
        }

        let payload: [String: Any] = ["snapshot": data]

        let contextWasUpdated: Bool
        do {
            try session.updateApplicationContext(payload)
            contextWasUpdated = true
        } catch {
            contextWasUpdated = false
        }

        guard session.isPaired else {
            completion?(.watchNotPaired)
            return
        }

        if session.isReachable {
            session.sendMessage(payload) { [weak self] _ in
                Task { @MainActor in
                    self?.markWatchCommunicationObserved()
                    if self?.pendingSnapshot == snapshot {
                        self?.pendingSnapshot = nil
                    }
                    completion?(.sent)
                }
            } errorHandler: { _ in
                Task { @MainActor in
                    completion?(self.queueTransfer(payload: payload, on: session, contextWasUpdated: contextWasUpdated))
                }
            }
        } else {
            completion?(queueTransfer(payload: payload, on: session, contextWasUpdated: contextWasUpdated))
        }
    }

    private func encodedCurrentSnapshot() -> Data? {
        guard let snapshot = snapshotProvider?() else { return nil }
        return try? JSONEncoder().encode(snapshot)
    }

    private var hasCommunicatedWithWatch: Bool {
        UserDefaults.standard.bool(forKey: Self.hasCommunicatedWithWatchKey)
    }

    private func markWatchCommunicationObserved() {
        UserDefaults.standard.set(true, forKey: Self.hasCommunicatedWithWatchKey)
    }

    private func queueTransfer(
        payload: [String: Any],
        on session: WCSession,
        contextWasUpdated: Bool
    ) -> WatchSyncResult {
        if session.isWatchAppInstalled || hasCommunicatedWithWatch || contextWasUpdated {
            _ = session.transferUserInfo(payload)
            pendingSnapshot = nil
            return .queued
        }

        return .watchAppNotInstalled
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            guard let snapshot = self.pendingSnapshot ?? self.snapshotProvider?() else { return }
            self.send(snapshot: snapshot)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            guard let snapshot = self.pendingSnapshot ?? self.snapshotProvider?() else { return }
            self.send(snapshot: snapshot)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let requestsSnapshot = message["requestSnapshot"] as? Bool == true
        nonisolated(unsafe) let replyHandler = replyHandler

        Task { @MainActor in
            self.markWatchCommunicationObserved()
            guard requestsSnapshot, let data = self.encodedCurrentSnapshot() else {
                replyHandler([:])
                return
            }

            replyHandler(["snapshot": data])
        }
    }
}
