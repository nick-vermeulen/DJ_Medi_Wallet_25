import Foundation

struct QRSegmentAccumulator {
    struct Progress {
        let collectedCount: Int
        let totalCount: Int
        let latestIndex: Int
        let nextExpectedIndex: Int?
        let isDuplicate: Bool
    }

    enum Outcome {
        case singlePayload(String)
        case progress(Progress)
        case complete(String)
        case invalid(String)
    }

    private static let headerPrefix = "DJMW"
    private static let headerSeparator: Character = "|"

    private var expectedTotal: Int?
    private var segments: [Int: String] = [:]

    mutating func reset() {
        expectedTotal = nil
        segments.removeAll()
    }

    mutating func ingest(_ raw: String) -> Outcome {
        guard let segment = parseSegment(from: raw) else {
            if expectedTotal == nil && segments.isEmpty {
                return .singlePayload(raw)
            }
            let message = "Scanned code doesn’t belong to this presentation. Start over from the first segment."
            reset()
            return .invalid(message)
        }

        if let expectedTotal, expectedTotal != segment.total {
            let message = "Segments disagreed on how many parts to expect. Ask the sharer to restart the QR sequence."
            reset()
            return .invalid(message)
        }

        expectedTotal = segment.total

        guard segment.index >= 1, segment.index <= segment.total else {
            let message = "Segment number \(segment.index) is outside the expected range. Begin the scan again."
            reset()
            return .invalid(message)
        }

        if let existing = segments[segment.index] {
            if existing == segment.body {
                let progress = Progress(
                    collectedCount: segments.count,
                    totalCount: segment.total,
                    latestIndex: segment.index,
                    nextExpectedIndex: nextExpectedIndex(forTotal: segment.total),
                    isDuplicate: true
                )
                return .progress(progress)
            } else {
                let message = "Segment \(segment.index) doesn’t match the previous scan. Restart the scanning sequence."
                reset()
                return .invalid(message)
            }
        }

        segments[segment.index] = segment.body
        let collected = segments.count

        if collected == segment.total {
            let ordered = (1...segment.total).compactMap { index -> String? in
                segments[index]
            }

            guard ordered.count == segment.total else {
                let message = "One or more segments are missing. Restart the scanning sequence."
                reset()
                return .invalid(message)
            }

            let payload = ordered.joined()
            reset()
            return .complete(payload)
        }

        let progress = Progress(
            collectedCount: collected,
            totalCount: segment.total,
            latestIndex: segment.index,
            nextExpectedIndex: nextExpectedIndex(forTotal: segment.total),
            isDuplicate: false
        )
        return .progress(progress)
    }

    private func parseSegment(from raw: String) -> (index: Int, total: Int, body: String)? {
        guard raw.hasPrefix(Self.headerPrefix + String(Self.headerSeparator)) else {
            return nil
        }

        let components = raw.split(separator: Self.headerSeparator, maxSplits: 3, omittingEmptySubsequences: false)
        guard components.count == 4,
              let index = Int(components[1]),
              let total = Int(components[2]) else {
            return nil
        }

        let body = String(components[3])
        return (index, total, body)
    }

    private func nextExpectedIndex(forTotal total: Int) -> Int? {
        guard total > 0 else { return nil }
        for index in 1...total {
            if segments[index] == nil {
                return index
            }
        }
        return nil
    }
}
