import Foundation
import WatchConnectivity

class PhoneSessionManager: NSObject, ObservableObject {

    static let shared = PhoneSessionManager()

    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false

    private var session: WCSession?

    /// Called when recording data is received from the watch.
    var onRecordingDataReceived: ((_ recordingId: String, _ data: Data, _ sampleCount: Int, _ durationMs: Double, _ strokeType: String, _ impactLabel: String) -> Void)?

    /// Called when a status update is received from the watch.
    var onStatusUpdate: ((_ payload: [String: Any]) -> Void)?

    /// Called when an error is received from the watch.
    var onError: ((_ payload: [String: Any]) -> Void)?

    private override init() {
        super.init()
    }

    func activate() {
        print("[PhoneSession] activate() called, isSupported=\(WCSession.isSupported())")
        guard WCSession.isSupported() else {
            print("[PhoneSession] WCSession not supported on this device")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[PhoneSession] WCSession.activate() called, delegate set to \(String(describing: session?.delegate))")
    }

    // MARK: - Send Commands to Watch

    func sendCommand(_ command: String, payload: [String: Any] = [:]) {
        guard let session = session, session.isReachable else {
            print("[PhoneSession] Watch not reachable")
            return
        }

        var message = payload
        message["type"] = command

        session.sendMessage(message, replyHandler: nil) { error in
            print("[PhoneSession] Send error: \(error)")
        }
    }

    func getWatchStatus() -> [String: Any] {
        guard let session = session else {
            return ["isReachable": false, "isPaired": false, "isWatchAppInstalled": false]
        }
        return [
            "isReachable": session.isReachable,
            "isPaired": session.isPaired,
            "isWatchAppInstalled": session.isWatchAppInstalled
        ]
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("[PhoneSession] Activation complete: state=\(activationState.rawValue) reachable=\(session.isReachable) paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        if let error = error {
            print("[PhoneSession] Activation error: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[PhoneSession] Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("[PhoneSession] Watch state changed: paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) reachable=\(session.isReachable)")
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    // Receive messages from watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "statusUpdate":
                self.onStatusUpdate?(message)
            case "error":
                self.onError?(message)
            default:
                break
            }
        }
    }

    // Receive file transfers from watch (recording data)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata,
              let type = metadata["type"] as? String,
              type == "recordingData",
              let recordingId = metadata["recordingId"] as? String,
              let sampleCount = metadata["sampleCount"] as? Int,
              let durationMs = metadata["durationMs"] as? Double else {
            return
        }

        let strokeType = metadata["strokeType"] as? String ?? "forehand"
        let impactLabel = metadata["impactLabel"] as? String ?? "impact"

        // Read the file data before it gets cleaned up
        guard let data = try? Data(contentsOf: file.fileURL) else {
            print("[PhoneSession] Failed to read transferred file")
            return
        }

        DispatchQueue.main.async {
            self.onRecordingDataReceived?(recordingId, data, sampleCount, durationMs, strokeType, impactLabel)
        }
    }
}
