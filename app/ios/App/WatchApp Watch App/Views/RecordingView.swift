import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var coordinator: RecordingCoordinator

    var body: some View {
        VStack(spacing: 12) {
            // Status
            Text(coordinator.state.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundStyle(stateColor)

            // Elapsed time
            Text(formatTime(coordinator.elapsedMs))
                .font(.system(size: 36, weight: .medium, design: .monospaced))

            // Sample count
            Text("\(coordinator.motionRecorder.sampleCount) samples")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Labels
            HStack {
                Label(coordinator.strokeType, systemImage: "figure.tennis")
                    .font(.caption2)
                Spacer()
                Text(coordinator.impactLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            // Controls
            HStack(spacing: 16) {
                if coordinator.state == .recording {
                    Button {
                        coordinator.pauseRecording()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                } else if coordinator.state == .paused {
                    Button {
                        coordinator.resumeRecording()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                Button {
                    coordinator.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .navigationBarBackButtonHidden()
    }

    private var stateColor: Color {
        switch coordinator.state {
        case .recording: return .green
        case .paused: return .yellow
        case .transferring: return .orange
        case .idle: return .secondary
        }
    }

    private func formatTime(_ ms: Double) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
