import Foundation

// MARK: - NetBox Reference Types

/// Generic reference to another NetBox object (used in API responses)
struct NetBoxReference: Codable {
    let id: Int
    let url: String?
    let display: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id, url, display, name
    }
}

/// Device type reference with manufacturer info
struct NetBoxDeviceTypeReference: Codable {
    let id: Int
    let manufacturer: NetBoxReference
    let model: String
    let slug: String
    let display: String?
}
