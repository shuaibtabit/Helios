import Foundation
import SwiftUI

@MainActor
class GeminiSessionViewModel: ObservableObject {
  @Published var isGeminiActive: Bool = false
  @Published var connectionState: GeminiConnectionState = .disconnected
  @Published var isModelSpeaking: Bool = false
  @Published var errorMessage: String?
  @Published var userTranscript: String = ""
  @Published var aiTranscript: String = ""
  @Published var toolCallStatus: ToolCallStatus = .idle
  @Published var agentConnectionState: HeliosAgentConnectionState = .notConfigured
  let taskStateManager = TaskStateManager()
  private let geminiService = GeminiLiveService()
  private let agentBridge = HeliosAgentBridge()
  private var toolCallRouter: ToolCallRouter?
  private let audioManager = AudioManager()
  var dataCenterCoordinator: DataCenterCoordinator?
  private var lastVideoFrameTime: Date = .distantPast
  private var stateObservation: Task<Void, Never>?
  private var autoPromptTask: Task<Void, Never>?
  private var turnTextBuffer = ""
  private var frameCount = 0

  var streamingMode: StreamingMode = .glasses

  func startSession() async {
    guard !isGeminiActive else { return }

    guard GeminiConfig.isConfigured else {
      errorMessage = "Gemini API key not configured. Open GeminiConfig.swift and replace YOUR_GEMINI_API_KEY with your key from https://aistudio.google.com/apikey"
      return
    }

    isGeminiActive = true

    // Wire audio callbacks
    audioManager.onAudioCaptured = { [weak self] data in
      guard let self else { return }
      Task { @MainActor in
        // Mute mic while model speaks when speaker is on the phone
        // (loudspeaker + co-located mic overwhelms iOS echo cancellation)
        let speakerOnPhone = self.streamingMode == .iPhone || SettingsManager.shared.speakerOutputEnabled
        if speakerOnPhone && self.geminiService.isModelSpeaking { return }
        self.geminiService.sendAudio(data: data)
      }
    }

    geminiService.onAudioReceived = { [weak self] data in
      self?.audioManager.playAudio(data: data)
    }

    geminiService.onInterrupted = { [weak self] in
      self?.audioManager.stopPlayback()
    }

    geminiService.onTextReceived = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        self.turnTextBuffer += text
      }
    }

    geminiService.onTurnComplete = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.extractAndProcessState(from: self.turnTextBuffer)
        self.turnTextBuffer = ""
        // Clear user transcript when AI finishes responding
        self.userTranscript = ""
      }
    }

    geminiService.onInputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        self.userTranscript += text
        self.aiTranscript = ""
      }
    }

    geminiService.onOutputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        self.aiTranscript += text
        self.turnTextBuffer += text
      }
    }

    // Handle unexpected disconnection
    geminiService.onDisconnected = { [weak self] reason in
      guard let self else { return }
      Task { @MainActor in
        guard self.isGeminiActive else { return }
        self.stopSession()
        self.errorMessage = "Connection lost: \(reason ?? "Unknown error")"
      }
    }

    // Check Helios Agent connectivity and start fresh session
    await agentBridge.checkConnection()
    agentBridge.resetSession()

    // Wire tool call handling
    toolCallRouter = ToolCallRouter(bridge: agentBridge)

    geminiService.onToolCall = { [weak self] toolCall in
      guard let self else { return }
      Task { @MainActor in
        for call in toolCall.functionCalls {
          self.toolCallRouter?.handleToolCall(call) { [weak self] response in
            self?.geminiService.sendToolResponse(response)
          }
        }
      }
    }

    geminiService.onToolCallCancellation = { [weak self] cancellation in
      guard let self else { return }
      Task { @MainActor in
        self.toolCallRouter?.cancelToolCalls(ids: cancellation.ids)
      }
    }

    // Observe service state
    stateObservation = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard !Task.isCancelled else { break }
        self.connectionState = self.geminiService.connectionState
        self.isModelSpeaking = self.geminiService.isModelSpeaking
        self.toolCallStatus = self.agentBridge.lastToolCallStatus
        self.agentConnectionState = self.agentBridge.connectionState
      }
    }

    // Setup audio
    do {
      try audioManager.setupAudioSession(useIPhoneMode: streamingMode == .iPhone)
    } catch {
      errorMessage = "Audio setup failed: \(error.localizedDescription)"
      isGeminiActive = false
      return
    }

    // Connect to Gemini and wait for setupComplete
    let setupOk = await geminiService.connect()

    if !setupOk {
      let msg: String
      if case .error(let err) = geminiService.connectionState {
        msg = err
      } else {
        msg = "Failed to connect to Gemini"
      }
      errorMessage = msg
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }

    // Start mic capture
    do {
      try audioManager.startCapture()
    } catch {
      errorMessage = "Mic capture failed: \(error.localizedDescription)"
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }

    // Auto-prompt timer: trigger Gemini to speak proactively every ~10s
    autoPromptTask = Task { [weak self] in
      // Wait a few seconds for Gemini to receive first frames
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      while !Task.isCancelled {
        guard let self, self.isGeminiActive, self.connectionState == .ready else { break }
        // Only auto-prompt when Gemini is NOT already speaking
        if !self.geminiService.isModelSpeaking {
          let domain = self.taskStateManager.activeDomain
          let prompt: String
          if domain == .cooking {
            prompt = "Based on what you ACTUALLY SEE in this frame right now, give a brief spoken update. Only describe what is visually present — do not assume or hallucinate browning, color changes, or doneness you cannot see. If cooking, include your seconds_est countdown. If you see eggs or a stove and haven't started guiding yet, proactively offer to help cook."
          } else {
            prompt = "Based on what you see right now, give a brief spoken status update about the equipment or environment."
          }
          self.geminiService.sendTextTurn(prompt)
        }
        try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
      }
    }

    // Start DataCenter monitoring if in datacenter domain
    if taskStateManager.activeDomain == .dataCenter {
      let mockMode = SettingsManager.shared.dataCenterMockMode
      dataCenterCoordinator = DataCenterCoordinator(
        useMockData: mockMode,
        netboxBaseURL: mockMode ? "" : SettingsManager.shared.netboxBaseURL,
        netboxAPIToken: mockMode ? "" : SettingsManager.shared.netboxAPIToken,
        mockScenario: SettingsManager.shared.dataCenterMockScenario
      )
      await dataCenterCoordinator?.startMonitoring(refreshInterval: 30)
      // Send initial datacenter context to prime Gemini
      if let coordinator = dataCenterCoordinator, coordinator.inventory != nil {
        let initialContext = "DATACENTER SESSION START. " + coordinator.generateAIContext()
        geminiService.sendTextContext(initialContext)
        NSLog("[Helios] Sent initial datacenter context (%d chars)", initialContext.count)
      }
    }
  }

  func stopSession() {
    isGeminiActive = false
    connectionState = .disconnected
    isModelSpeaking = false
    toolCallRouter?.cancelAll()
    toolCallRouter = nil
    audioManager.stopPlayback()
    audioManager.stopCapture()
    geminiService.disconnect()
    stateObservation?.cancel()
    stateObservation = nil
    autoPromptTask?.cancel()
    autoPromptTask = nil
    dataCenterCoordinator?.stopMonitoring()
    dataCenterCoordinator = nil
    userTranscript = ""
    aiTranscript = ""
    toolCallStatus = .idle
  }

  func sendVideoFrameIfThrottled(image: UIImage) {
    guard isGeminiActive, connectionState == .ready else { return }
    let now = Date()
    guard now.timeIntervalSince(lastVideoFrameTime) >= GeminiConfig.videoFrameInterval else { return }
    lastVideoFrameTime = now

    frameCount += 1
    var frameContext = "Frame \(frameCount)."
    if let prevState = taskStateManager.currentState,
       let data = try? JSONEncoder().encode(prevState),
       let json = String(data: data, encoding: .utf8) {
      frameContext += " Previous state: \(json)"
    }
    if let prediction = taskStateManager.predictedSecondsToAction {
      frameContext += " Predicted seconds to action: \(Int(prediction))."
    }
    if taskStateManager.isAccelerating() {
      frameContext += " Urgency is ACCELERATING."
    }

    // Add datacenter context if in datacenter domain
    if taskStateManager.activeDomain == .dataCenter,
       let coordinator = dataCenterCoordinator {
      frameContext += " \(coordinator.generateCompactContext())"
    }

    geminiService.sendTextContext(frameContext)
    geminiService.sendVideoFrame(image: image)
  }

  func switchDomain(_ domain: HeliosDomain) async {
    let wasActive = isGeminiActive
    if wasActive {
      stopSession()
    }
    SettingsManager.shared.heliosDomain = domain
    taskStateManager.activeDomain = domain
    taskStateManager.reset()
    frameCount = 0
    turnTextBuffer = ""
    if wasActive {
      try? await Task.sleep(nanoseconds: 500_000_000)
      await startSession()
    }
  }

  // MARK: - JSON State Parsing

  private func extractAndProcessState(from text: String) {
    guard !text.isEmpty else { return }

    var jsonString: String?

    // Try ```json ... ``` block first
    if let startRange = text.range(of: "```json"),
       let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
      jsonString = String(text[startRange.upperBound..<endRange.lowerBound])
    }

    // Fallback: first { to last }
    if jsonString == nil,
       let firstBrace = text.firstIndex(of: "{"),
       let lastBrace = text.lastIndex(of: "}") {
      jsonString = String(text[firstBrace...lastBrace])
    }

    guard let jsonString, let data = jsonString.data(using: .utf8) else { return }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      let state = try decoder.decode(TaskState.self, from: data)
      taskStateManager.updateState(state)
      NSLog("[Helios] State: stage=%@ urgency=%.2f", state.stage, state.urgency)
    } catch {
      NSLog("[Helios] Failed to decode TaskState: %@", error.localizedDescription)
    }
  }

}
