//
//  Patient.swift
//  DJMediWallet
//
//  FHIR Patient resource model
//

import Foundation

/// FHIR Patient resource
public struct Patient: Codable {
    public let resourceType: String
    public let id: String?
    public let identifier: [Identifier]?
    public let active: Bool?
    public let name: [HumanName]?
    public let telecom: [ContactPoint]?
    public let gender: String?
    public let birthDate: String?
    public let address: [Address]?
    public let contact: [PatientContact]?
    
    public init(
        id: String? = nil,
        identifier: [Identifier]? = nil,
        active: Bool? = true,
        name: [HumanName]? = nil,
        telecom: [ContactPoint]? = nil,
        gender: String? = nil,
        birthDate: String? = nil,
        address: [Address]? = nil,
        contact: [PatientContact]? = nil
    ) {
        self.resourceType = "Patient"
        self.id = id
        self.identifier = identifier
        self.active = active
        self.name = name
        self.telecom = telecom
        self.gender = gender
        self.birthDate = birthDate
        self.address = address
        self.contact = contact
    }
}

/// FHIR Identifier
public struct Identifier: Codable {
    public let system: String?
    public let value: String?
    public let use: String?
    public let type: CodeableConcept?
    
    public init(system: String?, value: String?, use: String? = nil, type: CodeableConcept? = nil) {
        self.system = system
        self.value = value
        self.use = use
        self.type = type
    }
}

/// FHIR HumanName
public struct HumanName: Codable {
    public let use: String?
    public let family: String?
    public let given: [String]?
    public let prefix: [String]?
    public let suffix: [String]?
    
    public init(use: String? = nil, family: String?, given: [String]?, prefix: [String]? = nil, suffix: [String]? = nil) {
        self.use = use
        self.family = family
        self.given = given
        self.prefix = prefix
        self.suffix = suffix
    }
    
    public var fullName: String {
        var parts: [String] = []
        if let prefix = prefix {
            parts.append(contentsOf: prefix)
        }
        if let given = given {
            parts.append(contentsOf: given)
        }
        if let family = family {
            parts.append(family)
        }
        if let suffix = suffix {
            parts.append(contentsOf: suffix)
        }
        return parts.joined(separator: " ")
    }
}

/// FHIR ContactPoint
public struct ContactPoint: Codable {
    public let system: String?
    public let value: String?
    public let use: String?
    
    public init(system: String?, value: String?, use: String? = nil) {
        self.system = system
        self.value = value
        self.use = use
    }
}

/// FHIR Address
public struct Address: Codable {
    public let use: String?
    public let type: String?
    public let line: [String]?
    public let city: String?
    public let state: String?
    public let postalCode: String?
    public let country: String?
    
    public init(
        use: String? = nil,
        type: String? = nil,
        line: [String]? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        country: String? = nil
    ) {
        self.use = use
        self.type = type
        self.line = line
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
    
    public var fullAddress: String {
        var parts: [String] = []
        if let line = line {
            parts.append(contentsOf: line)
        }
        if let city = city {
            parts.append(city)
        }
        if let state = state {
            parts.append(state)
        }
        if let postalCode = postalCode {
            parts.append(postalCode)
        }
        if let country = country {
            parts.append(country)
        }
        return parts.joined(separator: ", ")
    }
}

/// FHIR Patient Contact
public struct PatientContact: Codable {
    public let relationship: [CodeableConcept]?
    public let name: HumanName?
    public let telecom: [ContactPoint]?
    public let address: Address?
    
    public init(
        relationship: [CodeableConcept]? = nil,
        name: HumanName? = nil,
        telecom: [ContactPoint]? = nil,
        address: Address? = nil
    ) {
        self.relationship = relationship
        self.name = name
        self.telecom = telecom
        self.address = address
    }
}

/// FHIR CodeableConcept
public struct CodeableConcept: Codable {
    public let coding: [Coding]?
    public let text: String?
    
    public init(coding: [Coding]?, text: String? = nil) {
        self.coding = coding
        self.text = text
    }
    
    public var display: String? {
        return text ?? coding?.first?.display
    }
}

/// FHIR Coding
public struct Coding: Codable {
    public let system: String?
    public let code: String?
    public let display: String?
    public let version: String?
    
    public init(system: String?, code: String?, display: String? = nil, version: String? = nil) {
        self.system = system
        self.code = code
        self.display = display
        self.version = version
    }
    
    public var isSNOMED: Bool {
        return system == "http://snomed.info/sct"
    }
}
