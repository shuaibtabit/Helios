import Foundation

// MARK: - Redfish Thermal & Power Models

/// Redfish Thermal data (temperatures and fans)
struct RedfishThermalData: Codable {
    let id: String?
    let name: String?
    let temperatures: [Temperature]?
    let fans: [Fan]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case temperatures = "Temperatures"
        case fans = "Fans"
    }

    struct Temperature: Codable {
        let name: String?
        let sensorNumber: Int?
        let readingCelsius: Double?
        let upperThresholdNonCritical: Double?
        let upperThresholdCritical: Double?
        let upperThresholdFatal: Double?
        let lowerThresholdNonCritical: Double?
        let lowerThresholdCritical: Double?
        let status: RedfishStatus?
        let physicalContext: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case sensorNumber = "SensorNumber"
            case readingCelsius = "ReadingCelsius"
            case upperThresholdNonCritical = "UpperThresholdNonCritical"
            case upperThresholdCritical = "UpperThresholdCritical"
            case upperThresholdFatal = "UpperThresholdFatal"
            case lowerThresholdNonCritical = "LowerThresholdNonCritical"
            case lowerThresholdCritical = "LowerThresholdCritical"
            case status = "Status"
            case physicalContext = "PhysicalContext"
        }
    }

    struct Fan: Codable {
        let name: String?
        let reading: Int?
        let readingUnits: String?
        let lowerThresholdNonCritical: Int?
        let lowerThresholdCritical: Int?
        let lowerThresholdFatal: Int?
        let status: RedfishStatus?
        let physicalContext: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case reading = "Reading"
            case readingUnits = "ReadingUnits"
            case lowerThresholdNonCritical = "LowerThresholdNonCritical"
            case lowerThresholdCritical = "LowerThresholdCritical"
            case lowerThresholdFatal = "LowerThresholdFatal"
            case status = "Status"
            case physicalContext = "PhysicalContext"
        }
    }
}

/// Redfish Power data (power supplies and consumption)
struct RedfishPowerData: Codable {
    let id: String?
    let name: String?
    let powerSupplies: [PowerSupply]?
    let voltages: [Voltage]?
    let powerControl: [PowerControl]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case powerSupplies = "PowerSupplies"
        case voltages = "Voltages"
        case powerControl = "PowerControl"
    }

    struct PowerSupply: Codable {
        let name: String?
        let manufacturer: String?
        let model: String?
        let serialNumber: String?
        let partNumber: String?
        let powerSupplyType: String?
        let lineInputVoltage: Double?
        let lastPowerOutputWatts: Double?
        let powerCapacityWatts: Double?
        let status: RedfishStatus?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case manufacturer = "Manufacturer"
            case model = "Model"
            case serialNumber = "SerialNumber"
            case partNumber = "PartNumber"
            case powerSupplyType = "PowerSupplyType"
            case lineInputVoltage = "LineInputVoltage"
            case lastPowerOutputWatts = "LastPowerOutputWatts"
            case powerCapacityWatts = "PowerCapacityWatts"
            case status = "Status"
        }
    }

    struct Voltage: Codable {
        let name: String?
        let sensorNumber: Int?
        let readingVolts: Double?
        let upperThresholdNonCritical: Double?
        let upperThresholdCritical: Double?
        let lowerThresholdNonCritical: Double?
        let lowerThresholdCritical: Double?
        let status: RedfishStatus?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case sensorNumber = "SensorNumber"
            case readingVolts = "ReadingVolts"
            case upperThresholdNonCritical = "UpperThresholdNonCritical"
            case upperThresholdCritical = "UpperThresholdCritical"
            case lowerThresholdNonCritical = "LowerThresholdNonCritical"
            case lowerThresholdCritical = "LowerThresholdCritical"
            case status = "Status"
        }
    }

    struct PowerControl: Codable {
        let name: String?
        let powerConsumedWatts: Double?
        let powerCapacityWatts: Double?
        let powerAllocatedWatts: Double?
        let powerAvailableWatts: Double?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case powerConsumedWatts = "PowerConsumedWatts"
            case powerCapacityWatts = "PowerCapacityWatts"
            case powerAllocatedWatts = "PowerAllocatedWatts"
            case powerAvailableWatts = "PowerAvailableWatts"
        }
    }
}
