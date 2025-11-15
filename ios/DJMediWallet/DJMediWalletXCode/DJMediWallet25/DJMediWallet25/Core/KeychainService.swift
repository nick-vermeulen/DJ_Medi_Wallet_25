//
//  KeychainService.swift
//  DJMediWallet
//
//  Lightweight helper for storing sensitive data in the system keychain.
//

import Foundation
import Security

struct KeychainService {
    enum KeychainError: Error {
        case unhandledStatus(OSStatus)
    }
    
    private let service = "com.djmediwallet.applock"
    
    func save(_ data: Data, for key: String, accessibility: CFString = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) throws {
        let baseQuery = query(for: key)
        SecItemDelete(baseQuery as CFDictionary)
        
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecParam || status == errSecDecode {
            var fallbackQuery = baseQuery
            fallbackQuery[kSecValueData as String] = data
            fallbackQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let fallbackStatus = SecItemAdd(fallbackQuery as CFDictionary, nil)
            guard fallbackStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(fallbackStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledStatus(status)
        }
    }
    
    func read(_ key: String) throws -> Data? {
        var query = query(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        return item as? Data
    }
    
    func delete(_ key: String) throws {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
    
    func contains(_ key: String) -> Bool {
        guard let value = try? read(key) else { return false }
        return value != nil
    }
    
    private func query(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
