//
//  Base64URLExtensions.swift
//  DJMediWallet25
//
//  Helper utilities for Base64URL encoding/decoding required by SD-JWT payloads.
//

import Foundation

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        let paddingLength = (4 - string.count % 4) % 4
        let padded = string + String(repeating: "=", count: paddingLength)
        let base64 = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        self.init(base64Encoded: base64)
    }
}

extension String {
    func base64URLDecodedData() -> Data? {
        Data(base64URLEncoded: self)
    }
}