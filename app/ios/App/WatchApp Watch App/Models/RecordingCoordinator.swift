import Foundation
import Combine

class RecordingCoordinator: ObservableObject {

    static let shared = RecordingCoordinator()

    let workoutManager = WorkoutManager()
    let motionRecorder = MotionRecorder()
    let sessionManager = WatchSessionManager.shared

    @Published var recordingId: String = ""
    @Published var strokeType: String = ""
    @Published var impactLabel: String = ""
    @Published var state: RecordingState = .idle
    @Published var elapsedMs: Double = 0

    private var timerCancellable: AnyCancellable?
    private var recordingStartDate: Date?
    private var cancellables = Set<AnyCancellable>()

    enum RecordingState: String {
        case idle
        case recording
        case paused
        case transferring
    }

    private init() {
        // Listen for commands from the phone
        sessionManager.onCommand = { [weak self] type, payload in
            self?.handleCommand(type, payload: payload)
        }

        // Forward nested ObservableObject changes to trigger SwiftUI updates
        motionRecorder.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        sessionManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - Commands

    private func handleCommand(_ type: String, payload: [String: Any]) {
        switch type {
        case "startRecording":
            let id = payload["recordingId"] as? String ?? UUID().uuidString
            let stroke = payload["strokeType"] as? String ?? "forehand"
            let impact = payload["impactLabel"] as? String ?? "impact"
            startRecording(id: id, strokeType: stroke, impactLabel: impact)

        case "pauseRecording":
            pauseRecording()

        case "resumeRecording":
            resumeRecording()

        case "stopRecording":
            stopRecording()

        default:
            print("[RecordingCoordinator] Unknown command: \(type)")
        }
    }

    // MARK: - Recording Lifecycle

    func startRecording(id: String? = nil, strokeType: String = "forehand", impactLabel: String = "impact") {
        guard state == .idle else { return }

        self.recordingId = id ?? UUID().uuidString
        self.strokeType = strokeType
        self.impactLabel = impactLabel
        self.elapsedMs = 0
        self.recordingStartDate = Date()

        // Start workout session to keep app alive
        workoutManager.start()

        // Start collecting motion data
        motionRecorder.startCollection()

        state = .recording
        startTimer()

        sendStatus()
    }

    func pauseRecording() {
        guard state == .recording else { return }
        motionRecorder.stopCollection()
        workoutManager.pause()
        state = .paused
        stopTimer()
        sendStatus()
    }

    func resumeRecording() {
        guard state == .paused else { return }
        workoutManager.resume()
        motionRecorder.resumeCollection()
        state = .recording
        startTimer()
        sendStatus()
    }

    func stopRecording() {
        guard state == .recording || state == .paused else { return }

        motionRecorder.stopCollection()
        workoutManager.end()
        stopTimer()

        state = .transferring
        sendStatus()

        // Transfer data to phone
        let samples = motionRecorder.samples
        let data = MotionSample.encode(samples)

        sessionManager.transferRecordingData(
            recordingId: recordingId,
            data: data,
            sampleCount: samples.count,
            durationMs: elapsedMs,
            strokeType: strokeType,
            impactLabel: impactLabel
        )

        // Reset for next recording
        motionRecorder.reset()
        state = .idle
        sendStatus()
    }

    // MARK: - Watch-initiated recording (no phone involved)

    func startFromWatch(strokeType: String, impactLabel: String) {
        startRecording(strokeType: strokeType, impactLabel: impactLabel)
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.recordingStartDate else { return }
                self.elapsedMs = Date().timeIntervalSince(start) * 1000.0
                self.sendStatus()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Status

    private func sendStatus() {
        sessionManager.sendStatusUpdate(
            state: state.rawValue,
            recordingId: recordingId,
            sampleCount: motionRecorder.sampleCount,
            elapsedMs: elapsedMs
        )
    }
}
