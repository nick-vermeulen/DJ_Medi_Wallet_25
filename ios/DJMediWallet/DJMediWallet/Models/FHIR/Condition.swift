//
//  Condition.swift
//  DJMediWallet
//
//  FHIR Condition resource model
//

import Foundation

/// FHIR Condition resource for diagnoses and health concerns
public struct Condition: Codable {
    public let resourceType: String
    public let id: String?
    public let clinicalStatus: CodeableConcept?
    public let verificationStatus: CodeableConcept?
    public let category: [CodeableConcept]?
    public let severity: CodeableConcept?
    public let code: CodeableConcept
    public let subject: Reference
    public let onsetDateTime: String?
    public let recordedDate: String?
    public let note: [Annotation]?
    
    public init(
        id: String? = nil,
        clinicalStatus: CodeableConcept? = nil,
        verificationStatus: CodeableConcept? = nil,
        category: [CodeableConcept]? = nil,
        severity: CodeableConcept? = nil,
        code: CodeableConcept,
        subject: Reference,
        onsetDateTime: String? = nil,
        recordedDate: String? = nil,
        note: [Annotation]? = nil
    ) {
        self.resourceType = "Condition"
        self.id = id
        self.clinicalStatus = clinicalStatus
        self.verificationStatus = verificationStatus
        self.category = category
        self.severity = severity
        self.code = code
        self.subject = subject
        self.onsetDateTime = onsetDateTime
        self.recordedDate = recordedDate
        self.note = note
    }
}
