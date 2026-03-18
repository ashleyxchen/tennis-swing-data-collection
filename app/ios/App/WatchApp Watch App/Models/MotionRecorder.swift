import Foundation
import CoreMotion
import Combine

class MotionRecorder: ObservableObject {

    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.ashleyc.watchmotiondata.motion"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()

    private var startTime: TimeInterval?
    private var samplesLock = NSLock()
    private var _samples: [MotionSample] = []

    @Published var sampleCount: Int = 0
    @Published var isRecording: Bool = false

    /// All collected samples (thread-safe read).
    var samples: [MotionSample] {
        samplesLock.lock()
        defer { samplesLock.unlock() }
        return _samples
    }

    func startCollection() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionRecorder] Device motion not available")
            return
        }

        samplesLock.lock()
        _samples = []
        samplesLock.unlock()

        startTime = nil
        isRecording = true

        motionManager.deviceMotionUpdateInterval = 0.01 // 100 Hz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            if self.startTime == nil {
                self.startTime = motion.timestamp
            }

            let timestampMs = (motion.timestamp - self.startTime!) * 1000.0

            let sample = MotionSample(
                timestamp: timestampMs,
                accelX: motion.userAcceleration.x,
                accelY: motion.userAcceleration.y,
                accelZ: motion.userAcceleration.z,
                gyroX: motion.rotationRate.x,
                gyroY: motion.rotationRate.y,
                gyroZ: motion.rotationRate.z,
                roll: motion.attitude.roll,
                pitch: motion.attitude.pitch,
                yaw: motion.attitude.yaw
            )

            self.samplesLock.lock()
            self._samples.append(sample)
            let count = self._samples.count
            self.samplesLock.unlock()

            if count % 100 == 0 {
                DispatchQueue.main.async {
                    self.sampleCount = count
                }
            }
        }
    }

    func resumeCollection() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionRecorder] Device motion not available")
            return
        }

        isRecording = true

        motionManager.deviceMotionUpdateInterval = 0.01 // 100 Hz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            if self.startTime == nil {
                self.startTime = motion.timestamp
            }

            let timestampMs = (motion.timestamp - self.startTime!) * 1000.0

            let sample = MotionSample(
                timestamp: timestampMs,
                accelX: motion.userAcceleration.x,
                accelY: motion.userAcceleration.y,
                accelZ: motion.userAcceleration.z,
                gyroX: motion.rotationRate.x,
                gyroY: motion.rotationRate.y,
                gyroZ: motion.rotationRate.z,
                roll: motion.attitude.roll,
                pitch: motion.attitude.pitch,
                yaw: motion.attitude.yaw
            )

            self.samplesLock.lock()
            self._samples.append(sample)
            let count = self._samples.count
            self.samplesLock.unlock()

            if count % 100 == 0 {
                DispatchQueue.main.async {
                    self.sampleCount = count
                }
            }
        }
    }

    func stopCollection() {
        motionManager.stopDeviceMotionUpdates()
        isRecording = false

        samplesLock.lock()
        let count = _samples.count
        samplesLock.unlock()

        DispatchQueue.main.async {
            self.sampleCount = count
        }
    }

    func reset() {
        samplesLock.lock()
        _samples = []
        samplesLock.unlock()
        startTime = nil
        DispatchQueue.main.async {
            self.sampleCount = 0
            self.isRecording = false
        }
    }
}
