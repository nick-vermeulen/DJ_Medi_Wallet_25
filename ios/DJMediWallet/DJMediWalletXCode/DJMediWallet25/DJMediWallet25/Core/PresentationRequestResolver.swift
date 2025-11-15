//
//  PresentationRequestResolver.swift
//  DJMediWallet25
//
//  Utilities to parse SD-JWT / OpenID4VP QR payloads into wallet presentation requests.
//

import Foundation

enum PresentationRequestResolverError: LocalizedError {
    case unsupportedFormat
    case invalidPayload
    case remoteRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported QR format."
        case .invalidPayload:
            return "Unable to parse presentation request payload."
        case .remoteRequestFailed(let reason):
            return "Failed to download presentation request: \(reason)"
        }
    }
}

struct PresentationRequestResolver {
    static func resolve(from raw: String) async throws -> SDJWTPresentationRequest {
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(), ["sdjwt", "openid", "openid4vp"].contains(scheme) {
            return try await resolve(from: url)
        }

        if let data = decodeRawPayload(raw) {
            return try decodeRequest(from: data)
        }

        throw PresentationRequestResolverError.unsupportedFormat
    }

    private static func resolve(from url: URL) async throws -> SDJWTPresentationRequest {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw PresentationRequestResolverError.invalidPayload
        }

        if let payload = components.queryItems?.first(where: { ["request", "payload"].contains($0.name) })?.value,
           let data = decodeRawPayload(payload) {
            return try decodeRequest(from: data)
        }

        if let requestURIString = components.queryItems?.first(where: { $0.name == "request_uri" })?.value,
           let requestURL = URL(string: requestURIString) {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(from: requestURL)
            } catch {
                throw PresentationRequestResolverError.remoteRequestFailed(error.localizedDescription)
            }

            if let httpResponse = response as? HTTPURLResponse,
               (200 ..< 300).contains(httpResponse.statusCode) == false {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw PresentationRequestResolverError.remoteRequestFailed("HTTP \(httpResponse.statusCode): \(body)")
            }

            return try decodeRequest(from: data)
        }

        throw PresentationRequestResolverError.invalidPayload
    }

    private static func decodeRawPayload(_ raw: String) -> Data? {
        if let percentDecoded = raw.removingPercentEncoding,
           let decoded = Data(base64URLEncoded: percentDecoded) ?? percentDecoded.data(using: .utf8) {
            return decoded
        }

        if let base64Data = Data(base64URLEncoded: raw) {
            return base64Data
        }

        return raw.data(using: .utf8)
    }

    private static func decodeRequest(from data: Data) throws -> SDJWTPresentationRequest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SDJWTPresentationRequest.self, from: data)
    }
}