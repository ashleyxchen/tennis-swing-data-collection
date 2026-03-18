import Foundation
import Capacitor

@objc(WatchMotionPlugin)
public class WatchMotionPlugin: CAPPlugin, CAPBridgedPlugin {

    public let identifier = "WatchMotionPlugin"
    public let jsName = "WatchMotion"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getWatchStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pauseRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resumeRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listRecordings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "renameRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deleteRecording", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deleteRecordings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "exportDataset", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "shareExport", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getRecordingSamples", returnType: CAPPluginReturnPromise),
    ]

    private let sessionManager = PhoneSessionManager.shared
    private let storage = RecordingStorageManager.shared
    private let exportManager = ExportManager.shared

    public override func load() {
        // Wire up session callbacks
        sessionManager.onStatusUpdate = { [weak self] payload in
            self?.notifyListeners("recordingStateChanged", data: payload)
        }

        sessionManager.onError = { [weak self] payload in
            self?.notifyListeners("watchError", data: payload)
        }

        sessionManager.onRecordingDataReceived = { [weak self] recordingId, data, sampleCount, durationMs, strokeType, impactLabel in
            self?.handleRecordingData(recordingId: recordingId, data: data,
                                     sampleCount: sampleCount, durationMs: durationMs,
                                     strokeType: strokeType, impactLabel: impactLabel)
        }
    }

    // MARK: - Watch Status

    @objc func getWatchStatus(_ call: CAPPluginCall) {
        let status = sessionManager.getWatchStatus()
        call.resolve(status)
    }

    // MARK: - Recording Lifecycle

    @objc func startRecording(_ call: CAPPluginCall) {
        let strokeType = call.getString("strokeType") ?? "forehand"
        let impactLabel = call.getString("impactLabel") ?? "impact"
        let settings = storage.loadSettings()
        let accelThreshold = call.getDouble("accelThreshold") ?? settings.accelThreshold
        let gyroThreshold = call.getDouble("gyroThreshold") ?? settings.gyroThreshold

        let recordingId = UUID().uuidString

        let recording = Recording(
            id: recordingId,
            name: "\(strokeType) \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
            createdAt: Date(),
            strokeType: strokeType,
            impactLabel: impactLabel,
            accelThreshold: accelThreshold,
            gyroThreshold: gyroThreshold,
            state: "recording"
        )
        storage.createRecording(recording)

        // Send command to watch
        sessionManager.sendCommand("startRecording", payload: [
            "recordingId": recordingId,
            "strokeType": strokeType,
            "impactLabel": impactLabel
        ])

        call.resolve(["recordingId": recordingId])
    }

    @objc func pauseRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        sessionManager.sendCommand("pauseRecording", payload: ["recordingId": recordingId])

        if var recording = storage.getRecording(recordingId) {
            recording.state = "paused"
            storage.updateRecording(recording)
        }

        call.resolve(["success": true])
    }

    @objc func resumeRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        sessionManager.sendCommand("resumeRecording", payload: ["recordingId": recordingId])

        if var recording = storage.getRecording(recordingId) {
            recording.state = "recording"
            storage.updateRecording(recording)
        }

        call.resolve(["success": true])
    }

    @objc func stopRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        sessionManager.sendCommand("stopRecording", payload: ["recordingId": recordingId])

        if var recording = storage.getRecording(recordingId) {
            recording.state = "transferring"
            storage.updateRecording(recording)
        }

        call.resolve(["recordingId": recordingId])
    }

    // MARK: - Recording Management

    @objc func listRecordings(_ call: CAPPluginCall) {
        let recordings = storage.listRecordings()
        let list = recordings.map { $0.toDictionary() }
        call.resolve(["recordings": list])
    }

    @objc func getRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        guard let recording = storage.getRecording(recordingId) else {
            call.reject("Recording not found")
            return
        }
        call.resolve(recording.toDictionary())
    }

    @objc func renameRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId"),
              let name = call.getString("name") else {
            call.reject("recordingId and name required")
            return
        }
        let success = storage.renameRecording(recordingId, name: name)
        call.resolve(["success": success])
    }

    @objc func deleteRecording(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        let success = storage.deleteRecording(recordingId)
        call.resolve(["success": success])
    }

    @objc func deleteRecordings(_ call: CAPPluginCall) {
        guard let ids = call.getArray("recordingIds", String.self) else {
            call.reject("recordingIds required")
            return
        }
        var deletedCount = 0
        for id in ids {
            if storage.deleteRecording(id) {
                deletedCount += 1
            }
        }
        call.resolve(["success": true, "deletedCount": deletedCount])
    }

    // MARK: - Export

    @objc func exportDataset(_ call: CAPPluginCall) {
        guard let ids = call.getArray("recordingIds", String.self) else {
            call.reject("recordingIds required")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let result = self?.exportManager.exportDataset(recordingIds: ids) else {
                DispatchQueue.main.async {
                    call.reject("Export failed")
                }
                return
            }
            DispatchQueue.main.async {
                call.resolve([
                    "exportPath": result.path,
                    "summary": result.summary.toDictionary()
                ])
            }
        }
    }

    @objc func shareExport(_ call: CAPPluginCall) {
        guard let path = call.getString("exportPath") else {
            call.reject("exportPath required")
            return
        }
        exportManager.shareExport(path: path, from: self.bridge?.viewController)
        call.resolve(["success": true])
    }

    // MARK: - Settings

    @objc func getSettings(_ call: CAPPluginCall) {
        let settings = storage.loadSettings()
        call.resolve([
            "accelThreshold": settings.accelThreshold,
            "gyroThreshold": settings.gyroThreshold
        ])
    }

    @objc func updateSettings(_ call: CAPPluginCall) {
        var settings = storage.loadSettings()
        if let accel = call.getDouble("accelThreshold") {
            settings.accelThreshold = accel
        }
        if let gyro = call.getDouble("gyroThreshold") {
            settings.gyroThreshold = gyro
        }
        storage.saveSettings(settings)
        call.resolve(["success": true])
    }

    // MARK: - Recording Samples for Charting

    @objc func getRecordingSamples(_ call: CAPPluginCall) {
        guard let recordingId = call.getString("recordingId") else {
            call.reject("recordingId required")
            return
        }
        let maxPoints = call.getInt("maxPoints") ?? 2000

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let recording = self.storage.getRecording(recordingId) else {
                DispatchQueue.main.async { call.reject("Recording not found") }
                return
            }

            guard let samples = self.storage.loadRawSamples(recordingId: recordingId), !samples.isEmpty else {
                DispatchQueue.main.async { call.reject("No sample data available") }
                return
            }

            // Compute magnitudes
            var timestamps: [Double] = []
            var accelMags: [Double] = []
            var gyroMags: [Double] = []
            timestamps.reserveCapacity(samples.count)
            accelMags.reserveCapacity(samples.count)
            gyroMags.reserveCapacity(samples.count)

            for s in samples {
                timestamps.append(s.timestamp)
                accelMags.append(sqrt(s.accelX * s.accelX + s.accelY * s.accelY + s.accelZ * s.accelZ))
                gyroMags.append(sqrt(s.gyroX * s.gyroX + s.gyroY * s.gyroY + s.gyroZ * s.gyroZ))
            }

            // Detect peaks for annotation
            let windows = SwingProcessor.detectStrokes(
                samples: samples,
                strokeType: recording.strokeType,
                impactLabel: recording.impactLabel,
                accelThreshold: recording.accelThreshold,
                gyroThreshold: recording.gyroThreshold
            )
            let peakTimestamps = windows.map { $0.peakTimestamp }

            // LTTB downsampling if needed, preserving peak indices
            let count = samples.count
            if count > maxPoints {
                // Find indices of peaks so we can preserve them
                var peakIndices = Set<Int>()
                for pt in peakTimestamps {
                    // Find closest index
                    if let idx = timestamps.enumerated().min(by: { abs($0.element - pt) < abs($1.element - pt) })?.offset {
                        peakIndices.insert(idx)
                    }
                }

                let selected = Self.lttbDownsample(
                    timestamps: timestamps,
                    accelMags: accelMags,
                    gyroMags: gyroMags,
                    targetCount: maxPoints,
                    preserveIndices: peakIndices
                )

                let dsTimes = selected.map { timestamps[$0] }
                let dsAccel = selected.map { accelMags[$0] }
                let dsGyro = selected.map { gyroMags[$0] }

                let durationMs = (timestamps.last ?? 0) - (timestamps.first ?? 0)
                DispatchQueue.main.async {
                    call.resolve([
                        "timestamps": dsTimes,
                        "accelMagnitudes": dsAccel,
                        "gyroMagnitudes": dsGyro,
                        "peakTimestamps": peakTimestamps,
                        "sampleCount": count,
                        "durationMs": durationMs
                    ])
                }
            } else {
                let durationMs = (timestamps.last ?? 0) - (timestamps.first ?? 0)
                DispatchQueue.main.async {
                    call.resolve([
                        "timestamps": timestamps,
                        "accelMagnitudes": accelMags,
                        "gyroMagnitudes": gyroMags,
                        "peakTimestamps": peakTimestamps,
                        "sampleCount": count,
                        "durationMs": durationMs
                    ])
                }
            }
        }
    }

    /// Largest-Triangle-Three-Buckets downsampling with forced preservation of specific indices.
    private static func lttbDownsample(
        timestamps: [Double],
        accelMags: [Double],
        gyroMags: [Double],
        targetCount: Int,
        preserveIndices: Set<Int>
    ) -> [Int] {
        let count = timestamps.count
        guard count > targetCount else {
            return Array(0..<count)
        }

        // Use accel magnitude as the primary y-axis for LTTB triangle area
        var selected: [Int] = [0] // Always keep first point
        let bucketSize = Double(count - 2) / Double(targetCount - 2)

        var prevSelected = 0

        for i in 0..<(targetCount - 2) {
            let bucketStart = Int(Double(i) * bucketSize) + 1
            let bucketEnd = min(Int(Double(i + 1) * bucketSize) + 1, count - 1)

            // Next bucket average for triangle calculation
            let nextBucketStart = min(Int(Double(i + 1) * bucketSize) + 1, count - 1)
            let nextBucketEnd = min(Int(Double(i + 2) * bucketSize) + 1, count - 1)
            var avgX = 0.0, avgY = 0.0
            let nextCount = nextBucketEnd - nextBucketStart + 1
            for j in nextBucketStart...nextBucketEnd {
                avgX += timestamps[j]
                avgY += accelMags[j]
            }
            avgX /= Double(nextCount)
            avgY /= Double(nextCount)

            // Find point in current bucket with largest triangle area
            var bestIdx = bucketStart
            var bestArea = -1.0

            let ax = timestamps[prevSelected]
            let ay = accelMags[prevSelected]

            for j in bucketStart..<bucketEnd {
                let area = abs((ax - avgX) * (accelMags[j] - ay) - (ax - timestamps[j]) * (avgY - ay))
                // Boost preserved indices so they always win
                let boosted = preserveIndices.contains(j) ? Double.infinity : area
                if boosted > bestArea {
                    bestArea = boosted
                    bestIdx = j
                }
            }

            selected.append(bestIdx)
            prevSelected = bestIdx
        }

        selected.append(count - 1) // Always keep last point

        // Ensure all preserved indices are included
        let selectedSet = Set(selected)
        for idx in preserveIndices where !selectedSet.contains(idx) {
            selected.append(idx)
        }

        selected.sort()
        return selected
    }

    // MARK: - Handle Recording Data from Watch

    private func handleRecordingData(recordingId: String, data: Data, sampleCount: Int, durationMs: Double, strokeType: String, impactLabel: String) {
        print("[WatchMotion] handleRecordingData: id=\(recordingId) dataSize=\(data.count) sampleCount=\(sampleCount)")
        // Save raw data
        let filename = storage.saveRawSamples(data, recordingId: recordingId)

        // Load samples and process
        let samples = MotionSample.decode(data)

        // Create recording if it doesn't exist (watch-initiated recordings)
        var recording: Recording
        if let existing = storage.getRecording(recordingId) {
            recording = existing
        } else {
            let settings = storage.loadSettings()
            recording = Recording(
                id: recordingId,
                name: "\(strokeType) \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
                createdAt: Date(),
                strokeType: strokeType,
                impactLabel: impactLabel,
                accelThreshold: settings.accelThreshold,
                gyroThreshold: settings.gyroThreshold,
                state: "transferring"
            )
            storage.createRecording(recording)
        }
        recording.state = "processing"
        recording.dataFilename = filename
        recording.sampleCount = sampleCount
        recording.durationMs = durationMs
        storage.updateRecording(recording)

        notifyListeners("recordingStateChanged", data: [
            "recordingId": recordingId,
            "state": "processing",
            "sampleCount": sampleCount,
            "elapsedMs": durationMs
        ])

        // Run swing detection
        let windows = SwingProcessor.detectStrokes(
            samples: samples,
            strokeType: recording.strokeType,
            impactLabel: recording.impactLabel,
            accelThreshold: recording.accelThreshold,
            gyroThreshold: recording.gyroThreshold
        )

        recording.detectedStrokes = windows.count
        recording.state = "complete"
        storage.updateRecording(recording)

        notifyListeners("recordingComplete", data: [
            "recordingId": recordingId,
            "sampleCount": sampleCount,
            "strokesDetected": windows.count,
            "duration": durationMs
        ])
    }
}
