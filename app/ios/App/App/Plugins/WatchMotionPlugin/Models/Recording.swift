import Foundation

struct Recording: Codable, Identifiable {
    let id: String
    var name: String
    let createdAt: Date
    let strokeType: String      // forehand/backhand/serve/shadow_swing/idle
    let impactLabel: String     // impact/no_impact
    let accelThreshold: Double
    let gyroThreshold: Double
    var state: String           // recording/paused/transferring/processing/complete/error
    var durationMs: Double?
    var sampleCount: Int?
    var detectedStrokes: Int?
    var dataFilename: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "strokeType": strokeType,
            "impactLabel": impactLabel,
            "accelThreshold": accelThreshold,
            "gyroThreshold": gyroThreshold,
            "state": state
        ]
        if let d = durationMs { dict["durationMs"] = d }
        if let s = sampleCount { dict["sampleCount"] = s }
        if let ds = detectedStrokes { dict["detectedStrokes"] = ds }
        return dict
    }
}

struct AppSettings: Codable {
    var accelThreshold: Double = 3.0
    var gyroThreshold: Double = 8.0
}
