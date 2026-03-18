import Foundation

class RecordingStorageManager {

    static let shared = RecordingStorageManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var recordingsDir: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("recordings")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var settingsURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("settings.json")
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            try? data.write(to: settingsURL)
        }
    }

    // MARK: - Recording CRUD

    func createRecording(_ recording: Recording) {
        let dir = recordingsDir.appendingPathComponent(recording.id)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        saveRecordingMetadata(recording)
    }

    func saveRecordingMetadata(_ recording: Recording) {
        let dir = recordingsDir.appendingPathComponent(recording.id)
        let metaURL = dir.appendingPathComponent("metadata.json")
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(recording) {
            try? data.write(to: metaURL)
        }
    }

    func saveRawSamples(_ data: Data, recordingId: String) -> String {
        let filename = "raw_samples.bin"
        let dir = recordingsDir.appendingPathComponent(recordingId)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
        } catch {
            print("[Storage] Failed to write raw_samples.bin for \(recordingId): \(error)")
        }
        return filename
    }

    func loadRawSamples(recordingId: String) -> [MotionSample]? {
        let dir = recordingsDir.appendingPathComponent(recordingId)
        let fileURL = dir.appendingPathComponent("raw_samples.bin")
        let exists = fileManager.fileExists(atPath: fileURL.path)
        print("[Storage] loadRawSamples: path=\(fileURL.path) exists=\(exists)")
        guard let data = try? Data(contentsOf: fileURL) else {
            print("[Storage] loadRawSamples: failed to read data for \(recordingId)")
            return nil
        }
        let samples = MotionSample.decode(data)
        print("[Storage] loadRawSamples: decoded \(samples.count) samples from \(data.count) bytes")
        return samples
    }

    func getRecording(_ id: String) -> Recording? {
        let metaURL = recordingsDir.appendingPathComponent(id).appendingPathComponent("metadata.json")
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: metaURL),
              let recording = try? decoder.decode(Recording.self, from: data) else {
            return nil
        }
        return recording
    }

    func listRecordings() -> [Recording] {
        decoder.dateDecodingStrategy = .iso8601
        guard let contents = try? fileManager.contentsOfDirectory(
            at: recordingsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var recordings: [Recording] = []
        for dir in contents {
            let metaURL = dir.appendingPathComponent("metadata.json")
            if let data = try? Data(contentsOf: metaURL),
               let recording = try? decoder.decode(Recording.self, from: data) {
                recordings.append(recording)
            }
        }

        return recordings.sorted { $0.createdAt > $1.createdAt }
    }

    func renameRecording(_ id: String, name: String) -> Bool {
        guard var recording = getRecording(id) else { return false }
        recording.name = name
        saveRecordingMetadata(recording)
        return true
    }

    func deleteRecording(_ id: String) -> Bool {
        let dir = recordingsDir.appendingPathComponent(id)
        do {
            try fileManager.removeItem(at: dir)
            return true
        } catch {
            print("[Storage] Delete error: \(error)")
            return false
        }
    }

    func updateRecording(_ recording: Recording) {
        saveRecordingMetadata(recording)
    }
}
