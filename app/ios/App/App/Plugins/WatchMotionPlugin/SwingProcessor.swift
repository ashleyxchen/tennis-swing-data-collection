import Foundation

struct StrokeWindow {
    let peakTimestamp: Double    // ms in original recording
    let samples: [MotionSample]
}

class SwingProcessor {

    /// Detect strokes in a recording and extract windows around each peak.
    /// All recordings use peak-based detection: only windows around above-threshold motion are extracted.
    static func detectStrokes(
        samples: [MotionSample],
        strokeType: String,
        impactLabel: String,
        accelThreshold: Double,
        gyroThreshold: Double
    ) -> [StrokeWindow] {
        return detectPeakWindows(
            samples: samples,
            accelThreshold: accelThreshold,
            gyroThreshold: gyroThreshold,
            preMs: 150,
            postMs: 500,
            minGapMs: 500
        )
    }

    // MARK: - Peak-based detection

    private static func detectPeakWindows(
        samples: [MotionSample],
        accelThreshold: Double,
        gyroThreshold: Double,
        preMs: Double,
        postMs: Double,
        minGapMs: Double
    ) -> [StrokeWindow] {
        guard !samples.isEmpty else { return [] }

        // 1. Compute magnitudes and find above-threshold regions
        struct CandidatePeak {
            let index: Int
            let timestamp: Double
            let score: Double // accelMag + gyroMag
        }

        var candidates: [CandidatePeak] = []
        var inRegion = false
        var regionBest: CandidatePeak?

        for (i, sample) in samples.enumerated() {
            let accelMag = sqrt(sample.accelX * sample.accelX +
                              sample.accelY * sample.accelY +
                              sample.accelZ * sample.accelZ)
            let gyroMag = sqrt(sample.gyroX * sample.gyroX +
                              sample.gyroY * sample.gyroY +
                              sample.gyroZ * sample.gyroZ)

            let aboveThreshold = accelMag > accelThreshold || gyroMag > gyroThreshold

            if aboveThreshold {
                let score = accelMag + gyroMag
                if !inRegion {
                    inRegion = true
                    regionBest = CandidatePeak(index: i, timestamp: sample.timestamp, score: score)
                } else if let best = regionBest, score > best.score {
                    regionBest = CandidatePeak(index: i, timestamp: sample.timestamp, score: score)
                }
            } else {
                if inRegion, let best = regionBest {
                    candidates.append(best)
                    regionBest = nil
                    inRegion = false
                }
            }
        }
        // Handle region at end of recording
        if inRegion, let best = regionBest {
            candidates.append(best)
        }

        // 2. Non-maximum suppression: enforce minimum gap
        var peaks: [CandidatePeak] = []
        for candidate in candidates {
            if let last = peaks.last {
                if candidate.timestamp - last.timestamp >= minGapMs {
                    peaks.append(candidate)
                } else if candidate.score > last.score {
                    peaks[peaks.count - 1] = candidate
                }
            } else {
                peaks.append(candidate)
            }
        }

        // 3. Extract windows around each peak
        var windows: [StrokeWindow] = []
        for peak in peaks {
            let windowStart = peak.timestamp - preMs
            let windowEnd = peak.timestamp + postMs

            let windowSamples = samples.filter {
                $0.timestamp >= windowStart && $0.timestamp <= windowEnd
            }

            guard !windowSamples.isEmpty else { continue }

            // Normalize timestamps to start at 0
            let baseTime = windowSamples.first!.timestamp
            let normalized = windowSamples.map { sample in
                MotionSample(
                    timestamp: sample.timestamp - baseTime,
                    accelX: sample.accelX, accelY: sample.accelY, accelZ: sample.accelZ,
                    gyroX: sample.gyroX, gyroY: sample.gyroY, gyroZ: sample.gyroZ,
                    roll: sample.roll, pitch: sample.pitch, yaw: sample.yaw
                )
            }

            windows.append(StrokeWindow(peakTimestamp: peak.timestamp, samples: normalized))
        }

        return windows
    }

    // MARK: - Idle slicing

    private static func sliceIdleWindows(samples: [MotionSample], windowMs: Double) -> [StrokeWindow] {
        guard let firstTimestamp = samples.first?.timestamp,
              let lastTimestamp = samples.last?.timestamp else { return [] }

        var windows: [StrokeWindow] = []
        var windowStart = firstTimestamp

        while windowStart + windowMs <= lastTimestamp {
            let windowEnd = windowStart + windowMs

            let windowSamples = samples.filter {
                $0.timestamp >= windowStart && $0.timestamp < windowEnd
            }

            guard !windowSamples.isEmpty else {
                windowStart += windowMs
                continue
            }

            let baseTime = windowSamples.first!.timestamp
            let normalized = windowSamples.map { sample in
                MotionSample(
                    timestamp: sample.timestamp - baseTime,
                    accelX: sample.accelX, accelY: sample.accelY, accelZ: sample.accelZ,
                    gyroX: sample.gyroX, gyroY: sample.gyroY, gyroZ: sample.gyroZ,
                    roll: sample.roll, pitch: sample.pitch, yaw: sample.yaw
                )
            }

            windows.append(StrokeWindow(peakTimestamp: windowStart, samples: normalized))
            windowStart += windowMs
        }

        return windows
    }
}
