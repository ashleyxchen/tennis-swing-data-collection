import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: RecordingCoordinator

    @State private var selectedStroke: String = "forehand"
    @State private var selectedImpact: String = "impact"

    private let strokeTypes = ["forehand", "backhand", "serve", "shadow_swing", "idle"]
    private let impactLabels = ["impact", "no_impact"]

    var body: some View {
        NavigationStack {
            if coordinator.state != .idle {
                RecordingView()
            } else {
                startView
            }
        }
    }

    private var startView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Connection status
                HStack {
                    Circle()
                        .fill(coordinator.sessionManager.isReachable ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(coordinator.sessionManager.isReachable ? "Connected" : "Disconnected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Stroke type picker
                NavigationLink {
                    List(strokeTypes, id: \.self) { type in
                        Button {
                            selectedStroke = type
                        } label: {
                            HStack {
                                Spacer()
                                Text(shortLabel(type))
                                Spacer()
                                if type == selectedStroke {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                            }
                        }
                    }
                    .navigationTitle("Stroke")
                } label: {
                    HStack {
                        Spacer()
                        Text("Stroke")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(shortLabel(selectedStroke))
                        Spacer()
                    }
                }

                // Impact picker
                NavigationLink {
                    List(impactLabels, id: \.self) { label in
                        Button {
                            selectedImpact = label
                        } label: {
                            HStack {
                                Spacer()
                                Text(shortLabel(label))
                                Spacer()
                                if label == selectedImpact {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                            }
                        }
                    }
                    .navigationTitle("Impact")
                } label: {
                    HStack {
                        Spacer()
                        Text("Impact")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(shortLabel(selectedImpact))
                        Spacer()
                    }
                }

                // Start button
                Button {
                    coordinator.startFromWatch(
                        strokeType: selectedStroke,
                        impactLabel: selectedImpact
                    )
                } label: {
                    Text("START")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal)
        }
    }

    private func shortLabel(_ value: String) -> String {
        switch value {
        case "forehand": return "FH"
        case "backhand": return "BH"
        case "serve": return "SV"
        case "shadow_swing": return "Shadow"
        case "idle": return "Idle"
        case "impact": return "Impact"
        case "no_impact": return "No Impact"
        default: return value
        }
    }
}
