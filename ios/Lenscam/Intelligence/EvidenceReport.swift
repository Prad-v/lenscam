import Foundation
import LenscamCore
import UIKit

enum EvidenceReport {
    static func pdf(for sidecar: CaptureSidecar) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            let body = """
            Lenscam evidence report

            \(EvidencePolicy.masterStatement)

            Profile: \(sidecar.profile.title)
            Captured: \(sidecar.createdAt.formatted(date: .abbreviated, time: .standard))
            Master: \(sidecar.masterFilename)
            Codec: \(sidecar.codec)
            SHA-256: \(sidecar.masterSHA256)
            Zoom: \(sidecar.zoom.factorLabel) · \(sidecar.zoom.band.title)
            \(sidecar.zoom.coach)

            \(locationLine(sidecar))

            Text read from the master
            \(sidecar.reading?.sourceText.isEmpty == false ? sidecar.reading?.sourceText ?? "" : "(none)")

            Barcodes
            \(sidecar.reading?.barcodes.isEmpty == false ? sidecar.reading?.barcodes.joined(separator: "\n") ?? "" : "(none)")

            Note
            \(sidecar.note.isEmpty ? "(none)" : sidecar.note)
            """
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black,
            ]
            body.draw(in: page.insetBy(dx: 48, dy: 48), withAttributes: attributes)
        }
    }

    private static func locationLine(_ sidecar: CaptureSidecar) -> String {
        guard let location = sidecar.location else {
            return "Location: not marked"
        }
        return String(
            format: "Location: %.5f, %.5f (±%.0f m)",
            location.latitude,
            location.longitude,
            location.horizontalAccuracy
        )
    }
}
