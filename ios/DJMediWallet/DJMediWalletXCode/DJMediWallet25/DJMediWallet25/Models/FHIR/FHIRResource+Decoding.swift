import Foundation

enum FHIRResourceDecodingError: LocalizedError {
    case missingData
    case unsupportedResourceType(expected: String)
    case invalidJSONPayload

    var errorDescription: String? {
        switch self {
        case .missingData:
            return "The credential does not contain any FHIR data to display."
        case .unsupportedResourceType(let expected):
            return "Expected a \(expected) resource but received a different type."
        case .invalidJSONPayload:
            return "The FHIR payload could not be decoded into JSON."
        }
    }
}

extension FHIRResource {
    func decodeObservation() throws -> FHIRObservation {
        guard resourceType == "Observation" else {
            throw FHIRResourceDecodingError.unsupportedResourceType(expected: "Observation")
        }
        guard var payload = data else {
            throw FHIRResourceDecodingError.missingData
        }
        payload["resourceType"] = resourceType
        if let id = id {
            payload["id"] = id
        }
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw FHIRResourceDecodingError.invalidJSONPayload
        }
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()
    return try decoder.decode(FHIRObservation.self, from: jsonData)
    }

    func makeObservationBundle(fallbackIdentifier: String) throws -> FHIRBundle {
        let observation = try decodeObservation()
        let referenceId = observation.id ?? fallbackIdentifier
        let entry = BundleEntry(fullUrl: "urn:uuid:\(referenceId)", resource: .observation(observation))
        return FHIRBundle(entry: [entry])
    }

    func decodeCondition() throws -> Condition {
        guard resourceType == "Condition" else {
            throw FHIRResourceDecodingError.unsupportedResourceType(expected: "Condition")
        }
        guard var payload = data else {
            throw FHIRResourceDecodingError.missingData
        }
        payload["resourceType"] = resourceType
        if let id = id {
            payload["id"] = id
        }
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw FHIRResourceDecodingError.invalidJSONPayload
        }
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(Condition.self, from: jsonData)
    }

    func makeConditionBundle(fallbackIdentifier: String) throws -> FHIRBundle {
        let condition = try decodeCondition()
        let referenceId = condition.id ?? fallbackIdentifier
        let entry = BundleEntry(fullUrl: "urn:uuid:\(referenceId)", resource: .condition(condition))
        return FHIRBundle(entry: [entry])
    }

    func decodeMedicationStatement() throws -> MedicationStatement {
        guard resourceType == "MedicationStatement" else {
            throw FHIRResourceDecodingError.unsupportedResourceType(expected: "MedicationStatement")
        }
        guard var payload = data else {
            throw FHIRResourceDecodingError.missingData
        }
        payload["resourceType"] = resourceType
        if let id = id {
            payload["id"] = id
        }
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw FHIRResourceDecodingError.invalidJSONPayload
        }
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(MedicationStatement.self, from: jsonData)
    }

    func makeMedicationStatementBundle(fallbackIdentifier: String) throws -> FHIRBundle {
        let medication = try decodeMedicationStatement()
        let referenceId = medication.id ?? fallbackIdentifier
        let entry = BundleEntry(fullUrl: "urn:uuid:\(referenceId)", resource: .medicationStatement(medication))
        return FHIRBundle(entry: [entry])
    }
}
