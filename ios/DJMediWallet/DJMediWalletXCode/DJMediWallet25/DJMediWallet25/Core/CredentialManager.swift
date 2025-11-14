//
//  CredentialManager.swift
//  DJMediWallet
//
//  Manages medical credential validation and processing
//

import Foundation

/// Manages validation and processing of medical credentials
public class CredentialManager {
    
    // MARK: - Credential Validation
    
    /// Validate medical credential structure and content
    public func validateCredential(_ credential: MedicalCredential) -> Bool {
        // Check required fields
        guard !credential.id.isEmpty,
              !credential.type.isEmpty,
              credential.issuanceDate <= Date() else {
            return false
        }
        
        // Validate FHIR resource if present
        if let fhirResource = credential.fhirResource {
            return validateFHIRResource(fhirResource)
        }
        
        return true
    }
    
    /// Validate FHIR resource structure
    private func validateFHIRResource(_ resource: FHIRResource) -> Bool {
        // Check resource type
        guard !resource.resourceType.isEmpty else {
            return false
        }
        
        // Validate based on resource type
        switch resource.resourceType {
        case "Patient":
            return validatePatientResource(resource)
        case "Observation":
            return validateObservationResource(resource)
        case "Condition":
            return validateConditionResource(resource)
        case "MedicationStatement":
            return validateMedicationResource(resource)
        case "AllergyIntolerance":
            return validateAllergyResource(resource)
        case "Immunization":
            return validateImmunizationResource(resource)
        default:
            // Allow other resource types
            return true
        }
    }
    
    private func validatePatientResource(_ resource: FHIRResource) -> Bool {
        // Patient should have at least name or identifier
        guard let data = resource.data,
              data["name"] != nil || data["identifier"] != nil else {
            return false
        }
        return true
    }
    
    private func validateObservationResource(_ resource: FHIRResource) -> Bool {
        // Observation must have status and code
        guard let data = resource.data,
              data["status"] != nil,
              data["code"] != nil else {
            return false
        }
        return true
    }
    
    private func validateConditionResource(_ resource: FHIRResource) -> Bool {
        // Condition must have code
        guard let data = resource.data,
              data["code"] != nil else {
            return false
        }
        return true
    }
    
    private func validateMedicationResource(_ resource: FHIRResource) -> Bool {
        // MedicationStatement must have status and medication
        guard let data = resource.data,
              data["status"] != nil,
              (data["medicationCodeableConcept"] != nil || data["medicationReference"] != nil) else {
            return false
        }
        return true
    }
    
    private func validateAllergyResource(_ resource: FHIRResource) -> Bool {
        // AllergyIntolerance must have code or substance
        guard let data = resource.data,
              (data["code"] != nil || data["substance"] != nil) else {
            return false
        }
        return true
    }
    
    private func validateImmunizationResource(_ resource: FHIRResource) -> Bool {
        // Immunization must have status and vaccineCode
        guard let data = resource.data,
              data["status"] != nil,
              data["vaccineCode"] != nil else {
            return false
        }
        return true
    }
    
    // MARK: - SNOMED CT Code Validation
    
    /// Validate SNOMED CT code format
    public func validateSNOMEDCode(_ code: String) -> Bool {
        // SNOMED CT codes are 6-18 digits
        let pattern = "^[0-9]{6,18}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(code.startIndex..., in: code)
        return regex?.firstMatch(in: code, range: range) != nil
    }
    
    /// Extract SNOMED codes from FHIR resource
    public func extractSNOMEDCodes(from resource: FHIRResource) -> [SNOMEDCode] {
        var codes: [SNOMEDCode] = []
        
        guard let data = resource.data else {
            return codes
        }
        
        // Recursive function to search for SNOMED codes in nested structures
        func searchForCodes(in value: Any) {
            if let dict = value as? [String: Any] {
                // Check if this is a coding with SNOMED system
                if let system = dict["system"] as? String,
                   system == "http://snomed.info/sct",
                   let code = dict["code"] as? String {
                    let display = dict["display"] as? String
                    codes.append(SNOMEDCode(code: code, display: display))
                }
                
                // Recursively search nested dictionaries
                for (_, nestedValue) in dict {
                    searchForCodes(in: nestedValue)
                }
            } else if let array = value as? [Any] {
                // Recursively search arrays
                for item in array {
                    searchForCodes(in: item)
                }
            }
        }
        
        searchForCodes(in: data)
        return codes
    }
    
    // MARK: - Credential Processing
    
    /// Extract readable summary from credential
    public func extractSummary(from credential: MedicalCredential) -> String {
        guard let resource = credential.fhirResource else {
            return "Medical Credential: \(credential.type)"
        }
        
        switch resource.resourceType {
        case "Patient":
            return extractPatientSummary(resource)
        case "Observation":
            return extractObservationSummary(resource)
        case "Condition":
            return extractConditionSummary(resource)
        case "MedicationStatement":
            return extractMedicationSummary(resource)
        case "AllergyIntolerance":
            return extractAllergySummary(resource)
        case "Immunization":
            return extractImmunizationSummary(resource)
        default:
            return "\(resource.resourceType) Record"
        }
    }
    
    private func extractPatientSummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data else { return "Patient Record" }
        
        if let nameArray = data["name"] as? [[String: Any]],
           let name = nameArray.first,
           let given = name["given"] as? [String],
           let family = name["family"] as? String {
            return "\(given.joined(separator: " ")) \(family)"
        }
        
        return "Patient Record"
    }
    
    private func extractObservationSummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data,
              let code = data["code"] as? [String: Any],
              let coding = code["coding"] as? [[String: Any]],
              let display = coding.first?["display"] as? String else {
            return "Observation"
        }
        return display
    }
    
    private func extractConditionSummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data,
              let code = data["code"] as? [String: Any],
              let coding = code["coding"] as? [[String: Any]],
              let display = coding.first?["display"] as? String else {
            return "Condition"
        }
        return display
    }
    
    private func extractMedicationSummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data else { return "Medication" }
        
        if let medication = data["medicationCodeableConcept"] as? [String: Any],
           let coding = medication["coding"] as? [[String: Any]],
           let display = coding.first?["display"] as? String {
            return display
        }
        
        return "Medication"
    }
    
    private func extractAllergySummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data else { return "Allergy" }
        
        if let code = data["code"] as? [String: Any],
           let coding = code["coding"] as? [[String: Any]],
           let display = coding.first?["display"] as? String {
            return "Allergy: \(display)"
        }
        
        return "Allergy Record"
    }
    
    private func extractImmunizationSummary(_ resource: FHIRResource) -> String {
        guard let data = resource.data,
              let vaccineCode = data["vaccineCode"] as? [String: Any],
              let coding = vaccineCode["coding"] as? [[String: Any]],
              let display = coding.first?["display"] as? String else {
            return "Immunization"
        }
        return "Vaccine: \(display)"
    }
}

// MARK: - Supporting Types

public struct SNOMEDCode: Codable {
    public let code: String
    public let display: String?
    
    public init(code: String, display: String?) {
        self.code = code
        self.display = display
    }
}
