//
//  MedicalCredential.swift
//  DJMediWallet
//
//  Core medical credential model
//

import Foundation

/// Represents a verifiable medical credential
public struct MedicalCredential: Codable, Identifiable {
    public let id: String
    public let type: String
    public let issuer: String
    public let issuanceDate: Date
    public let expirationDate: Date?
    public let fhirResource: FHIRResource?
    public let proof: CredentialProof?
    
    public init(
        id: String,
        type: String,
        issuer: String,
        issuanceDate: Date,
        expirationDate: Date? = nil,
        fhirResource: FHIRResource? = nil,
        proof: CredentialProof? = nil
    ) {
        self.id = id
        self.type = type
        self.issuer = issuer
        self.issuanceDate = issuanceDate
        self.expirationDate = expirationDate
        self.fhirResource = fhirResource
        self.proof = proof
    }
    
    /// Check if credential is expired
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            return false
        }
        return Date() > expirationDate
    }
    
    /// Check if credential is valid
    public var isValid: Bool {
        return !isExpired && issuanceDate <= Date()
    }
}

/// FHIR Resource wrapper
public struct FHIRResource: Codable {
    public let resourceType: String
    public let id: String?
    public let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case resourceType
        case id
    }
    
    public init(resourceType: String, id: String? = nil, data: [String: Any]? = nil) {
        self.resourceType = resourceType
        self.id = id
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONCodingKeys.self)
        let fullData = try container.decode([String: Any].self)
        guard let resourceType = fullData["resourceType"] as? String else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing or invalid resourceType"))
        }
        self.resourceType = resourceType
        self.id = fullData["id"] as? String
        var additionalData = fullData
        additionalData.removeValue(forKey: "resourceType")
        additionalData.removeValue(forKey: "id")
        self.data = additionalData.isEmpty ? nil : additionalData
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONCodingKeys.self)
        try container.encode(resourceType, forKey: JSONCodingKeys(stringValue: "resourceType"))
        if let id = id {
            try container.encode(id, forKey: JSONCodingKeys(stringValue: "id"))
        }
        if let data = data {
            try container.encode(data)
        }
    }
}

/// Credential proof/signature
public struct CredentialProof: Codable {
    public let type: String
    public let created: Date
    public let verificationMethod: String
    public let proofValue: String
    
    public init(type: String, created: Date, verificationMethod: String, proofValue: String) {
        self.type = type
        self.created = created
        self.verificationMethod = verificationMethod
        self.proofValue = proofValue
    }
}

// MARK: - Codable Support for [String: Any]

// Decoding extensions (unchanged from original)
extension KeyedDecodingContainer {
    func decode(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any> {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }
    
    func decodeIfPresent(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any>? {
        guard contains(key) else {
            return nil
        }
        return try decode(type, forKey: key)
    }
    
    func decode(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any> {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }
    
    func decodeIfPresent(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any>? {
        guard contains(key) else {
            return nil
        }
        return try decode(type, forKey: key)
    }
    
    func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {
        var dictionary = Dictionary<String, Any>()
        
        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode(Dictionary<String, Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode(Array<Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        return dictionary
    }
}

extension UnkeyedDecodingContainer {
    mutating func decode(_ type: Array<Any>.Type) throws -> Array<Any> {
        var array: [Any] = []
        while isAtEnd == false {
            if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let value = try? decode(Int.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode(Dictionary<String, Any>.self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode(Array<Any>.self) {
                array.append(nestedArray)
            }
        }
        return array
    }
    
    mutating func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {
        let nestedContainer = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try nestedContainer.decode(type)
    }
}

// Encoding extensions (newly added for symmetry)
extension KeyedEncodingContainer {
    mutating func encode(_ value: [String: Any], forKey key: K) throws {
        var container = self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        try container.encode(value)
    }
    
    mutating func encodeIfPresent(_ value: [String: Any]?, forKey key: K) throws {
        if let value = value {
            try encode(value, forKey: key)
        }
    }
    
    mutating func encode(_ value: [Any], forKey key: K) throws {
        var container = self.nestedUnkeyedContainer(forKey: key)
        try container.encode(value)
    }
    
    mutating func encodeIfPresent(_ value: [Any]?, forKey key: K) throws {
        if let value = value {
            try encode(value, forKey: key)
        }
    }
    
    mutating func encode(_ value: [String: Any]) throws {
        for (k, v) in value {
            let codingKey = JSONCodingKeys(stringValue: k)
            try encodeAny(v, forKey: codingKey)
        }
    }
    
    private mutating func encodeAny(_ value: Any, forKey key: KeyedEncodingContainer<K>.Key) throws {
        if let bool = value as? Bool {
            try encode(bool, forKey: key)
        } else if let string = value as? String {
            try encode(string, forKey: key)
        } else if let int = value as? Int {
            try encode(int, forKey: key)
        } else if let double = value as? Double {
            try encode(double, forKey: key)
        } else if let dict = value as? [String: Any] {
            var container = nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
            try container.encode(dict)
        } else if let array = value as? [Any] {
            var container = nestedUnkeyedContainer(forKey: key)
            try container.encode(array)
        }
        // Add more type cases if your FHIR data requires (e.g., UInt, Float, etc.)
    }
}

extension UnkeyedEncodingContainer {
    mutating func encode(_ value: [Any]) throws {
        for v in value {
            try encodeAny(v)
        }
    }
    
    private mutating func encodeAny(_ value: Any) throws {
        if let bool = value as? Bool {
            try encode(bool)
        } else if let string = value as? String {
            try encode(string)
        } else if let int = value as? Int {
            try encode(int)
        } else if let double = value as? Double {
            try encode(double)
        } else if let dict = value as? [String: Any] {
            var container = nestedContainer(keyedBy: JSONCodingKeys.self)
            try container.encode(dict)
        } else if let array = value as? [Any] {
            var container = nestedUnkeyedContainer()
            try container.encode(array)
        }
        // Add more type cases if your FHIR data requires (e.g., UInt, Float, etc.)
    }
}

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}
