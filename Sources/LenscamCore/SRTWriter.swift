import Foundation

public enum SRTWriter {
    public static func render(_ segments: [TranscriptSegment]) -> String {
        segments.enumerated().map { index, segment in
            let start = min(segment.start, segment.end)
            let end = max(segment.start, segment.end)
            let lines = [segment.text, segment.translation]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let body = lines.joined(separator: "\n")
            return "\(index + 1)\n\(timestamp(start)) --> \(timestamp(end))\n\(body)\n"
        }
        .joined(separator: "\n")
    }

    public static func timestamp(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let totalMillis = Int((clamped * 1000).rounded())
        let hours = totalMillis / 3_600_000
        let minutes = (totalMillis % 3_600_000) / 60_000
        let secs = (totalMillis % 60_000) / 1000
        let millis = totalMillis % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }
}
