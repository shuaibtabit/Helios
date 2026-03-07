import Foundation

// MARK: - Redfish Mock Data Generator

struct RedfishMockGenerator {

    // MARK: - Health Scenarios

    enum HealthScenario {
        case healthy
        case degradedCooling
        case criticalTemperature
        case fanFailure
        case powerSupplyFailure
        case offline
    }

    // MARK: - System

    static func generateSystem(
        deviceName: String,
        scenario: HealthScenario = .healthy
    ) -> RedfishSystem {
        let powerState: String
        let health: String

        switch scenario {
        case .offline:
            powerState = "Off"
            health = "OK"
        case .criticalTemperature, .fanFailure, .powerSupplyFailure:
            powerState = "On"
            health = "Critical"
        case .degradedCooling:
            powerState = "On"
            health = "Warning"
        case .healthy:
            powerState = "On"
            health = "OK"
        }

        return RedfishSystem(
            id: "System.Embedded.1",
            name: deviceName,
            systemType: "Physical",
            manufacturer: deviceName.contains("Dell") || deviceName.contains("srv") ? "Dell Inc." : "HPE",
            model: deviceName.contains("Dell") || deviceName.contains("srv") ? "PowerEdge R750" : "ProLiant DL380 Gen11",
            serialNumber: generateSerialNumber(deviceName),
            sku: "SKU-\(deviceName.suffix(3))",
            partNumber: "PN-\(deviceName.suffix(3))",
            biosVersion: "2.15.0",
            powerState: powerState,
            status: RedfishStatus(
                state: powerState == "On" ? "Enabled" : "Disabled",
                health: health,
                healthRollup: health
            ),
            processorSummary: ProcessorSummary(
                count: 2,
                model: "Intel(R) Xeon(R) Gold 6338 CPU @ 2.00GHz",
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil)
            ),
            memorySummary: MemorySummary(
                totalSystemMemoryGiB: 256.0,
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil)
            ),
            hostName: "\(deviceName).example.com"
        )
    }

    // MARK: - Chassis

    static func generateChassis(
        deviceName: String,
        scenario: HealthScenario = .healthy
    ) -> RedfishChassis {
        let health: String
        switch scenario {
        case .offline, .healthy:
            health = "OK"
        case .degradedCooling:
            health = "Warning"
        case .criticalTemperature, .fanFailure, .powerSupplyFailure:
            health = "Critical"
        }

        return RedfishChassis(
            id: "Chassis.Embedded.1",
            name: "Computer System Chassis",
            chassisType: "RackMount",
            manufacturer: deviceName.contains("Dell") || deviceName.contains("srv") ? "Dell Inc." : "HPE",
            model: deviceName.contains("Dell") || deviceName.contains("srv") ? "PowerEdge R750" : "ProLiant DL380 Gen11",
            serialNumber: generateSerialNumber(deviceName),
            partNumber: "PN-CHASSIS-\(deviceName.suffix(3))",
            assetTag: "ASSET-\(deviceName.suffix(3))",
            status: RedfishStatus(
                state: "Enabled",
                health: health,
                healthRollup: health
            ),
            indicatorLED: "Off"
        )
    }

    // MARK: - Thermal Data

    static func generateThermalData(
        deviceName: String,
        scenario: HealthScenario = .healthy
    ) -> RedfishThermalData {
        let temperatures = generateTemperatures(scenario: scenario)
        let fans = generateFans(scenario: scenario)

        return RedfishThermalData(
            id: "Thermal",
            name: "Thermal",
            temperatures: temperatures,
            fans: fans
        )
    }

    private static func generateTemperatures(scenario: HealthScenario) -> [RedfishThermalData.Temperature] {
        let cpuTemp: Double
        let inletTemp: Double
        let exhaustTemp: Double

        switch scenario {
        case .offline:
            cpuTemp = 25.0
            inletTemp = 22.0
            exhaustTemp = 24.0
        case .criticalTemperature:
            cpuTemp = 92.0
            inletTemp = 28.0
            exhaustTemp = 88.0
        case .degradedCooling, .fanFailure:
            cpuTemp = 78.0
            inletTemp = 26.0
            exhaustTemp = 74.0
        case .healthy, .powerSupplyFailure:
            cpuTemp = 52.0
            inletTemp = 22.0
            exhaustTemp = 45.0
        }

        return [
            RedfishThermalData.Temperature(
                name: "CPU1 Temp",
                sensorNumber: 1,
                readingCelsius: cpuTemp,
                upperThresholdNonCritical: 70.0,
                upperThresholdCritical: 85.0,
                upperThresholdFatal: 95.0,
                lowerThresholdNonCritical: nil,
                lowerThresholdCritical: nil,
                status: RedfishStatus(
                    state: "Enabled",
                    health: cpuTemp >= 85 ? "Critical" : (cpuTemp >= 70 ? "Warning" : "OK"),
                    healthRollup: nil
                ),
                physicalContext: "CPU"
            ),
            RedfishThermalData.Temperature(
                name: "CPU2 Temp",
                sensorNumber: 2,
                readingCelsius: cpuTemp - 2,
                upperThresholdNonCritical: 70.0,
                upperThresholdCritical: 85.0,
                upperThresholdFatal: 95.0,
                lowerThresholdNonCritical: nil,
                lowerThresholdCritical: nil,
                status: RedfishStatus(
                    state: "Enabled",
                    health: (cpuTemp - 2) >= 85 ? "Critical" : ((cpuTemp - 2) >= 70 ? "Warning" : "OK"),
                    healthRollup: nil
                ),
                physicalContext: "CPU"
            ),
            RedfishThermalData.Temperature(
                name: "Inlet Temp",
                sensorNumber: 3,
                readingCelsius: inletTemp,
                upperThresholdNonCritical: 42.0,
                upperThresholdCritical: 47.0,
                upperThresholdFatal: nil,
                lowerThresholdNonCritical: nil,
                lowerThresholdCritical: nil,
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil),
                physicalContext: "Intake"
            ),
            RedfishThermalData.Temperature(
                name: "Exhaust Temp",
                sensorNumber: 4,
                readingCelsius: exhaustTemp,
                upperThresholdNonCritical: 70.0,
                upperThresholdCritical: 80.0,
                upperThresholdFatal: nil,
                lowerThresholdNonCritical: nil,
                lowerThresholdCritical: nil,
                status: RedfishStatus(
                    state: "Enabled",
                    health: exhaustTemp >= 80 ? "Critical" : (exhaustTemp >= 70 ? "Warning" : "OK"),
                    healthRollup: nil
                ),
                physicalContext: "Exhaust"
            )
        ]
    }

    private static func generateFans(scenario: HealthScenario) -> [RedfishThermalData.Fan] {
        let fanHealth: String
        let fan1RPM: Int
        let fan2RPM: Int

        switch scenario {
        case .offline:
            fanHealth = "OK"
            fan1RPM = 0
            fan2RPM = 0
        case .fanFailure:
            fanHealth = "Critical"
            fan1RPM = 1200
            fan2RPM = 0
        case .degradedCooling:
            fanHealth = "Warning"
            fan1RPM = 8500
            fan2RPM = 8300
        case .criticalTemperature:
            fanHealth = "OK"
            fan1RPM = 9500
            fan2RPM = 9400
        case .healthy, .powerSupplyFailure:
            fanHealth = "OK"
            fan1RPM = 4200
            fan2RPM = 4150
        }

        return [
            RedfishThermalData.Fan(
                name: "System Fan 1",
                reading: fan1RPM,
                readingUnits: "RPM",
                lowerThresholdNonCritical: 2000,
                lowerThresholdCritical: 1000,
                lowerThresholdFatal: 500,
                status: RedfishStatus(
                    state: fan1RPM > 0 ? "Enabled" : "Absent",
                    health: fanHealth,
                    healthRollup: nil
                ),
                physicalContext: "SystemBoard"
            ),
            RedfishThermalData.Fan(
                name: "System Fan 2",
                reading: fan2RPM,
                readingUnits: "RPM",
                lowerThresholdNonCritical: 2000,
                lowerThresholdCritical: 1000,
                lowerThresholdFatal: 500,
                status: RedfishStatus(
                    state: fan2RPM > 0 ? "Enabled" : "Absent",
                    health: scenario == .fanFailure ? "Critical" : fanHealth,
                    healthRollup: nil
                ),
                physicalContext: "SystemBoard"
            )
        ]
    }

    // MARK: - Power Data

    static func generatePowerData(
        deviceName: String,
        scenario: HealthScenario = .healthy
    ) -> RedfishPowerData {
        let powerSupplies = generatePowerSupplies(scenario: scenario)
        let powerConsumed: Double

        switch scenario {
        case .offline:
            powerConsumed = 0
        case .criticalTemperature:
            powerConsumed = 620
        case .degradedCooling, .fanFailure:
            powerConsumed = 580
        case .healthy, .powerSupplyFailure:
            powerConsumed = 320
        }

        return RedfishPowerData(
            id: "Power",
            name: "Power",
            powerSupplies: powerSupplies,
            voltages: generateVoltages(),
            powerControl: [
                RedfishPowerData.PowerControl(
                    name: "System Power Control",
                    powerConsumedWatts: powerConsumed,
                    powerCapacityWatts: 1400,
                    powerAllocatedWatts: 800,
                    powerAvailableWatts: 1400 - powerConsumed
                )
            ]
        )
    }

    private static func generatePowerSupplies(scenario: HealthScenario) -> [RedfishPowerData.PowerSupply] {
        let psu1Health: String
        let psu2Health: String
        let psu1Output: Double
        let psu2Output: Double

        switch scenario {
        case .offline:
            psu1Health = "OK"
            psu2Health = "OK"
            psu1Output = 0
            psu2Output = 0
        case .powerSupplyFailure:
            psu1Health = "OK"
            psu2Health = "Critical"
            psu1Output = 320
            psu2Output = 0
        case .criticalTemperature:
            psu1Health = "OK"
            psu2Health = "OK"
            psu1Output = 310
            psu2Output = 310
        case .degradedCooling, .fanFailure:
            psu1Health = "OK"
            psu2Health = "OK"
            psu1Output = 290
            psu2Output = 290
        case .healthy:
            psu1Health = "OK"
            psu2Health = "OK"
            psu1Output = 160
            psu2Output = 160
        }

        return [
            RedfishPowerData.PowerSupply(
                name: "PS1",
                manufacturer: "Delta",
                model: "DPS-700AB-1A",
                serialNumber: "PSU-SN-001",
                partNumber: "PSU-PN-001",
                powerSupplyType: "AC",
                lineInputVoltage: 230.0,
                lastPowerOutputWatts: psu1Output,
                powerCapacityWatts: 700,
                status: RedfishStatus(
                    state: psu1Output > 0 ? "Enabled" : "Disabled",
                    health: psu1Health,
                    healthRollup: nil
                )
            ),
            RedfishPowerData.PowerSupply(
                name: "PS2",
                manufacturer: "Delta",
                model: "DPS-700AB-1A",
                serialNumber: "PSU-SN-002",
                partNumber: "PSU-PN-002",
                powerSupplyType: "AC",
                lineInputVoltage: 230.0,
                lastPowerOutputWatts: psu2Output,
                powerCapacityWatts: 700,
                status: RedfishStatus(
                    state: scenario == .powerSupplyFailure ? "Absent" : (psu2Output > 0 ? "Enabled" : "Disabled"),
                    health: psu2Health,
                    healthRollup: nil
                )
            )
        ]
    }

    private static func generateVoltages() -> [RedfishPowerData.Voltage] {
        [
            RedfishPowerData.Voltage(
                name: "12V",
                sensorNumber: 1,
                readingVolts: 12.1,
                upperThresholdNonCritical: 12.6,
                upperThresholdCritical: 13.2,
                lowerThresholdNonCritical: 11.4,
                lowerThresholdCritical: 10.8,
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil)
            ),
            RedfishPowerData.Voltage(
                name: "5V",
                sensorNumber: 2,
                readingVolts: 5.02,
                upperThresholdNonCritical: 5.25,
                upperThresholdCritical: 5.5,
                lowerThresholdNonCritical: 4.75,
                lowerThresholdCritical: 4.5,
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil)
            ),
            RedfishPowerData.Voltage(
                name: "3.3V",
                sensorNumber: 3,
                readingVolts: 3.31,
                upperThresholdNonCritical: 3.47,
                upperThresholdCritical: 3.63,
                lowerThresholdNonCritical: 3.14,
                lowerThresholdCritical: 2.97,
                status: RedfishStatus(state: "Enabled", health: "OK", healthRollup: nil)
            )
        ]
    }

    // MARK: - Helpers

    private static func generateSerialNumber(_ deviceName: String) -> String {
        let suffix = deviceName.suffix(3)
        return "SN-\(suffix)-\(String(format: "%06d", Int.random(in: 100000...999999)))"
    }
}
