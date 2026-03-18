import Foundation
import WatchConnectivity
import Combine

class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var isReachable: Bool = false

    private var session: WCSession?

    /// Callback when a command is received from the phone.
    var onCommand: ((_ type: String, _ payload: [String: Any]) -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send to Phone

    /// Send a status update to the phone (best-effort, only if reachable).
    func sendStatusUpdate(state: String, recordingId: String, sampleCount: Int, elapsedMs: Double) {
        guard let session = session, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "statusUpdate",
            "recordingId": recordingId,
            "state": state,
            "sampleCount": sampleCount,
            "elapsedMs": elapsedMs
        ]
        session.sendMessage(message, replyHandler: nil) { error in
            print("[WatchSession] Send status error: \(error)")
        }
    }

    /// Send an error message to the phone.
    func sendError(recordingId: String, message: String) {
        guard let session = session, session.isReachable else { return }
        let msg: [String: Any] = [
            "type": "error",
            "recordingId": recordingId,
            "message": message
        ]
        session.sendMessage(msg, replyHandler: nil, errorHandler: nil)
    }

    /// Transfer recorded motion data as a file (for large payloads).
    func transferRecordingData(recordingId: String, data: Data, sampleCount: Int, durationMs: Double, strokeType: String, impactLabel: String) {
        guard let session = session else { return }

        // Write data to a temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(recordingId).bin")
        do {
            try data.write(to: tempURL)
        } catch {
            print("[WatchSession] Error writing temp file: \(error)")
            return
        }

        let metadata: [String: Any] = [
            "type": "recordingData",
            "recordingId": recordingId,
            "sampleCount": sampleCount,
            "durationMs": durationMs,
            "strokeType": strokeType,
            "impactLabel": impactLabel
        ]

        session.transferFile(tempURL, metadata: metadata)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if let error = error {
            print("[WatchSession] Activation error: \(error)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        DispatchQueue.main.async {
            self.onCommand?(type, message)
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["error": "missing type"])
            return
        }
        DispatchQueue.main.async {
            self.onCommand?(type, message)
        }
        replyHandler(["received": true])
    }
}
