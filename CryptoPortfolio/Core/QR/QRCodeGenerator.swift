import UIKit
import CoreImage

/// Produces a `UIImage` from a string using CoreImage's QR code filter.
/// Returns `nil` for empty strings or generation failure.
enum QRCodeGenerator {
    static func generate(text: String, size: CGFloat = 240) -> UIImage? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter?.outputImage else { return nil }
        let scale = max(1, size / ciImage.extent.width)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
