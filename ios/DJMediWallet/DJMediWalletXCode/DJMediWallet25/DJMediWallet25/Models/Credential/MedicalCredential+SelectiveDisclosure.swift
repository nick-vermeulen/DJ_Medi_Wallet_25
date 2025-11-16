//
//  MedicalCredential+SelectiveDisclosure.swift
//  DJMediWallet25
//
//  Helpers to extract selective disclosure values from FHIR-based credentials.
//

import Foundation

private let iso8601WithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

extension MedicalCredential {
    func value(forClaimPath claimPath: String) -> SDJWTClaimValue? {
        let trimmed = claimPath.trimmingCharacters(in: .whitespacesAndNewlines)

        switch trimmed {
        case "credential.id":
            return .string(id)
        case "credential.type":
            return .string(type)
        case "credential.issuer":
            return .string(issuer)
        case "credential.issuanceDate":
            return .string(iso8601WithFractional.string(from: issuanceDate))
        case "credential.expirationDate":
            if let expirationDate {
                return .string(iso8601WithFractional.string(from: expirationDate))
            } else {
                return .null
            }
        default:
            break
        }

        let targetPath: String
        if trimmed.hasPrefix("fhir.") {
            targetPath = String(trimmed.dropFirst(5))
        } else {
            targetPath = trimmed
        }

        guard let value = rawFHIRValue(for: targetPath) else {
            return nil
        }

        return SDJWTClaimValue(any: value)
    }

    private func rawFHIRValue(for path: String) -> Any? {
        guard let resource = fhirResource else { return nil }

        if path.isEmpty || path == "*" {
            var payload: [String: Any] = ["resourceType": resource.resourceType]
            if let id = resource.id {
                payload["id"] = id
            }
            if let data = resource.data {
                for (key, value) in data {
                    payload[key] = value
                }
            }
            return payload
        }

        if path == "resourceType" {
            return resource.resourceType
        }

        if path == "id" {
            return resource.id
        }

        guard let data = resource.data else {
            return nil
        }

        return data.value(forKeyPath: path)
    }
}

private extension Dictionary where Key == String, Value == Any {
    func value(forKeyPath keyPath: String) -> Any? {
        let components = keyPath.split(separator: ".").map(String.init)
        guard components.isEmpty == false else { return nil }

        var current: Any? = self
        for component in components {
            guard let next = extract(component: component, from: current) else {
                return nil
            }
            current = next
        }
        return current
    }

    func extract(component: String, from current: Any?) -> Any? {
        let (key, index) = parseComponent(component)

        switch (key, current) {
        case let (key?, dictionary as [String: Any]):
            guard let child = dictionary[key] else { return nil }
            if let index {
                guard let array = child as? [Any], array.indices.contains(index) else { return nil }
                return array[index]
            }
            return child
        case let (nil, array as [Any]):
            guard let index, array.indices.contains(index) else { return nil }
            return array[index]
        default:
            return nil
        }
    }

    func parseComponent(_ component: String) -> (key: String?, index: Int?) {
        guard let start = component.firstIndex(of: "["),
              let end = component.firstIndex(of: "]"),
              start < end else {
            return (component, nil)
        }

        let key = String(component[..<start])
        let indexStart = component.index(after: start)
        let indexString = component[indexStart..<end]
        let index = Int(indexString)
        return (key.isEmpty ? nil : key, index)
    }
}

extension SDJWTClaimValue {
    init?(any value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let bool as Bool:
            self = .bool(bool)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let double as Double:
            self = .number(double)
        case let int as Int:
            self = .number(Double(int))
        case let date as Date:
            self = .string(iso8601WithFractional.string(from: date))
        case let dict as [String: Any]:
            var mapped: [String: SDJWTClaimValue] = [:]
            for (key, nested) in dict {
                if let mappedValue = SDJWTClaimValue(any: nested) {
                    mapped[key] = mappedValue
                }
            }
            self = .object(mapped)
        case let array as [Any]:
            let mapped = array.compactMap { SDJWTClaimValue(any: $0) }
            self = .array(mapped)
        case _ as NSNull:
            self = .null
        default:
            return nil
        }
    }
}