import Foundation

final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  private enum Key: String {
    case geminiAPIKey
    case agentHost
    case agentPort
    case agentHookToken
    case agentGatewayToken
    case geminiSystemPrompt
    case heliosDomain
    case webrtcSignalingURL
    case speakerOutputEnabled
    case netboxBaseURL
    case netboxAPIToken
    case redfishEnabled
    case dataCenterMockMode
    case dataCenterMockScenario
  }

  private init() {}

  // MARK: - Gemini

  var geminiAPIKey: String {
    get { defaults.string(forKey: Key.geminiAPIKey.rawValue) ?? Secrets.geminiAPIKey }
    set { defaults.set(newValue, forKey: Key.geminiAPIKey.rawValue) }
  }

  var geminiSystemPrompt: String {
    get { defaults.string(forKey: Key.geminiSystemPrompt.rawValue) ?? GeminiConfig.defaultSystemInstruction }
    set { defaults.set(newValue, forKey: Key.geminiSystemPrompt.rawValue) }
  }

  var heliosDomain: HeliosDomain {
    get { HeliosDomain(rawValue: defaults.string(forKey: Key.heliosDomain.rawValue) ?? "") ?? .cooking }
    set { defaults.set(newValue.rawValue, forKey: Key.heliosDomain.rawValue) }
  }

  // MARK: - Agent Gateway

  var agentHost: String {
    get { defaults.string(forKey: Key.agentHost.rawValue) ?? Secrets.agentHost }
    set { defaults.set(newValue, forKey: Key.agentHost.rawValue) }
  }

  var agentPort: Int {
    get {
      let stored = defaults.integer(forKey: Key.agentPort.rawValue)
      return stored != 0 ? stored : Secrets.agentPort
    }
    set { defaults.set(newValue, forKey: Key.agentPort.rawValue) }
  }

  var agentHookToken: String {
    get { defaults.string(forKey: Key.agentHookToken.rawValue) ?? Secrets.agentHookToken }
    set { defaults.set(newValue, forKey: Key.agentHookToken.rawValue) }
  }

  var agentGatewayToken: String {
    get { defaults.string(forKey: Key.agentGatewayToken.rawValue) ?? Secrets.agentGatewayToken }
    set { defaults.set(newValue, forKey: Key.agentGatewayToken.rawValue) }
  }

  // MARK: - WebRTC

  var webrtcSignalingURL: String {
    get { defaults.string(forKey: Key.webrtcSignalingURL.rawValue) ?? Secrets.webrtcSignalingURL }
    set { defaults.set(newValue, forKey: Key.webrtcSignalingURL.rawValue) }
  }

  // MARK: - Audio

  var speakerOutputEnabled: Bool {
    get { defaults.bool(forKey: Key.speakerOutputEnabled.rawValue) }
    set { defaults.set(newValue, forKey: Key.speakerOutputEnabled.rawValue) }
  }

  // MARK: - DataCenter

  var netboxBaseURL: String {
    get { defaults.string(forKey: Key.netboxBaseURL.rawValue) ?? "" }
    set { defaults.set(newValue, forKey: Key.netboxBaseURL.rawValue) }
  }

  var netboxAPIToken: String {
    get { defaults.string(forKey: Key.netboxAPIToken.rawValue) ?? "" }
    set { defaults.set(newValue, forKey: Key.netboxAPIToken.rawValue) }
  }

  var redfishEnabled: Bool {
    get { defaults.bool(forKey: Key.redfishEnabled.rawValue) }
    set { defaults.set(newValue, forKey: Key.redfishEnabled.rawValue) }
  }

  var dataCenterMockMode: Bool {
    get {
      if defaults.object(forKey: Key.dataCenterMockMode.rawValue) == nil {
        return true
      }
      return defaults.bool(forKey: Key.dataCenterMockMode.rawValue)
    }
    set { defaults.set(newValue, forKey: Key.dataCenterMockMode.rawValue) }
  }

  var dataCenterMockScenario: MockDataCenterScenarios.Scenario {
    get {
      let raw = defaults.string(forKey: Key.dataCenterMockScenario.rawValue) ?? "mixedHealth"
      return MockDataCenterScenarios.Scenario.from(raw) ?? .mixedHealth
    }
    set { defaults.set(newValue.rawString, forKey: Key.dataCenterMockScenario.rawValue) }
  }

  // MARK: - Reset

  func resetAll() {
    for key in [Key.geminiAPIKey, .geminiSystemPrompt, .heliosDomain, .agentHost, .agentPort,
                .agentHookToken, .agentGatewayToken, .webrtcSignalingURL,
                .speakerOutputEnabled, .netboxBaseURL, .netboxAPIToken, .redfishEnabled,
                .dataCenterMockMode, .dataCenterMockScenario] {
      defaults.removeObject(forKey: key.rawValue)
    }
  }
}
