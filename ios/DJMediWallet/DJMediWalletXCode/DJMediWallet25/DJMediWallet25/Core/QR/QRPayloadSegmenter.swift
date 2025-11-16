import Foundation

struct QRPayloadSegment: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let total: Int
    let payload: String
}

enum QRPayloadSegmenter {
    private static let headerPrefix = "DJMW"
    private static let headerSeparator = "|"
    private static let defaultMaxLength = 700
    private static let minimumBodyLength = 80

    static func segments(for payload: String, maxLength: Int = defaultMaxLength) -> [QRPayloadSegment] {
        let bodyLength = max(1, maxLength - estimatedHeaderLength(forTotalCount: 1))
        guard payload.count > bodyLength else {
            let singlePayload = makeSegmentPayload(index: 1, total: 1, body: payload)
            return [QRPayloadSegment(index: 1, total: 1, payload: singlePayload)]
        }

        var chunkSize = max(minimumBodyLength, maxLength - estimatedHeaderLength(forTotalCount: payload.count / minimumBodyLength + 1))
        var segments: [QRPayloadSegment] = []

        while chunkSize >= minimumBodyLength {
            let parts = chunk(payload, chunkSize: chunkSize)
            let total = parts.count

            let generated: [QRPayloadSegment] = parts.enumerated().compactMap { offset, part in
                let index = offset + 1
                let segmentPayload = makeSegmentPayload(index: index, total: total, body: part)
                guard segmentPayload.count <= maxLength else { return nil }
                return QRPayloadSegment(index: index, total: total, payload: segmentPayload)
            }

            if generated.count == total {
                segments = generated
                break
            }

            chunkSize -= 20
        }

        if segments.isEmpty {
            let body = String(payload.prefix(maxLength - estimatedHeaderLength(forTotalCount: 1)))
            let fallback = makeSegmentPayload(index: 1, total: 1, body: body)
            segments = [QRPayloadSegment(index: 1, total: 1, payload: fallback)]
        }

        return segments
    }

    private static func chunk(_ payload: String, chunkSize: Int) -> [String] {
        var result: [String] = []
        var start = payload.startIndex
        while start < payload.endIndex {
            let end = payload.index(start, offsetBy: chunkSize, limitedBy: payload.endIndex) ?? payload.endIndex
            result.append(String(payload[start..<end]))
            start = end
        }
        return result
    }

    private static func makeSegmentPayload(index: Int, total: Int, body: String) -> String {
        "\(headerPrefix)\(headerSeparator)\(index)\(headerSeparator)\(total)\(headerSeparator)\(body)"
    }

    private static func estimatedHeaderLength(forTotalCount total: Int) -> Int {
        let digits = String(total).count
        let maxIndexDigits = digits
        return headerPrefix.count + (headerSeparator.count * 3) + digits + maxIndexDigits
    }
}
