import Foundation

// MARK: - Redfish Core Models

/// Redfish System resource (ComputerSystem)
struct RedfishSystem: Codable {
    let id: String
    let name: String
    let systemType: String?
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let sku: String?
    let partNumber: String?
    let biosVersion: String?
    let powerState: String
    let status: RedfishStatus
    let processorSummary: ProcessorSummary?
    let memorySummary: MemorySummary?
    let hostName: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case systemType = "SystemType"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case serialNumber = "SerialNumber"
        case sku = "SKU"
        case partNumber = "PartNumber"
        case biosVersion = "BiosVersion"
        case powerState = "PowerState"
        case status = "Status"
        case processorSummary = "ProcessorSummary"
        case memorySummary = "MemorySummary"
        case hostName = "HostName"
    }
}

/// Redfish Chassis resource
struct RedfishChassis: Codable {
    let id: String
    let name: String
    let chassisType: String?
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let partNumber: String?
    let assetTag: String?
    let status: RedfishStatus
    let indicatorLED: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case chassisType = "ChassisType"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case serialNumber = "SerialNumber"
        case partNumber = "PartNumber"
        case assetTag = "AssetTag"
        case status = "Status"
        case indicatorLED = "IndicatorLED"
    }
}

/// Redfish Status object
struct RedfishStatus: Codable {
    let state: String?
    let health: String?
    let healthRollup: String?

    enum CodingKeys: String, CodingKey {
        case state = "State"
        case health = "Health"
        case healthRollup = "HealthRollup"
    }
}

/// Processor summary information
struct ProcessorSummary: Codable {
    let count: Int?
    let model: String?
    let status: RedfishStatus?

    enum CodingKeys: String, CodingKey {
        case count = "Count"
        case model = "Model"
        case status = "Status"
    }
}

/// Memory summary information
struct MemorySummary: Codable {
    let totalSystemMemoryGiB: Double?
    let status: RedfishStatus?

    enum CodingKeys: String, CodingKey {
        case totalSystemMemoryGiB = "TotalSystemMemoryGiB"
        case status = "Status"
    }
}

// MARK: - Health Status Enums

enum RedfishHealthStatus: String, Codable {
    case ok = "OK"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = RedfishHealthStatus(rawValue: value) ?? .unknown
    }
}

enum RedfishPowerState: String, Codable {
    case on = "On"
    case off = "Off"
    case poweringOn = "PoweringOn"
    case poweringOff = "PoweringOff"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = RedfishPowerState(rawValue: value) ?? .unknown
    }
}
