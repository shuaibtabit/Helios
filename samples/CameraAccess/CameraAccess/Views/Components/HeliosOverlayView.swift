import SwiftUI

struct HeliosOverlayView: View {
  @ObservedObject var stateManager: TaskStateManager

  var body: some View {
    VStack {
      // Top row: domain badge (left) + stage badge (right)
      HStack {
        StatusPill(
          color: .blue,
          text: "\(stateManager.activeDomain.displayName)"
        )

        Spacer()

        if let state = stateManager.currentState {
          StatusPill(
            color: urgencyColor(state.urgency),
            text: state.stage.replacingOccurrences(of: "_", with: " ").capitalized
          )
        }
      }

      Spacer()

      // Bottom: action prompt + prediction + urgency bar
      if let state = stateManager.currentState {
        VStack(spacing: 8) {
          if let action = state.action {
            Text(action.uppercased())
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.white)
              .shadow(color: .black, radius: 4)
          }

          HStack(spacing: 12) {
            if let seconds = stateManager.predictedSecondsToAction {
              Text("~\(Int(seconds))s")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            }

            if stateManager.isAccelerating() {
              Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
            }
          }

          // Urgency bar
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(height: 8)

              RoundedRectangle(cornerRadius: 4)
                .fill(urgencyColor(state.urgency))
                .frame(width: geo.size.width * CGFloat(min(state.urgency, 1.0)), height: 8)
            }
          }
          .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
      }
    }
  }

  private func urgencyColor(_ urgency: Float) -> Color {
    switch urgency {
    case ..<0.3: return .green
    case ..<0.5: return .yellow
    case ..<0.7: return .orange
    default: return .red
    }
  }
}
