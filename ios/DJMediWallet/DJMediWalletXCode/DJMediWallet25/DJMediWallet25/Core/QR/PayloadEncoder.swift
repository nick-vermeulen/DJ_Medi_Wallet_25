import Foundation
import Compression

enum PayloadEncoder {
    static let compressionPrefix = "compressed:"

    enum DecodedPayloadFormat {
        case prefixedCompressed
        case inferredCompressed
        case plainUTF8
    }

    struct DecodedPayload {
        let data: Data
        let format: DecodedPayloadFormat
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count > 2000 else {
            return String(decoding: data, as: UTF8.self)
        }
        let compressed = try gzipCompress(data: data)
        let base64 = compressed.base64EncodedString()
        return compressionPrefix + base64
    }

    static func decodePayload(_ payload: String) throws -> Data {
        try decodePayloadDetailed(payload).data
    }

    static func decodePayloadDetailed(_ payload: String) throws -> DecodedPayload {
        if payload.hasPrefix(compressionPrefix) {
            let base64 = String(payload.dropFirst(compressionPrefix.count))
            guard let compressedData = Data(base64Encoded: base64) else {
                throw PayloadError.invalidBase64
            }
            let decompressed = try gzipDecompress(data: compressedData)
            return DecodedPayload(data: decompressed, format: .prefixedCompressed)
        }

        if let base64Data = Data(base64Encoded: payload), looksLikeZlib(base64Data) {
            let decompressed = try gzipDecompress(data: base64Data)
            return DecodedPayload(data: decompressed, format: .inferredCompressed)
        }

        if let utfData = payload.data(using: .utf8) {
            if looksLikeZlib(utfData) {
                let decompressed = try gzipDecompress(data: utfData)
                return DecodedPayload(data: decompressed, format: .inferredCompressed)
            }
            return DecodedPayload(data: utfData, format: .plainUTF8)
        }

        throw PayloadError.invalidUTF8
    }

    private static func gzipCompress(data: Data) throws -> Data {
        try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
            guard let baseAddress = sourceBuffer.baseAddress else {
                throw PayloadError.bufferFailure
            }
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }
            let compressedSize = compression_encode_buffer(
                destinationBuffer,
                data.count,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
            guard compressedSize > 0 else {
                throw PayloadError.compressionFailed
            }
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
    }

    private static func gzipDecompress(data: Data) throws -> Data {
        var decompressed = Data()
        let chunkSize = max(2048, data.count * 2)
        try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) in
            guard let baseAddress = sourceBuffer.baseAddress else {
                throw PayloadError.bufferFailure
            }
            var stream = compression_stream(
                dst_ptr: UnsafeMutablePointer<UInt8>(bitPattern: 0)!,
                dst_size: 0,
                src_ptr: UnsafePointer<UInt8>(bitPattern: 0)!,
                src_size: 0,
                state: nil
            )
            var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status != COMPRESSION_STATUS_ERROR else {
                throw PayloadError.compressionFailed
            }
            defer { compression_stream_destroy(&stream) }
            stream.src_ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            stream.src_size = data.count

            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { dstBuffer.deallocate() }

            repeat {
                stream.dst_ptr = dstBuffer
                stream.dst_size = chunkSize
                status = compression_stream_process(&stream, 0)
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let outputSize = chunkSize - stream.dst_size
                    if outputSize > 0 {
                        decompressed.append(dstBuffer, count: outputSize)
                    }
                default:
                    throw PayloadError.compressionFailed
                }
            } while status == COMPRESSION_STATUS_OK

            if status != COMPRESSION_STATUS_END {
                throw PayloadError.compressionFailed
            }
        }
        return decompressed
    }

    enum PayloadError: Error {
        case invalidUTF8
        case invalidBase64
        case compressionFailed
        case bufferFailure
    }

    private static func looksLikeZlib(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let header = data[data.startIndex]
        let flag = data[data.index(after: data.startIndex)]
        if header == 0x78 && [UInt8(0x01), 0x5E, 0x9C, 0xDA].contains(flag) {
            return true
        }
        return false
    }
}
