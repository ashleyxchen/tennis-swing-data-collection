import Foundation

struct MotionSample: Codable {
    let timestamp: Double   // ms since recording start
    let accelX: Double      // g (userAcceleration)
    let accelY: Double
    let accelZ: Double
    let gyroX: Double       // rad/s (rotationRate)
    let gyroY: Double
    let gyroZ: Double
    let roll: Double        // rad (attitude)
    let pitch: Double
    let yaw: Double
}

extension MotionSample {
    /// Serialize an array of MotionSample to binary Data for efficient transfer.
    /// Layout: contiguous array of 10 Float64 values per sample.
    static func encode(_ samples: [MotionSample]) -> Data {
        var data = Data(capacity: samples.count * MemoryLayout<Double>.size * 10)
        for sample in samples {
            var values: [Double] = [
                sample.timestamp,
                sample.accelX, sample.accelY, sample.accelZ,
                sample.gyroX, sample.gyroY, sample.gyroZ,
                sample.roll, sample.pitch, sample.yaw
            ]
            data.append(Data(bytes: &values, count: values.count * MemoryLayout<Double>.size))
        }
        return data
    }

    /// Deserialize binary Data back to an array of MotionSample.
    static func decode(_ data: Data) -> [MotionSample] {
        let stride = MemoryLayout<Double>.size * 10
        let count = data.count / stride
        var samples: [MotionSample] = []
        samples.reserveCapacity(count)

        data.withUnsafeBytes { buffer in
            let doubles = buffer.bindMemory(to: Double.self)
            for i in 0..<count {
                let offset = i * 10
                samples.append(MotionSample(
                    timestamp: doubles[offset],
                    accelX: doubles[offset + 1],
                    accelY: doubles[offset + 2],
                    accelZ: doubles[offset + 3],
                    gyroX: doubles[offset + 4],
                    gyroY: doubles[offset + 5],
                    gyroZ: doubles[offset + 6],
                    roll: doubles[offset + 7],
                    pitch: doubles[offset + 8],
                    yaw: doubles[offset + 9]
                ))
            }
        }
        return samples
    }
}
