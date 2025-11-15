import Foundation

public struct FHIRBundle: Codable {
    public let resourceType: String
    public let id: String?
    public let type: String
    public let timestamp: String
    public let entry: [BundleEntry]

    public init(id: String? = nil, type: String = "collection", timestamp: Date = Date(), entry: [BundleEntry]) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.resourceType = "Bundle"
        self.id = id
        self.type = type
        self.timestamp = formatter.string(from: timestamp)
        self.entry = entry
    }
}

public struct BundleEntry: Codable {
    public let fullUrl: String?
    public let resource: CodableResource

    public init(fullUrl: String? = nil, resource: CodableResource) {
        self.fullUrl = fullUrl
        self.resource = resource
    }
}

public enum CodableResource: Codable {
    case observation(FHIRObservation)
    case diagnosticReport(DiagnosticReport)
    case condition(Condition)
    case medicationStatement(MedicationStatement)

    private enum CodingKeys: String, CodingKey {
        case resourceType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resourceType = try container.decode(String.self, forKey: .resourceType)
        switch resourceType {
        case "Observation":
            let observation = try FHIRObservation(from: decoder)
            self = .observation(observation)
        case "DiagnosticReport":
            let report = try DiagnosticReport(from: decoder)
            self = .diagnosticReport(report)
        case "Condition":
            let condition = try Condition(from: decoder)
            self = .condition(condition)
        case "MedicationStatement":
            let medication = try MedicationStatement(from: decoder)
            self = .medicationStatement(medication)
        default:
            throw DecodingError.dataCorruptedError(forKey: .resourceType, in: container, debugDescription: "Unsupported resource type \(resourceType)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .observation(let observation):
            try observation.encode(to: encoder)
        case .diagnosticReport(let report):
            try report.encode(to: encoder)
        case .condition(let condition):
            try condition.encode(to: encoder)
        case .medicationStatement(let medication):
            try medication.encode(to: encoder)
        }
    }
}
