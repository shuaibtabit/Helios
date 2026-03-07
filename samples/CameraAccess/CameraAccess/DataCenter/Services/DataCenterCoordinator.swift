import Foundation
import Combine

// MARK: - DataCenter Coordinator

@MainActor
class DataCenterCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var inventory: DataCenterInventory?
    @Published var isMonitoring: Bool = false
    @Published var lastError: String?

    // MARK: - Services

    private let netboxService: NetBoxService
    private let redfishService: RedfishService
    private let useMockData: Bool

    // MARK: - Monitoring

    private var refreshTask: Task<Void, Never>?
    private var refreshInterval: TimeInterval = 30.0

    // MARK: - Initialization

    init(
        useMockData: Bool = true,
        netboxBaseURL: String = "",
        netboxAPIToken: String = "",
        mockScenario: MockDataCenterScenarios.Scenario = .healthy
    ) {
        self.useMockData = useMockData

        if useMockData {
            self.netboxService = NetBoxService(useMockData: true)
            let redfishScenario: RedfishMockGenerator.HealthScenario
            switch mockScenario {
            case .healthy:
                redfishScenario = .healthy
            case .degradedCooling:
                redfishScenario = .degradedCooling
            case .serverDown:
                redfishScenario = .offline
            case .powerIssue:
                redfishScenario = .powerSupplyFailure
            case .criticalTemperature:
                redfishScenario = .criticalTemperature
            case .mixedHealth:
                redfishScenario = .healthy
            }
            self.redfishService = RedfishService(useMockData: true, mockScenario: redfishScenario)

            self.inventory = MockDataCenterScenarios.generateInventory(scenario: mockScenario)
        } else {
            self.netboxService = NetBoxService(
                baseURL: netboxBaseURL,
                apiToken: netboxAPIToken,
                useMockData: false
            )
            self.redfishService = RedfishService(useMockData: false)
        }
    }

    // MARK: - Public API

    func startMonitoring(refreshInterval: TimeInterval = 30.0) async {
        guard !isMonitoring else { return }

        self.refreshInterval = refreshInterval
        isMonitoring = true

        await refreshInventory()

        refreshTask = Task {
            while !Task.isCancelled && isMonitoring {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                if !Task.isCancelled && isMonitoring {
                    await refreshInventory()
                }
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshInventory() async {
        await netboxService.fetchAll()

        let devices = netboxService.devices

        let devicesWithHealth = await withTaskGroup(
            of: DeviceWithHealth.self,
            returning: [DeviceWithHealth].self
        ) { group in
            for device in devices {
                group.addTask {
                    let healthStatus = await self.redfishService.fetchHealthStatus(for: device)
                    return DeviceWithHealth(device: device, healthStatus: healthStatus)
                }
            }

            var results: [DeviceWithHealth] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        inventory = DataCenterInventory(
            sites: netboxService.sites,
            racks: netboxService.racks,
            devices: devicesWithHealth,
            cables: netboxService.cables,
            ipAddresses: netboxService.ipAddresses,
            lastUpdated: Date()
        )
    }

    // MARK: - AI Context Generation

    func generateAIContext(focusedDevice: String? = nil) -> String {
        guard let inventory = inventory else {
            return "DATACENTER CONTEXT: No inventory data available"
        }

        var context = "\n" + String(repeating: "=", count: 60) + "\n"
        context += "DATACENTER INFRASTRUCTURE STATUS\n"
        context += String(repeating: "=", count: 60) + "\n"

        // Summary stats
        context += "Total Infrastructure: \(inventory.sites.count) sites, \(inventory.racks.count) racks, \(inventory.totalDevices) devices\n"

        // Sites breakdown
        context += "\nSITES:\n"
        for site in inventory.sites {
            let devicesInSite = getDevices(bySite: site.name)
            context += "• \(site.name) (\(site.slug)): \(devicesInSite.count) devices"
            if let facility = site.facility {
                context += " - \(facility)"
            }
            context += "\n"
        }

        // Health overview
        context += "\nHEALTH STATUS:\n"
        if inventory.criticalDevices > 0 || inventory.degradedDevices > 0 || inventory.offlineDevices > 0 {
            if inventory.criticalDevices > 0 {
                context += "⛔️ CRITICAL: \(inventory.criticalDevices) devices\n"
            }
            if inventory.degradedDevices > 0 {
                context += "⚠️ DEGRADED: \(inventory.degradedDevices) devices\n"
            }
            if inventory.offlineDevices > 0 {
                context += "⭕️ OFFLINE: \(inventory.offlineDevices) devices\n"
            }
            context += "✅ HEALTHY: \(inventory.healthyDevices) devices\n"

            // Detail on problem devices
            let devicesWithIssues = inventory.devices.filter { device in
                device.healthStatus?.hasIssues == true || device.healthStatus?.overallHealth == .offline
            }.sorted { (d1, d2) -> Bool in
                let p1 = d1.healthStatus?.overallHealth == .critical ? 0 : (d1.healthStatus?.overallHealth == .degraded ? 1 : 2)
                let p2 = d2.healthStatus?.overallHealth == .critical ? 0 : (d2.healthStatus?.overallHealth == .degraded ? 1 : 2)
                return p1 < p2
            }

            if !devicesWithIssues.isEmpty {
                context += "\nPROBLEM DEVICES:\n"
                for device in devicesWithIssues.prefix(8) {
                    let health = device.healthStatus?.overallHealth.rawValue ?? "Unknown"
                    context += "• \(device.name)"
                    if let rack = device.rackName {
                        context += " (Rack \(rack))"
                    }
                    context += " - \(health)\n"

                    if let critical = device.healthStatus?.criticalIssues, !critical.isEmpty {
                        for issue in critical.prefix(2) {
                            context += "  ⛔️ \(issue.message)\n"
                        }
                    }
                    if let warnings = device.healthStatus?.warnings, !warnings.isEmpty {
                        for issue in warnings.prefix(1) {
                            context += "  ⚠️ \(issue.message)\n"
                        }
                    }
                }
            }
        } else {
            context += "✅ All \(inventory.healthyDevices) devices operational\n"
        }

        // Equipment breakdown
        let servers = getDevices(byRole: "Server")
        let network = getDevices(byRole: "Network")
        let storage = getDevices(byRole: "Storage")

        context += "\nEQUIPMENT INVENTORY:\n"
        context += "• Servers: \(servers.count)\n"
        if !network.isEmpty {
            context += "• Network: \(network.count)\n"
        }
        if !storage.isEmpty {
            context += "• Storage: \(storage.count)\n"
        }

        // Focused device if specified
        if let focusedDevice = focusedDevice,
           let device = inventory.devices.first(where: { $0.name == focusedDevice }) {
            context += "\n" + String(repeating: "-", count: 60) + "\n"
            context += generateDeviceContext(device)
        }

        context += String(repeating: "=", count: 60) + "\n"

        return context
    }

    func generateDeviceContext(_ device: DeviceWithHealth) -> String {
        var context = "FOCUSED DEVICE: \(device.name)\n"
        context += "- Role: \(device.role)\n"

        if let rack = device.rackName, let position = device.position {
            context += "- Location: Rack \(rack), U\(Int(position))\n"
        }

        if let healthStatus = device.healthStatus {
            context += "- Power: \(healthStatus.powerState)\n"
            context += "- Health: \(healthStatus.overallHealth.rawValue)\n"

            if let systemInfo = healthStatus.systemInfo {
                if let manufacturer = systemInfo.manufacturer, let model = systemInfo.model {
                    context += "- Hardware: \(manufacturer) \(model)\n"
                }
                if let cpuCount = systemInfo.processorCount, let cpuModel = systemInfo.processorModel {
                    context += "- CPU: \(cpuCount)x \(cpuModel)\n"
                }
                if let memory = systemInfo.totalMemoryGiB {
                    context += "- Memory: \(Int(memory)) GB\n"
                }
            }

            if !healthStatus.criticalIssues.isEmpty {
                context += "- CRITICAL ISSUES:\n"
                for issue in healthStatus.criticalIssues {
                    context += "  • \(issue.component): \(issue.message)\n"
                    if let details = issue.details {
                        context += "    (\(details))\n"
                    }
                }
            }

            if !healthStatus.warnings.isEmpty {
                context += "- WARNINGS:\n"
                for issue in healthStatus.warnings {
                    context += "  • \(issue.component): \(issue.message)\n"
                }
            }

            if let thermal = healthStatus.thermalInfo {
                context += "- Temperatures:\n"
                for temp in thermal.temperatures.prefix(4) {
                    context += "  • \(temp.name): \(Int(temp.currentCelsius))°C"
                    if let critical = temp.criticalThreshold {
                        context += " (critical: \(Int(critical))°C)"
                    }
                    context += "\n"
                }
            }

            if let power = healthStatus.powerInfo {
                if let totalPower = power.totalPowerWatts {
                    context += "- Power Consumption: \(Int(totalPower))W"
                    if let capacity = power.powerCapacityWatts {
                        context += " / \(Int(capacity))W capacity\n"
                    } else {
                        context += "\n"
                    }
                }
            }
        } else {
            context += "- No health monitoring available\n"
        }

        if let ip = device.primaryIP {
            context += "- Primary IP: \(ip)\n"
        }

        return context
    }

    // MARK: - Device Queries

    func getDevice(byName name: String) -> DeviceWithHealth? {
        inventory?.devices.first { $0.name == name }
    }

    func getDevices(inRack rackName: String) -> [DeviceWithHealth] {
        inventory?.devices.filter { $0.rackName == rackName } ?? []
    }

    func getDevices(bySite siteName: String) -> [DeviceWithHealth] {
        inventory?.devices.filter { device in
            device.device.site.display?.contains(siteName) ?? false ||
            device.device.site.name?.contains(siteName) ?? false
        } ?? []
    }

    func getDevices(byRole role: String) -> [DeviceWithHealth] {
        inventory?.devices.filter { device in
            device.device.deviceRole.display?.lowercased() == role.lowercased() ||
            device.device.deviceRole.name?.lowercased() == role.lowercased()
        } ?? []
    }

    func getCriticalDevices() -> [DeviceWithHealth] {
        inventory?.devices.filter { $0.healthStatus?.overallHealth == .critical } ?? []
    }

    func getDegradedDevices() -> [DeviceWithHealth] {
        inventory?.devices.filter { $0.healthStatus?.overallHealth == .degraded } ?? []
    }

    func getHealthyDevices() -> [DeviceWithHealth] {
        inventory?.devices.filter { $0.healthStatus?.overallHealth == .healthy } ?? []
    }

    func getOfflineDevices() -> [DeviceWithHealth] {
        inventory?.devices.filter { $0.healthStatus?.overallHealth == .offline } ?? []
    }

    func getRackSummary(rackName: String) -> String? {
        guard let inventory = inventory,
              let rack = inventory.racks.first(where: { $0.name == rackName }) else {
            return nil
        }

        let devicesInRack = getDevices(inRack: rackName)
        var summary = "RACK: \(rackName)\n"
        summary += "- Site: \(rack.site.display ?? "Unknown")\n"
        summary += "- U-Height: \(rack.uHeight)U\n"
        summary += "- Role: \(rack.role?.display ?? "General")\n"
        summary += "- Devices: \(devicesInRack.count)\n"

        let criticalInRack = devicesInRack.filter { $0.healthStatus?.overallHealth == .critical }.count
        let degradedInRack = devicesInRack.filter { $0.healthStatus?.overallHealth == .degraded }.count

        if criticalInRack > 0 || degradedInRack > 0 {
            summary += "- Health: \(criticalInRack) critical, \(degradedInRack) degraded\n"
        } else {
            summary += "- Health: All systems operational\n"
        }

        if !devicesInRack.isEmpty {
            summary += "- Equipment:\n"
            for device in devicesInRack.prefix(10) {
                let health = device.healthStatus?.overallHealth.rawValue ?? "Unknown"
                summary += "  • \(device.name) (U\(Int(device.position ?? 0))) [\(health)]\n"
            }
        }

        return summary
    }

    func getSiteSummary(siteName: String) -> String? {
        guard let inventory = inventory,
              let site = inventory.sites.first(where: { $0.name.contains(siteName) || $0.slug.contains(siteName) }) else {
            return nil
        }

        let devicesInSite = getDevices(bySite: site.name)
        let racksInSite = inventory.racks.filter { $0.site.display?.contains(site.name) ?? false }

        var summary = "SITE: \(site.name)\n"
        summary += "- Location: \(site.physicalAddress ?? "N/A")\n"
        summary += "- Facility: \(site.facility ?? "N/A")\n"
        summary += "- Timezone: \(site.timeZone ?? "N/A")\n"
        summary += "- Racks: \(racksInSite.count)\n"
        summary += "- Total Devices: \(devicesInSite.count)\n"

        let critical = devicesInSite.filter { $0.healthStatus?.overallHealth == .critical }.count
        let degraded = devicesInSite.filter { $0.healthStatus?.overallHealth == .degraded }.count
        let offline = devicesInSite.filter { $0.healthStatus?.overallHealth == .offline }.count

        if critical > 0 || degraded > 0 || offline > 0 {
            summary += "- Health Issues: \(critical) critical, \(degraded) degraded, \(offline) offline\n"
        } else {
            summary += "- Health: All systems operational\n"
        }

        return summary
    }

    func getOverallSummary() -> String {
        guard let inventory = inventory else {
            return "No datacenter inventory data available"
        }

        var summary = "DATACENTER OVERVIEW\n"
        summary += "="
        summary += String(repeating: "=", count: 50)
        summary += "\n"
        summary += "Sites: \(inventory.sites.count) | "
        summary += "Racks: \(inventory.racks.count) | "
        summary += "Devices: \(inventory.totalDevices)\n\n"

        summary += "HEALTH STATUS\n"
        summary += "-" + String(repeating: "-", count: 50) + "\n"
        summary += "Healthy: \(inventory.healthyDevices) | "
        summary += "Degraded: \(inventory.degradedDevices) | "
        summary += "Critical: \(inventory.criticalDevices) | "
        summary += "Offline: \(inventory.offlineDevices)\n\n"

        summary += "SITES\n"
        summary += "-" + String(repeating: "-", count: 50) + "\n"
        for site in inventory.sites {
            let devicesInSite = getDevices(bySite: site.name)
            summary += "• \(site.name): \(devicesInSite.count) devices\n"
        }

        if inventory.criticalDevices > 0 || inventory.degradedDevices > 0 {
            summary += "\nISSUES REQUIRING ATTENTION\n"
            summary += "-" + String(repeating: "-", count: 50) + "\n"

            let problemDevices = inventory.devices.filter { device in
                device.healthStatus?.hasIssues == true || device.healthStatus?.overallHealth == .offline
            }

            for device in problemDevices.prefix(10) {
                summary += "• \(device.name) - \(device.healthStatus?.overallHealth.rawValue ?? "Unknown")\n"
                if let critical = device.healthStatus?.criticalIssues, !critical.isEmpty {
                    for issue in critical.prefix(2) {
                        summary += "  ⚠️ \(issue.message)\n"
                    }
                }
            }
        }

        summary += "\nLast Updated: \(inventory.lastUpdated.formatted())\n"

        return summary
    }
}
