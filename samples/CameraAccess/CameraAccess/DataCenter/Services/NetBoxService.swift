import Foundation

// MARK: - NetBox Service

@MainActor
class NetBoxService: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .idle
    @Published var sites: [NetBoxSite] = []
    @Published var racks: [NetBoxRack] = []
    @Published var devices: [NetBoxDevice] = []
    @Published var cables: [NetBoxCable] = []
    @Published var ipAddresses: [NetBoxIPAddress] = []

    // MARK: - Configuration

    private let baseURL: String
    private let apiToken: String
    private let useMockData: Bool

    enum ConnectionState {
        case idle
        case connecting
        case connected
        case error(String)
    }

    // MARK: - Initialization

    init(baseURL: String = "", apiToken: String = "", useMockData: Bool = true) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.useMockData = useMockData
    }

    // MARK: - Public API

    func fetchAll() async {
        if useMockData {
            await fetchMockData()
        } else {
            await fetchRealData()
        }
    }

    func fetchSites() async -> Result<[NetBoxSite], Error> {
        if useMockData {
            return .success(NetBoxMockGenerator.generateSites())
        }

        return await fetch(endpoint: "/api/dcim/sites/")
    }

    func fetchRacks() async -> Result<[NetBoxRack], Error> {
        if useMockData {
            return .success(NetBoxMockGenerator.generateRacks())
        }

        return await fetch(endpoint: "/api/dcim/racks/")
    }

    func fetchDevices() async -> Result<[NetBoxDevice], Error> {
        if useMockData {
            return .success(NetBoxMockGenerator.generateDevices())
        }

        return await fetch(endpoint: "/api/dcim/devices/")
    }

    func fetchCables() async -> Result<[NetBoxCable], Error> {
        if useMockData {
            return .success(NetBoxMockGenerator.generateCables())
        }

        return await fetch(endpoint: "/api/dcim/cables/")
    }

    func fetchIPAddresses() async -> Result<[NetBoxIPAddress], Error> {
        if useMockData {
            return .success(NetBoxMockGenerator.generateIPAddresses())
        }

        return await fetch(endpoint: "/api/ipam/ip-addresses/")
    }

    // MARK: - Private Helpers

    private func fetchMockData() async {
        connectionState = .connecting

        try? await Task.sleep(nanoseconds: 500_000_000)

        sites = NetBoxMockGenerator.generateSites()
        racks = NetBoxMockGenerator.generateRacks()
        devices = NetBoxMockGenerator.generateDevices()
        cables = NetBoxMockGenerator.generateCables()
        ipAddresses = NetBoxMockGenerator.generateIPAddresses()

        connectionState = .connected
    }

    private func fetchRealData() async {
        connectionState = .connecting

        async let sitesResult = fetchSites()
        async let racksResult = fetchRacks()
        async let devicesResult = fetchDevices()
        async let cablesResult = fetchCables()
        async let ipResult = fetchIPAddresses()

        let results = await (sitesResult, racksResult, devicesResult, cablesResult, ipResult)

        if case .success(let fetchedSites) = results.0 {
            sites = fetchedSites
        }
        if case .success(let fetchedRacks) = results.1 {
            racks = fetchedRacks
        }
        if case .success(let fetchedDevices) = results.2 {
            devices = fetchedDevices
        }
        if case .success(let fetchedCables) = results.3 {
            cables = fetchedCables
        }
        if case .success(let fetchedIPs) = results.4 {
            ipAddresses = fetchedIPs
        }

        let hasError = [results.0, results.1, results.2, results.3, results.4].contains { result in
            if case .failure = result { return true }
            return false
        }

        if hasError {
            connectionState = .error("Failed to fetch some NetBox data")
        } else {
            connectionState = .connected
        }
    }

    private func fetch<T: Codable>(endpoint: String) async -> Result<[T], Error> {
        guard !baseURL.isEmpty else {
            return .failure(NetBoxError.invalidConfiguration("NetBox base URL not configured"))
        }

        guard let url = URL(string: baseURL + endpoint) else {
            return .failure(NetBoxError.invalidURL(endpoint))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetBoxError.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(NetBoxError.httpError(httpResponse.statusCode))
            }

            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(NetBoxListResponse<T>.self, from: data)

            return .success(listResponse.results)
        } catch {
            return .failure(NetBoxError.networkError(error))
        }
    }

    // MARK: - Errors

    enum NetBoxError: Error, LocalizedError {
        case invalidConfiguration(String)
        case invalidURL(String)
        case invalidResponse
        case httpError(Int)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration(let message):
                return "NetBox configuration error: \(message)"
            case .invalidURL(let endpoint):
                return "Invalid NetBox URL: \(endpoint)"
            case .invalidResponse:
                return "Invalid response from NetBox"
            case .httpError(let code):
                return "NetBox HTTP error: \(code)"
            case .networkError(let error):
                return "NetBox network error: \(error.localizedDescription)"
            }
        }
    }
}
