import Foundation

struct TaskState: Codable {
  let task: String
  let work_type: String
  let stage: String
  let urgency: Float
  let cues: [String]
  let action: String?
  let seconds_est: Int?
  let confidence: Float
}

@MainActor
class TaskStateManager: ObservableObject {
  @Published var currentState: TaskState?
  @Published var activeDomain: HeliosDomain = .cooking
  @Published var predictedSecondsToAction: Float?

  private var history: [(timestamp: Date, urgency: Float)] = []

  func updateState(_ newState: TaskState) {
    history.append((timestamp: Date(), urgency: newState.urgency))
    if history.count > 20 {
      history.removeFirst(history.count - 20)
    }
    currentState = newState
    predictedSecondsToAction = predictTimeToAction()
  }

  func predictTimeToAction() -> Float? {
    guard history.count >= 2 else { return nil }

    let recent = Array(history.suffix(5))
    guard recent.count >= 2 else { return nil }

    let lastUrgency = recent.last!.urgency
    if lastUrgency >= 0.9 { return nil }

    // Linear regression: urgency vs time
    let t0 = recent.first!.timestamp.timeIntervalSince1970
    let points: [(t: Double, u: Double)] = recent.map {
      (t: $0.timestamp.timeIntervalSince1970 - t0, u: Double($0.urgency))
    }

    let n = Double(points.count)
    let sumT = points.reduce(0.0) { $0 + $1.t }
    let sumU = points.reduce(0.0) { $0 + $1.u }
    let sumTU = points.reduce(0.0) { $0 + $1.t * $1.u }
    let sumT2 = points.reduce(0.0) { $0 + $1.t * $1.t }

    let denom = n * sumT2 - sumT * sumT
    guard abs(denom) > 1e-9 else { return nil }

    let slope = (n * sumTU - sumT * sumU) / denom
    guard slope > 0 else { return nil } // urgency not increasing

    let intercept = (sumU - slope * sumT) / n

    // Solve for t when urgency = 0.9
    let tAtTarget = (0.9 - intercept) / slope
    let currentT = points.last!.t
    let secondsRemaining = tAtTarget - currentT

    guard secondsRemaining > 0 else { return nil }
    return Float(secondsRemaining)
  }

  func isAccelerating() -> Bool {
    guard history.count >= 4 else { return false }

    let mid = history.count / 2
    let firstHalf = Array(history[0..<mid])
    let secondHalf = Array(history[mid...])

    func rateOfChange(_ slice: [(timestamp: Date, urgency: Float)]) -> Float {
      guard slice.count >= 2 else { return 0 }
      let dt = Float(slice.last!.timestamp.timeIntervalSince(slice.first!.timestamp))
      guard dt > 0 else { return 0 }
      return (slice.last!.urgency - slice.first!.urgency) / dt
    }

    return rateOfChange(secondHalf) > rateOfChange(firstHalf)
  }

  func reset() {
    history.removeAll()
    currentState = nil
    predictedSecondsToAction = nil
  }
}
