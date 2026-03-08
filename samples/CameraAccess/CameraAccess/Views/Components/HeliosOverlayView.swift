import SwiftUI

struct HeliosOverlayView: View {
  @ObservedObject var stateManager: TaskStateManager

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // Bottom panel: action + countdown + urgency bar
      if let state = stateManager.currentState {
        VStack(spacing: 10) {
          // Action callout
          if let action = state.action {
            Text(action.uppercased())
              .font(.system(size: 22, weight: .heavy, design: .rounded))
              .foregroundColor(urgencyColor(state.urgency))
              .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 2)
              .multilineTextAlignment(.center)
          }

          // Stage + countdown row
          HStack(spacing: 16) {
            // Stage pill
            HStack(spacing: 6) {
              Circle()
                .fill(urgencyColor(state.urgency))
                .frame(width: 8, height: 8)
              Text(state.stage.replacingOccurrences(of: "_", with: " ").uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // Countdown + acceleration
            HStack(spacing: 6) {
              if stateManager.isAccelerating() {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.system(size: 12))
                  .foregroundColor(.orange)
              }

              if let seconds = state.seconds_est {
                HStack(spacing: 4) {
                  Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                  Text("\(seconds)s")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                }
              } else if let predicted = stateManager.predictedSecondsToAction {
                HStack(spacing: 4) {
                  Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                  Text("~\(Int(predicted))s")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                }
              }
            }
          }

          // Urgency bar
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.15))
                .frame(height: 6)

              RoundedRectangle(cornerRadius: 4)
                .fill(
                  LinearGradient(
                    colors: [urgencyColor(state.urgency).opacity(0.8), urgencyColor(state.urgency)],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: geo.size.width * CGFloat(min(state.urgency, 1.0)), height: 6)
                .animation(.easeInOut(duration: 0.3), value: state.urgency)
            }
          }
          .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(urgencyColor(state.urgency).opacity(0.3), lineWidth: 1)
            )
        )
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
