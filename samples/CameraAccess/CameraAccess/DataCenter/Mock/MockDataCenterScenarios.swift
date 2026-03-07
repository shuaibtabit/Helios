import Foundation

// MARK: - Mock DataCenter Scenarios

struct MockDataCenterScenarios {

    // MARK: - Scenario Types

    enum Scenario: CaseIterable {
        case healthy
        case degradedCooling
        case serverDown
        case powerIssue
        case criticalTemperature
        case mixedHealth

        var description: String {
            switch self {
            case .healthy:
                return "All systems operational"
            case .degradedCooling:
                return "Elevated temperatures, cooling warning"
            case .serverDown:
                return "Critical server powered off"
            case .powerIssue:
                return "Power supply failure detected"
            case .criticalTemperature:
                return "CPU temperature critical"
            case .mixedHealth:
                return "Multiple issues across datacenter"
            }
        }

        var rawString: String {
            switch self {
            case .healthy: return "healthy"
            case .degradedCooling: return "degradedCooling"
            case .serverDown: return "serverDown"
            case .powerIssue: return "powerIssue"
            case .criticalTemperature: return "criticalTemperature"
            case .mixedHealth: return "mixedHealth"
            }
        }

        var displayName: String {
            switch self {
            case .healthy: return "Healthy"
            case .degradedCooling: return "Cooling Issue"
            case .serverDown: return "Server Down"
            case .powerIssue: return "Power Failure"
            case .criticalTemperature: return "Critical Temp"
            case .mixedHealth: return "Mixed Health"
            }
        }

        static func from(_ raw: String) -> Scenario? {
            allCases.first { $0.rawString == raw }
        }
    }

    // MARK: - Generate Scenario

    static func generateInventory(scenario: Scenario = .healthy) -> DataCenterInventory {
        let sites = NetBoxMockGenerator.generateSites()
        let racks = NetBoxMockGenerator.generateRacks()
        let devices = NetBoxMockGenerator.generateDevices()
        let cables = NetBoxMockGenerator.generateCables()
        let ipAddresses = NetBoxMockGenerator.generateIPAddresses()

        // Generate health data based on scenario
        let devicesWithHealth = devices.map { device -> DeviceWithHealth in
            let healthScenario = determineHealthScenario(
                for: device,
                overallScenario: scenario
            )

            guard device.deviceRole.display?.lowercased() == "server" else {
                return DeviceWithHealth(device: device, healthStatus: nil)
            }

            let system = RedfishMockGenerator.generateSystem(
                deviceName: device.name,
                scenario: healthScenario
            )
            let chassis = RedfishMockGenerator.generateChassis(
                deviceName: device.name,
                scenario: healthScenario
            )
            let thermal = RedfishMockGenerator.generateThermalData(
                deviceName: device.name,
                scenario: healthScenario
            )
            let power = RedfishMockGenerator.generatePowerData(
                deviceName: device.name,
                scenario: healthScenario
            )

            let healthStatus = ServerHealthStatus.fromRedfish(
                deviceName: device.name,
                system: system,
                chassis: chassis,
                thermal: thermal,
                power: power
            )

            return DeviceWithHealth(device: device, healthStatus: healthStatus)
        }

        return DataCenterInventory(
            sites: sites,
            racks: racks,
            devices: devicesWithHealth,
            cables: cables,
            ipAddresses: ipAddresses,
            lastUpdated: Date()
        )
    }

    // MARK: - Scenario Mapping

    private static func determineHealthScenario(
        for device: NetBoxDevice,
        overallScenario: Scenario
    ) -> RedfishMockGenerator.HealthScenario {
        switch overallScenario {
        case .healthy:
            return .healthy

        case .degradedCooling:
            if device.name.contains("srv-001") {
                return .degradedCooling
            }
            return .healthy

        case .serverDown:
            if device.name == "ash01-srv-001" {
                return .offline
            }
            return .healthy

        case .powerIssue:
            if device.name == "ash01-srv-002" {
                return .powerSupplyFailure
            }
            return .healthy

        case .criticalTemperature:
            if device.name == "ash01-srv-001" {
                return .criticalTemperature
            }
            return .healthy

        case .mixedHealth:
            if device.name == "ash01-srv-001" {
                return .criticalTemperature
            } else if device.name == "ash01-srv-002" {
                return .powerSupplyFailure
            } else if device.name == "pdx01-srv-001" {
                return .degradedCooling
            } else if device.name == "fra01-srv-001" {
                return .offline
            }
            return .healthy
        }
    }

    // MARK: - Scenario Summaries

    static func generateSummary(for scenario: Scenario) -> String {
        let inventory = generateInventory(scenario: scenario)
        var summary = "DATACENTER SCENARIO: \(scenario.description)\n\n"

        summary += "Total Devices: \(inventory.totalDevices)\n"
        summary += "Healthy: \(inventory.healthyDevices) | "
        summary += "Degraded: \(inventory.degradedDevices) | "
        summary += "Critical: \(inventory.criticalDevices) | "
        summary += "Offline: \(inventory.offlineDevices)\n\n"

        let devicesWithIssues = inventory.devices.filter { device in
            device.healthStatus?.hasIssues == true || device.healthStatus?.overallHealth == .offline
        }

        if !devicesWithIssues.isEmpty {
            summary += "DEVICES WITH ISSUES:\n"
            for device in devicesWithIssues {
                summary += "• \(device.name) [\(device.healthStatus?.overallHealth.rawValue ?? "Unknown")]\n"

                if let critical = device.healthStatus?.criticalIssues, !critical.isEmpty {
                    for issue in critical {
                        summary += "  - CRITICAL: \(issue.message)\n"
                    }
                }

                if let warnings = device.healthStatus?.warnings, !warnings.isEmpty {
                    for issue in warnings {
                        summary += "  - WARNING: \(issue.message)\n"
                    }
                }
            }
        }

        return summary
    }

    // MARK: - Quick Test

    static func testAllScenarios() {
        print("=" * 80)
        print("MOCK DATACENTER SCENARIOS TEST")
        print("=" * 80)

        for scenario in [
            Scenario.healthy,
            .degradedCooling,
            .serverDown,
            .powerIssue,
            .criticalTemperature,
            .mixedHealth
        ] {
            print(generateSummary(for: scenario))
            print("-" * 80)
        }
    }
}

// MARK: - String Repetition Helper

private extension String {
    static func * (string: String, count: Int) -> String {
        String(repeating: string, count: count)
    }
}
