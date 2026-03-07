import Foundation

// MARK: - Redfish Service

@MainActor
class RedfishService: ObservableObject {

    // MARK: - Configuration

    private let useMockData: Bool
    private let mockScenario: RedfishMockGenerator.HealthScenario

    // MARK: - Initialization

    init(useMockData: Bool = true, mockScenario: RedfishMockGenerator.HealthScenario = .healthy) {
        self.useMockData = useMockData
        self.mockScenario = mockScenario
    }

    // MARK: - Public API

    func fetchHealthStatus(
        for device: NetBoxDevice,
        bmcURL: String? = nil,
        username: String? = nil,
        password: String? = nil
    ) async -> ServerHealthStatus? {
        if useMockData {
            return await fetchMockHealthStatus(for: device)
        }

        guard let bmcURL = bmcURL,
              let username = username,
              let password = password else {
            print("[RedfishService] Missing BMC credentials for \(device.name)")
            return nil
        }

        return await fetchRealHealthStatus(
            deviceName: device.name,
            bmcURL: bmcURL,
            username: username,
            password: password
        )
    }

    // MARK: - Mock Data

    private func fetchMockHealthStatus(for device: NetBoxDevice) async -> ServerHealthStatus? {
        guard device.deviceRole.display?.lowercased() == "server" else {
            return nil
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let system = RedfishMockGenerator.generateSystem(
            deviceName: device.name,
            scenario: mockScenario
        )
        let chassis = RedfishMockGenerator.generateChassis(
            deviceName: device.name,
            scenario: mockScenario
        )
        let thermal = RedfishMockGenerator.generateThermalData(
            deviceName: device.name,
            scenario: mockScenario
        )
        let power = RedfishMockGenerator.generatePowerData(
            deviceName: device.name,
            scenario: mockScenario
        )

        return ServerHealthStatus.fromRedfish(
            deviceName: device.name,
            system: system,
            chassis: chassis,
            thermal: thermal,
            power: power
        )
    }

    // MARK: - Real Redfish API

    private func fetchRealHealthStatus(
        deviceName: String,
        bmcURL: String,
        username: String,
        password: String
    ) async -> ServerHealthStatus? {
        async let systemResult = fetchSystem(bmcURL: bmcURL, username: username, password: password)
        async let chassisResult = fetchChassis(bmcURL: bmcURL, username: username, password: password)
        async let thermalResult = fetchThermal(bmcURL: bmcURL, username: username, password: password)
        async let powerResult = fetchPower(bmcURL: bmcURL, username: username, password: password)

        let (system, chassis, thermal, power) = await (systemResult, chassisResult, thermalResult, powerResult)

        return ServerHealthStatus.fromRedfish(
            deviceName: deviceName,
            system: system,
            chassis: chassis,
            thermal: thermal,
            power: power
        )
    }

    private func fetchSystem(bmcURL: String, username: String, password: String) async -> RedfishSystem? {
        await fetchRedfish(
            bmcURL: bmcURL,
            endpoint: "/redfish/v1/Systems/1",
            username: username,
            password: password
        )
    }

    private func fetchChassis(bmcURL: String, username: String, password: String) async -> RedfishChassis? {
        await fetchRedfish(
            bmcURL: bmcURL,
            endpoint: "/redfish/v1/Chassis/1",
            username: username,
            password: password
        )
    }

    private func fetchThermal(bmcURL: String, username: String, password: String) async -> RedfishThermalData? {
        await fetchRedfish(
            bmcURL: bmcURL,
            endpoint: "/redfish/v1/Chassis/1/Thermal",
            username: username,
            password: password
        )
    }

    private func fetchPower(bmcURL: String, username: String, password: String) async -> RedfishPowerData? {
        await fetchRedfish(
            bmcURL: bmcURL,
            endpoint: "/redfish/v1/Chassis/1/Power",
            username: username,
            password: password
        )
    }

    private func fetchRedfish<T: Codable>(
        bmcURL: String,
        endpoint: String,
        username: String,
        password: String
    ) async -> T? {
        guard let url = URL(string: bmcURL + endpoint) else {
            print("[RedfishService] Invalid URL: \(bmcURL + endpoint)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let loginData = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[RedfishService] Invalid response for \(endpoint)")
                return nil
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("[RedfishService] HTTP error \(httpResponse.statusCode) for \(endpoint)")
                return nil
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[RedfishService] Error fetching \(endpoint): \(error)")
            return nil
        }
    }
}
