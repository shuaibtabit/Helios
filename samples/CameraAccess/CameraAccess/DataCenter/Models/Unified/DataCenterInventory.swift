import Foundation

// MARK: - Unified DataCenter Models

/// Complete datacenter inventory combining NetBox infrastructure and Redfish health
struct DataCenterInventory {
    let sites: [NetBoxSite]
    let racks: [NetBoxRack]
    let devices: [DeviceWithHealth]
    let cables: [NetBoxCable]
    let ipAddresses: [NetBoxIPAddress]
    let lastUpdated: Date

    var totalDevices: Int { devices.count }
    var healthyDevices: Int {
        devices.filter { $0.healthStatus?.overallHealth == .healthy }.count
    }
    var degradedDevices: Int {
        devices.filter { $0.healthStatus?.overallHealth == .degraded }.count
    }
    var criticalDevices: Int {
        devices.filter { $0.healthStatus?.overallHealth == .critical }.count
    }
    var offlineDevices: Int {
        devices.filter { $0.healthStatus?.overallHealth == .offline }.count
    }
}

/// NetBox device enriched with Redfish health data
struct DeviceWithHealth {
    let device: NetBoxDevice
    let healthStatus: ServerHealthStatus?

    var id: Int { device.id }
    var name: String { device.name }
    var role: String { device.deviceRole.display ?? device.deviceRole.name ?? "Unknown" }
    var rackName: String? { device.rack?.display ?? device.rack?.name }
    var position: Double? { device.position }
    var primaryIP: String? { device.primaryIP?.display }

    var hasCriticalIssues: Bool {
        healthStatus?.criticalIssues.isEmpty == false
    }

    var hasWarnings: Bool {
        healthStatus?.warnings.isEmpty == false
    }
}

/// Aggregated server health status from Redfish
struct ServerHealthStatus {
    let deviceName: String
    let powerState: String
    let overallHealth: HealthLevel
    let criticalIssues: [HealthIssue]
    let warnings: [HealthIssue]
    let systemInfo: SystemInfo?
    let thermalInfo: ThermalInfo?
    let powerInfo: PowerInfo?
    let lastChecked: Date

    struct SystemInfo {
        let manufacturer: String?
        let model: String?
        let serialNumber: String?
        let biosVersion: String?
        let processorCount: Int?
        let processorModel: String?
        let totalMemoryGiB: Double?
    }

    struct ThermalInfo {
        let temperatures: [TemperatureReading]
        let fans: [FanReading]

        struct TemperatureReading {
            let name: String
            let currentCelsius: Double
            let criticalThreshold: Double?
            let warningThreshold: Double?
            let context: String?
        }

        struct FanReading {
            let name: String
            let currentRPM: Int
            let criticalThresholdRPM: Int?
            let context: String?
        }
    }

    struct PowerInfo {
        let powerSupplies: [PowerSupplyStatus]
        let totalPowerWatts: Double?
        let powerCapacityWatts: Double?

        struct PowerSupplyStatus {
            let name: String
            let model: String?
            let outputWatts: Double?
            let capacityWatts: Double?
            let health: String?
        }
    }

    var hasIssues: Bool {
        !criticalIssues.isEmpty || !warnings.isEmpty
    }
}

/// Individual health issue
struct HealthIssue {
    let category: IssueCategory
    let severity: IssueSeverity
    let component: String
    let message: String
    let details: String?

    enum IssueCategory: String {
        case thermal = "Thermal"
        case power = "Power"
        case hardware = "Hardware"
        case connectivity = "Connectivity"
        case performance = "Performance"
    }

    enum IssueSeverity: String {
        case critical = "Critical"
        case warning = "Warning"
        case info = "Info"
    }
}

/// Overall health level
enum HealthLevel: String {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case critical = "Critical"
    case offline = "Offline"
    case unknown = "Unknown"

    var color: String {
        switch self {
        case .healthy: return "green"
        case .degraded: return "yellow"
        case .critical: return "red"
        case .offline: return "gray"
        case .unknown: return "blue"
        }
    }
}

// MARK: - Helper Extensions

extension ServerHealthStatus {
    /// Determine overall health from Redfish data
    static func fromRedfish(
        deviceName: String,
        system: RedfishSystem?,
        chassis: RedfishChassis?,
        thermal: RedfishThermalData?,
        power: RedfishPowerData?
    ) -> ServerHealthStatus {
        var criticalIssues: [HealthIssue] = []
        var warnings: [HealthIssue] = []

        // Check power state
        let powerState = system?.powerState ?? "Unknown"
        var overallHealth: HealthLevel = .unknown

        if powerState.lowercased() == "off" {
            overallHealth = .offline
        } else {
            // Analyze thermal data
            if let temps = thermal?.temperatures {
                for temp in temps {
                    guard let reading = temp.readingCelsius else { continue }
                    let name = temp.name ?? "Unknown Sensor"

                    if let critical = temp.upperThresholdCritical, reading >= critical {
                        criticalIssues.append(HealthIssue(
                            category: .thermal,
                            severity: .critical,
                            component: name,
                            message: "Temperature critical (\(Int(reading))°C)",
                            details: "Current: \(Int(reading))°C, Critical threshold: \(Int(critical))°C"
                        ))
                    } else if let warning = temp.upperThresholdNonCritical, reading >= warning {
                        warnings.append(HealthIssue(
                            category: .thermal,
                            severity: .warning,
                            component: name,
                            message: "Temperature elevated (\(Int(reading))°C)",
                            details: "Current: \(Int(reading))°C, Warning threshold: \(Int(warning))°C"
                        ))
                    }
                }
            }

            // Analyze fan data
            if let fans = thermal?.fans {
                for fan in fans {
                    let name = fan.name ?? "Unknown Fan"
                    if let health = fan.status?.health, health.lowercased() != "ok" {
                        criticalIssues.append(HealthIssue(
                            category: .thermal,
                            severity: .critical,
                            component: name,
                            message: "Fan failure or degraded",
                            details: "Fan status: \(health)"
                        ))
                    }
                }
            }

            // Analyze power supplies
            if let psus = power?.powerSupplies {
                for psu in psus {
                    let name = psu.name ?? "Unknown PSU"
                    if let health = psu.status?.health, health.lowercased() != "ok" {
                        criticalIssues.append(HealthIssue(
                            category: .power,
                            severity: .critical,
                            component: name,
                            message: "Power supply failure",
                            details: "PSU status: \(health)"
                        ))
                    }
                }
            }

            // Determine overall health
            if !criticalIssues.isEmpty {
                overallHealth = .critical
            } else if !warnings.isEmpty {
                overallHealth = .degraded
            } else if powerState.lowercased() == "on" {
                overallHealth = .healthy
            }
        }

        // Build system info
        let systemInfo = system.map { sys in
            SystemInfo(
                manufacturer: sys.manufacturer,
                model: sys.model,
                serialNumber: sys.serialNumber,
                biosVersion: sys.biosVersion,
                processorCount: sys.processorSummary?.count,
                processorModel: sys.processorSummary?.model,
                totalMemoryGiB: sys.memorySummary?.totalSystemMemoryGiB
            )
        }

        // Build thermal info
        let thermalInfo = thermal.map { therm in
            ThermalInfo(
                temperatures: therm.temperatures?.compactMap { temp in
                    guard let reading = temp.readingCelsius else { return nil }
                    return ThermalInfo.TemperatureReading(
                        name: temp.name ?? "Unknown",
                        currentCelsius: reading,
                        criticalThreshold: temp.upperThresholdCritical,
                        warningThreshold: temp.upperThresholdNonCritical,
                        context: temp.physicalContext
                    )
                } ?? [],
                fans: therm.fans?.compactMap { fan in
                    guard let reading = fan.reading else { return nil }
                    return ThermalInfo.FanReading(
                        name: fan.name ?? "Unknown",
                        currentRPM: reading,
                        criticalThresholdRPM: fan.lowerThresholdCritical,
                        context: fan.physicalContext
                    )
                } ?? []
            )
        }

        // Build power info
        let powerInfo = power.map { pwr in
            PowerInfo(
                powerSupplies: pwr.powerSupplies?.compactMap { psu in
                    PowerInfo.PowerSupplyStatus(
                        name: psu.name ?? "Unknown",
                        model: psu.model,
                        outputWatts: psu.lastPowerOutputWatts,
                        capacityWatts: psu.powerCapacityWatts,
                        health: psu.status?.health
                    )
                } ?? [],
                totalPowerWatts: pwr.powerControl?.first?.powerConsumedWatts,
                powerCapacityWatts: pwr.powerControl?.first?.powerCapacityWatts
            )
        }

        return ServerHealthStatus(
            deviceName: deviceName,
            powerState: powerState,
            overallHealth: overallHealth,
            criticalIssues: criticalIssues,
            warnings: warnings,
            systemInfo: systemInfo,
            thermalInfo: thermalInfo,
            powerInfo: powerInfo,
            lastChecked: Date()
        )
    }
}
