import Foundation

// MARK: - NetBox Core Models

/// Represents a datacenter site in NetBox
struct NetBoxSite: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let status: String
    let region: String?
    let facility: String?
    let asn: Int?
    let timeZone: String?
    let description: String?
    let physicalAddress: String?
    let comments: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, status, region, facility, asn, description, comments
        case timeZone = "time_zone"
        case physicalAddress = "physical_address"
    }
}

/// Represents a rack in NetBox
struct NetBoxRack: Codable, Identifiable {
    let id: Int
    let name: String
    let site: NetBoxReference
    let status: String
    let role: NetBoxReference?
    let uHeight: Int
    let descUnits: Bool
    let outerWidth: Int?
    let outerDepth: Int?
    let outerUnit: String?
    let comments: String?
    let deviceCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, site, status, role, comments
        case uHeight = "u_height"
        case descUnits = "desc_units"
        case outerWidth = "outer_width"
        case outerDepth = "outer_depth"
        case outerUnit = "outer_unit"
        case deviceCount = "device_count"
    }
}

/// Represents a device (server, switch, etc.) in NetBox
struct NetBoxDevice: Codable, Identifiable {
    let id: Int
    let name: String
    let deviceType: NetBoxReference
    let deviceRole: NetBoxReference
    let site: NetBoxReference
    let rack: NetBoxReference?
    let position: Double?
    let face: String?
    let status: String
    let primaryIP: NetBoxReference?
    let serialNumber: String?
    let assetTag: String?
    let comments: String?
    let platform: NetBoxReference?

    enum CodingKeys: String, CodingKey {
        case id, name, site, rack, position, face, status, comments, platform
        case deviceType = "device_type"
        case deviceRole = "device_role"
        case primaryIP = "primary_ip"
        case serialNumber = "serial"
        case assetTag = "asset_tag"
    }
}

/// Represents a cable connection in NetBox
struct NetBoxCable: Codable, Identifiable {
    let id: Int
    let type: String
    let status: String
    let label: String?
    let color: String?
    let length: Double?
    let lengthUnit: String?
    let terminationAType: String?
    let terminationA: NetBoxReference?
    let terminationBType: String?
    let terminationB: NetBoxReference?

    enum CodingKeys: String, CodingKey {
        case id, type, status, label, color, length
        case lengthUnit = "length_unit"
        case terminationAType = "termination_a_type"
        case terminationA = "termination_a"
        case terminationBType = "termination_b_type"
        case terminationB = "termination_b"
    }
}

/// Represents an IP address assignment in NetBox
struct NetBoxIPAddress: Codable, Identifiable {
    let id: Int
    let address: String
    let status: String
    let dnsName: String?
    let description: String?
    let assignedObject: NetBoxReference?
    let assignedObjectType: String?

    enum CodingKeys: String, CodingKey {
        case id, address, status, description
        case dnsName = "dns_name"
        case assignedObject = "assigned_object"
        case assignedObjectType = "assigned_object_type"
    }
}

// MARK: - Response Wrappers

/// Standard NetBox API list response wrapper
struct NetBoxListResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}
