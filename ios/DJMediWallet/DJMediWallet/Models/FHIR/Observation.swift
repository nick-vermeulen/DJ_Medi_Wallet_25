//
//  Observation.swift
//  DJMediWallet
//
//  FHIR Observation resource model
//

import Foundation

/// FHIR Observation resource for vital signs and lab results
public struct Observation: Codable {
    public let resourceType: String
    public let id: String?
    public let status: String
    public let category: [CodeableConcept]?
    public let code: CodeableConcept
    public let subject: Reference?
    public let effectiveDateTime: String?
    public let issued: String?
    public let valueQuantity: Quantity?
    public let valueString: String?
    public let valueBoolean: Bool?
    public let component: [ObservationComponent]?
    public let interpretation: [CodeableConcept]?
    public let note: [Annotation]?
    
    public init(
        id: String? = nil,
        status: String,
        category: [CodeableConcept]? = nil,
        code: CodeableConcept,
        subject: Reference? = nil,
        effectiveDateTime: String? = nil,
        issued: String? = nil,
        valueQuantity: Quantity? = nil,
        valueString: String? = nil,
        valueBoolean: Bool? = nil,
        component: [ObservationComponent]? = nil,
        interpretation: [CodeableConcept]? = nil,
        note: [Annotation]? = nil
    ) {
        self.resourceType = "Observation"
        self.id = id
        self.status = status
        self.category = category
        self.code = code
        self.subject = subject
        self.effectiveDateTime = effectiveDateTime
        self.issued = issued
        self.valueQuantity = valueQuantity
        self.valueString = valueString
        self.valueBoolean = valueBoolean
        self.component = component
        self.interpretation = interpretation
        self.note = note
    }
}

/// FHIR Observation Component (for multi-value observations)
public struct ObservationComponent: Codable {
    public let code: CodeableConcept
    public let valueQuantity: Quantity?
    public let valueString: String?
    public let valueBoolean: Bool?
    
    public init(
        code: CodeableConcept,
        valueQuantity: Quantity? = nil,
        valueString: String? = nil,
        valueBoolean: Bool? = nil
    ) {
        self.code = code
        self.valueQuantity = valueQuantity
        self.valueString = valueString
        self.valueBoolean = valueBoolean
    }
}

/// FHIR Quantity
public struct Quantity: Codable {
    public let value: Double?
    public let unit: String?
    public let system: String?
    public let code: String?
    
    public init(value: Double?, unit: String? = nil, system: String? = nil, code: String? = nil) {
        self.value = value
        self.unit = unit
        self.system = system
        self.code = code
    }
    
    public var displayValue: String {
        guard let value = value else { return "" }
        if let unit = unit {
            return "\(value) \(unit)"
        }
        return "\(value)"
    }
}

/// FHIR Reference
public struct Reference: Codable {
    public let reference: String?
    public let display: String?
    public let type: String?
    
    public init(reference: String?, display: String? = nil, type: String? = nil) {
        self.reference = reference
        self.display = display
        self.type = type
    }
}

/// FHIR Annotation
public struct Annotation: Codable {
    public let text: String
    public let authorString: String?
    public let time: String?
    
    public init(text: String, authorString: String? = nil, time: String? = nil) {
        self.text = text
        self.authorString = authorString
        self.time = time
    }
}
