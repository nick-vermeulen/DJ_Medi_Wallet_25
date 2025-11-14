//
//  MedicationStatement.swift
//  DJMediWallet
//
//  FHIR MedicationStatement resource model
//

import Foundation

/// FHIR MedicationStatement resource for medication history
public struct MedicationStatement: Codable {
    public let resourceType: String
    public let id: String?
    public let status: String
    public let medicationCodeableConcept: CodeableConcept?
    public let medicationReference: Reference?
    public let subject: Reference
    public let effectiveDateTime: String?
    public let dateAsserted: String?
    public let dosage: [Dosage]?
    public let note: [Annotation]?
    
    public init(
        id: String? = nil,
        status: String,
        medicationCodeableConcept: CodeableConcept? = nil,
        medicationReference: Reference? = nil,
        subject: Reference,
        effectiveDateTime: String? = nil,
        dateAsserted: String? = nil,
        dosage: [Dosage]? = nil,
        note: [Annotation]? = nil
    ) {
        self.resourceType = "MedicationStatement"
        self.id = id
        self.status = status
        self.medicationCodeableConcept = medicationCodeableConcept
        self.medicationReference = medicationReference
        self.subject = subject
        self.effectiveDateTime = effectiveDateTime
        self.dateAsserted = dateAsserted
        self.dosage = dosage
        self.note = note
    }
}

/// FHIR Dosage
public struct Dosage: Codable {
    public let text: String?
    public let timing: Timing?
    public let route: CodeableConcept?
    public let doseAndRate: [DoseAndRate]?
    
    public init(
        text: String? = nil,
        timing: Timing? = nil,
        route: CodeableConcept? = nil,
        doseAndRate: [DoseAndRate]? = nil
    ) {
        self.text = text
        self.timing = timing
        self.route = route
        self.doseAndRate = doseAndRate
    }
}

/// FHIR Timing
public struct Timing: Codable {
    public let `repeat`: TimingRepeat?
    public let code: CodeableConcept?
    
    public init(`repeat`: TimingRepeat? = nil, code: CodeableConcept? = nil) {
        self.`repeat` = `repeat`
        self.code = code
    }
}

/// FHIR TimingRepeat
public struct TimingRepeat: Codable {
    public let frequency: Int?
    public let period: Double?
    public let periodUnit: String?
    
    public init(frequency: Int? = nil, period: Double? = nil, periodUnit: String? = nil) {
        self.frequency = frequency
        self.period = period
        self.periodUnit = periodUnit
    }
}

/// FHIR DoseAndRate
public struct DoseAndRate: Codable {
    public let type: CodeableConcept?
    public let doseQuantity: Quantity?
    
    public init(type: CodeableConcept? = nil, doseQuantity: Quantity? = nil) {
        self.type = type
        self.doseQuantity = doseQuantity
    }
}
