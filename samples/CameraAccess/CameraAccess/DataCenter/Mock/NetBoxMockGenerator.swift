import Foundation

// MARK: - NetBox Mock Data Generator - Comprehensive Datacenter

struct NetBoxMockGenerator {

    // MARK: - Sites

    static func generateSites() -> [NetBoxSite] {
        [
            NetBoxSite(
                id: 1,
                name: "Ashburn DC-01",
                slug: "ash01",
                status: "active",
                region: "US-East",
                facility: "Equinix DC2",
                asn: 64512,
                timeZone: "America/New_York",
                description: "Primary East Coast datacenter - 10,000 sq ft",
                physicalAddress: "21715 Filigree Ct, Ashburn, VA 20147",
                comments: "Main production facility. Carrier-neutral. Tier 3."
            ),
            NetBoxSite(
                id: 2,
                name: "Portland DC-01",
                slug: "pdx01",
                status: "active",
                region: "US-West",
                facility: "CoreSite POR1",
                asn: 64513,
                timeZone: "America/Los_Angeles",
                description: "West Coast datacenter - 8,000 sq ft",
                physicalAddress: "1335 NW Northrup St, Portland, OR 97209",
                comments: "Backup and DR site. Green power certified."
            ),
            NetBoxSite(
                id: 3,
                name: "Frankfurt DC-01",
                slug: "fra01",
                status: "active",
                region: "EU-Central",
                facility: "Equinix FR5",
                asn: 64514,
                timeZone: "Europe/Berlin",
                description: "European datacenter - 6,000 sq ft",
                physicalAddress: "Friesstraße 26, 60388 Frankfurt, Germany",
                comments: "EU data residency compliance. GDPR compliant."
            )
        ]
    }

    // MARK: - Racks

    static func generateRacks() -> [NetBoxRack] {
        var racks: [NetBoxRack] = []

        // Ashburn DC-01: 8 racks
        for i in 1...8 {
            let role = i <= 5 ? "Compute" : (i <= 7 ? "Network" : "Storage")
            racks.append(NetBoxRack(
                id: i,
                name: "ASH-R\(String(format: "%02d", i))",
                site: NetBoxReference(id: 1, url: nil, display: "Ashburn DC-01", name: "Ashburn DC-01"),
                status: "active",
                role: NetBoxReference(id: 1, url: nil, display: role, name: role),
                uHeight: 42,
                descUnits: false,
                outerWidth: 19,
                outerDepth: 42,
                outerUnit: "in",
                comments: "Row A, Position \(i)",
                deviceCount: i <= 5 ? 12 : (i <= 7 ? 6 : 8)
            ))
        }

        // Portland DC-01: 4 racks
        for i in 1...4 {
            racks.append(NetBoxRack(
                id: 10 + i,
                name: "PDX-R\(String(format: "%02d", i))",
                site: NetBoxReference(id: 2, url: nil, display: "Portland DC-01", name: "Portland DC-01"),
                status: "active",
                role: NetBoxReference(id: 1, url: nil, display: "Compute", name: "Compute"),
                uHeight: 42,
                descUnits: false,
                outerWidth: 19,
                outerDepth: 42,
                outerUnit: "in",
                comments: "Backup facility",
                deviceCount: 10
            ))
        }

        // Frankfurt DC-01: 3 racks
        for i in 1...3 {
            racks.append(NetBoxRack(
                id: 20 + i,
                name: "FRA-R\(String(format: "%02d", i))",
                site: NetBoxReference(id: 3, url: nil, display: "Frankfurt DC-01", name: "Frankfurt DC-01"),
                status: "active",
                role: NetBoxReference(id: 1, url: nil, display: "Compute", name: "Compute"),
                uHeight: 42,
                descUnits: false,
                outerWidth: 19,
                outerDepth: 42,
                outerUnit: "in",
                comments: "EU region",
                deviceCount: 8
            ))
        }

        return racks
    }

    // MARK: - Devices

    static func generateDevices() -> [NetBoxDevice] {
        var devices: [NetBoxDevice] = []
        var deviceId = 1000
        var ipId = 2000

        // Ashburn DC-01 Compute Racks (R01-R05)
        for rack in 1...5 {
            // 10 servers per compute rack
            for server in 1...10 {
                let serverName = "ash01-srv-\(String(format: "%03d", (rack - 1) * 10 + server))"
                let manufacturer = server % 2 == 0 ? "Dell" : "HPE"
                let model = manufacturer == "Dell" ? "PowerEdge R750" : "ProLiant DL380 Gen11"

                devices.append(NetBoxDevice(
                    id: deviceId,
                    name: serverName,
                    deviceType: NetBoxReference(id: 10 + (server % 3), url: nil, display: "\(manufacturer) \(model)", name: nil),
                    deviceRole: NetBoxReference(id: 1, url: nil, display: "Server", name: "Server"),
                    site: NetBoxReference(id: 1, url: nil, display: "Ashburn DC-01", name: nil),
                    rack: NetBoxReference(id: rack, url: nil, display: "ASH-R\(String(format: "%02d", rack))", name: "ASH-R\(String(format: "%02d", rack))"),
                    position: Double(2 + (server - 1) * 4),
                    face: "front",
                    status: "active",
                    primaryIP: NetBoxReference(id: ipId, url: nil, display: "10.1.\(rack).\(10 + server)/24", name: nil),
                    serialNumber: "\(manufacturer.prefix(3).uppercased())-\(String(format: "%06d", deviceId))",
                    assetTag: "ASH-SRV-\(String(format: "%03d", (rack - 1) * 10 + server))",
                    comments: "Production \(server % 3 == 0 ? "database" : (server % 3 == 1 ? "web" : "app")) server",
                    platform: NetBoxReference(id: 1, url: nil, display: "Linux", name: nil)
                ))
                deviceId += 1
                ipId += 1
            }
        }

        // Ashburn Network Equipment (R06-R07)
        let networkGear = [
            ("TOR Switch 1", "Cisco Nexus 9300", 6, 40),
            ("TOR Switch 2", "Cisco Nexus 9300", 6, 38),
            ("Core Switch 1", "Cisco Nexus 9500", 6, 36),
            ("Edge Router 1", "Cisco ASR 1001-X", 6, 34),
            ("Firewall 1", "Palo Alto PA-5250", 6, 32),
            ("Load Balancer 1", "F5 BIG-IP i10800", 6, 30),
            ("TOR Switch 3", "Arista 7050X", 7, 40),
            ("TOR Switch 4", "Arista 7050X", 7, 38),
            ("Core Switch 2", "Cisco Nexus 9500", 7, 36),
            ("Edge Router 2", "Cisco ASR 1001-X", 7, 34),
        ]

        for (index, gear) in networkGear.enumerated() {
            devices.append(NetBoxDevice(
                id: deviceId,
                name: "ash01-net-\(String(format: "%03d", index + 1))",
                deviceType: NetBoxReference(id: 20 + index, url: nil, display: gear.1, name: nil),
                deviceRole: NetBoxReference(id: 2, url: nil, display: "Network", name: "Network"),
                site: NetBoxReference(id: 1, url: nil, display: "Ashburn DC-01", name: nil),
                rack: NetBoxReference(id: gear.2, url: nil, display: "ASH-R\(String(format: "%02d", gear.2))", name: "ASH-R\(String(format: "%02d", gear.2))"),
                position: Double(gear.3),
                face: "front",
                status: "active",
                primaryIP: NetBoxReference(id: ipId, url: nil, display: "10.1.0.\(10 + index)/24", name: nil),
                serialNumber: "NET-\(String(format: "%06d", deviceId))",
                assetTag: "ASH-NET-\(String(format: "%03d", index + 1))",
                comments: gear.0,
                platform: NetBoxReference(id: 2, url: nil, display: gear.1.contains("Cisco") ? "Cisco IOS-XE" : "EOS", name: nil)
            ))
            deviceId += 1
            ipId += 1
        }

        // Ashburn Storage (R08)
        for storage in 1...6 {
            devices.append(NetBoxDevice(
                id: deviceId,
                name: "ash01-sto-\(String(format: "%03d", storage))",
                deviceType: NetBoxReference(id: 30, url: nil, display: "NetApp AFF A800", name: nil),
                deviceRole: NetBoxReference(id: 3, url: nil, display: "Storage", name: "Storage"),
                site: NetBoxReference(id: 1, url: nil, display: "Ashburn DC-01", name: nil),
                rack: NetBoxReference(id: 8, url: nil, display: "ASH-R08", name: "ASH-R08"),
                position: Double(4 + (storage - 1) * 6),
                face: "front",
                status: "active",
                primaryIP: NetBoxReference(id: ipId, url: nil, display: "10.1.8.\(10 + storage)/24", name: nil),
                serialNumber: "STO-\(String(format: "%06d", deviceId))",
                assetTag: "ASH-STO-\(String(format: "%03d", storage))",
                comments: "Production storage array",
                platform: NetBoxReference(id: 3, url: nil, display: "ONTAP", name: nil)
            ))
            deviceId += 1
            ipId += 1
        }

        // Portland DC-01 servers
        for rack in 1...4 {
            for server in 1...8 {
                let serverName = "pdx01-srv-\(String(format: "%03d", (rack - 1) * 8 + server))"
                devices.append(NetBoxDevice(
                    id: deviceId,
                    name: serverName,
                    deviceType: NetBoxReference(id: 10, url: nil, display: "Dell PowerEdge R750", name: nil),
                    deviceRole: NetBoxReference(id: 1, url: nil, display: "Server", name: "Server"),
                    site: NetBoxReference(id: 2, url: nil, display: "Portland DC-01", name: nil),
                    rack: NetBoxReference(id: 10 + rack, url: nil, display: "PDX-R\(String(format: "%02d", rack))", name: "PDX-R\(String(format: "%02d", rack))"),
                    position: Double(4 + (server - 1) * 4),
                    face: "front",
                    status: "active",
                    primaryIP: NetBoxReference(id: ipId, url: nil, display: "10.2.\(rack).\(10 + server)/24", name: nil),
                    serialNumber: "PDX-\(String(format: "%06d", deviceId))",
                    assetTag: "PDX-SRV-\(String(format: "%03d", (rack - 1) * 8 + server))",
                    comments: "DR/Backup server",
                    platform: NetBoxReference(id: 1, url: nil, display: "Linux", name: nil)
                ))
                deviceId += 1
                ipId += 1
            }
        }

        // Frankfurt DC-01 servers
        for rack in 1...3 {
            for server in 1...6 {
                let serverName = "fra01-srv-\(String(format: "%03d", (rack - 1) * 6 + server))"
                devices.append(NetBoxDevice(
                    id: deviceId,
                    name: serverName,
                    deviceType: NetBoxReference(id: 11, url: nil, display: "HPE ProLiant DL380 Gen11", name: nil),
                    deviceRole: NetBoxReference(id: 1, url: nil, display: "Server", name: "Server"),
                    site: NetBoxReference(id: 3, url: nil, display: "Frankfurt DC-01", name: nil),
                    rack: NetBoxReference(id: 20 + rack, url: nil, display: "FRA-R\(String(format: "%02d", rack))", name: "FRA-R\(String(format: "%02d", rack))"),
                    position: Double(6 + (server - 1) * 4),
                    face: "front",
                    status: "active",
                    primaryIP: NetBoxReference(id: ipId, url: nil, display: "10.3.\(rack).\(10 + server)/24", name: nil),
                    serialNumber: "FRA-\(String(format: "%06d", deviceId))",
                    assetTag: "FRA-SRV-\(String(format: "%03d", (rack - 1) * 6 + server))",
                    comments: "EU production server",
                    platform: NetBoxReference(id: 1, url: nil, display: "Linux", name: nil)
                ))
                deviceId += 1
                ipId += 1
            }
        }

        return devices
    }

    // MARK: - Cables

    static func generateCables() -> [NetBoxCable] {
        var cables: [NetBoxCable] = []
        var cableId = 5000

        let cableTypes = [
            ("cat6", "blue", 3.0),
            ("cat6a", "green", 3.0),
            ("smf", "yellow", 5.0),
            ("dac-passive", "black", 2.0),
            ("mmf", "orange", 5.0)
        ]

        // Generate 100 realistic cables
        for i in 1...100 {
            let cableType = cableTypes[i % cableTypes.count]
            cables.append(NetBoxCable(
                id: cableId,
                type: cableType.0,
                status: "connected",
                label: "CABLE-\(String(format: "%04d", i))",
                color: cableType.1,
                length: cableType.2 + Double(i % 10) * 0.5,
                lengthUnit: "m",
                terminationAType: "dcim.interface",
                terminationA: NetBoxReference(id: 10000 + i, url: nil, display: "Device A Port \(i)", name: nil),
                terminationBType: "dcim.interface",
                terminationB: NetBoxReference(id: 20000 + i, url: nil, display: "Device B Port \(i)", name: nil)
            ))
            cableId += 1
        }

        return cables
    }

    // MARK: - IP Addresses

    static func generateIPAddresses() -> [NetBoxIPAddress] {
        var ips: [NetBoxIPAddress] = []
        var ipId = 8000

        // Generate IPs for all devices
        for site in 1...3 {
            for subnet in 1...10 {
                for host in 10...30 {
                    ips.append(NetBoxIPAddress(
                        id: ipId,
                        address: "10.\(site).\(subnet).\(host)/24",
                        status: "active",
                        dnsName: "device-\(ipId).datacenter.local",
                        description: "Assigned to device interface",
                        assignedObject: NetBoxReference(id: ipId * 10, url: nil, display: "eth0", name: nil),
                        assignedObjectType: "dcim.interface"
                    ))
                    ipId += 1
                }
            }
        }

        return ips
    }
}
