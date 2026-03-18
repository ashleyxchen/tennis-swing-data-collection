import Foundation
import UIKit

class ExportManager {

    static let shared = ExportManager()

    private let fileManager = FileManager.default
    private let storage = RecordingStorageManager.shared

    struct ExportSummary {
        var totalRecordings: Int = 0
        var totalStrokes: Int = 0
        var strokeCounts: [String: Int] = [:]  // strokeType -> count
        var impactCounts: [String: Int] = [:]   // impactLabel -> count

        func toDictionary() -> [String: Any] {
            return [
                "totalRecordings": totalRecordings,
                "totalStrokes": totalStrokes,
                "strokeCounts": strokeCounts,
                "impactCounts": impactCounts
            ]
        }
    }

    // MARK: - Export

    func exportDataset(recordingIds: [String]) -> (path: String, summary: ExportSummary)? {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDir = docs.appendingPathComponent("exports")
        try? fileManager.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let exportName = "training_data_\(dateFormatter.string(from: Date()))"
        let exportDir = exportsDir.appendingPathComponent(exportName)

        // Create directory structure
        let strokeTypes = ["forehand", "backhand", "serve", "shadow_swing", "idle"]
        let impactLabels = ["impact", "no_impact"]

        for strokeType in strokeTypes {
            let dir = exportDir.appendingPathComponent("stroke_classification/\(strokeType)")
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        for impactLabel in impactLabels {
            let dir = exportDir.appendingPathComponent("impact_detection/\(impactLabel)")
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        var summary = ExportSummary()
        summary.totalRecordings = recordingIds.count

        // Process each recording
        for recordingId in recordingIds {
            guard let recording = storage.getRecording(recordingId),
                  let samples = storage.loadRawSamples(recordingId: recordingId) else {
                continue
            }

            let windows = SwingProcessor.detectStrokes(
                samples: samples,
                strokeType: recording.strokeType,
                impactLabel: recording.impactLabel,
                accelThreshold: recording.accelThreshold,
                gyroThreshold: recording.gyroThreshold
            )

            for (index, window) in windows.enumerated() {
                let csv = generateCSV(from: window.samples)
                let peakMs = Int(window.peakTimestamp)

                // Stroke classification CSV
                if recording.impactLabel == "impact" {
                    print("recording \(recording.name).impactLabel: \(recording.impactLabel)")
                    let strokeFilename = "stroke_\(peakMs).csv"
                    let strokeDir = exportDir.appendingPathComponent("stroke_classification/\(recording.strokeType)")
                    try? csv.write(to: strokeDir.appendingPathComponent(strokeFilename),
                                atomically: true, encoding: .utf8)
                }

                // Impact detection CSV
                let impactFilename = "window_\(peakMs).csv"
                let impactDir = exportDir.appendingPathComponent("impact_detection/\(recording.impactLabel)")
                try? csv.write(to: impactDir.appendingPathComponent(impactFilename),
                              atomically: true, encoding: .utf8)

                summary.totalStrokes += 1
                summary.strokeCounts[recording.strokeType, default: 0] += 1
                summary.impactCounts[recording.impactLabel, default: 0] += 1
            }
        }

        // Generate summary.txt
        let summaryText = generateSummaryText(exportName: exportName, summary: summary)
        try? summaryText.write(
            to: exportDir.appendingPathComponent("summary.txt"),
            atomically: true, encoding: .utf8
        )

        // Create zip
        let zipURL = exportsDir.appendingPathComponent("\(exportName).zip")
        if createZip(sourceDir: exportDir, zipURL: zipURL) {
            // Clean up unzipped directory
            try? fileManager.removeItem(at: exportDir)
            return (zipURL.path, summary)
        }

        return (exportDir.path, summary)
    }

    // MARK: - Share

    func shareExport(path: String, from viewController: UIViewController?) {
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: path) else { return }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        DispatchQueue.main.async {
            viewController?.present(activityVC, animated: true)
        }
    }

    // MARK: - CSV Generation

    private func generateCSV(from samples: [MotionSample]) -> String {
        var csv = "timestamp,accelX,accelY,accelZ,gyroX,gyroY,gyroZ,roll,pitch,yaw\n"

        for sample in samples {
            let ts = Int(sample.timestamp)
            csv += "\(ts),"
            csv += String(format: "%.6f,%.6f,%.6f,", sample.accelX, sample.accelY, sample.accelZ)
            csv += String(format: "%.6f,%.6f,%.6f,", sample.gyroX, sample.gyroY, sample.gyroZ)
            csv += String(format: "%.6f,%.6f,%.6f\n", sample.roll, sample.pitch, sample.yaw)
        }

        return csv
    }

    // MARK: - Summary

    private func generateSummaryText(exportName: String, summary: ExportSummary) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var text = """
        Export: \(exportName)
        Generated: \(dateFormatter.string(from: Date()))

        Recordings included: \(summary.totalRecordings)
        Total strokes extracted: \(summary.totalStrokes)

        Stroke Classification:
        """

        for type in ["forehand", "backhand", "serve", "shadow_swing", "idle"] {
            let count = summary.strokeCounts[type, default: 0]
            text += "\n  \(type): \(count) samples"
        }

        text += "\n\nImpact Detection:"
        for label in ["impact", "no_impact"] {
            let count = summary.impactCounts[label, default: 0]
            text += "\n  \(label): \(count) samples"
        }

        return text
    }

    // MARK: - Zip

    private func createZip(sourceDir: URL, zipURL: URL) -> Bool {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var success = false

        coordinator.coordinate(
            readingItemAt: sourceDir,
            options: .forUploading,
            error: &error
        ) { tempZipURL in
            do {
                try FileManager.default.moveItem(at: tempZipURL, to: zipURL)
                success = true
            } catch {
                print("[Export] Zip error: \(error)")
            }
        }

        if let error = error {
            print("[Export] Coordinator error: \(error)")
        }

        return success
    }
}
