import Foundation
import HealthKit
import Combine

class WorkoutManager: NSObject, ObservableObject {

    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?

    @Published var sessionState: HKWorkoutSessionState = .notStarted

    func start() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        } catch {
            print("[WorkoutManager] Error creating session: \(error)")
            return
        }

        session?.delegate = self
        session?.startActivity(with: Date())
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func end() {
        session?.end()
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            self.sessionState = toState
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("[WorkoutManager] Session error: \(error)")
    }
}
