import UIKit

enum ImageProcessor {
    static func prepareUploadData(_ data: Data, maxDimension: CGFloat = 1280, compressionQuality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largestSide = max(pixelWidth, pixelHeight)
        let targetLargestSide = max(maxDimension, 1)

        if largestSide > targetLargestSide {
            let scaleRatio = targetLargestSide / largestSide
            let targetPixelWidth = max(floor(pixelWidth * scaleRatio), 1)
            let targetPixelHeight = max(floor(pixelHeight * scaleRatio), 1)
            let targetSize = CGSize(width: targetPixelWidth, height: targetPixelHeight)

            let rendererFormat = UIGraphicsImageRendererFormat()
            rendererFormat.scale = 1
            rendererFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
            let renderedImage = renderer.image { context in
                context.cgContext.interpolationQuality = .high
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            if let jpegData = renderedImage.jpegData(compressionQuality: compressionQuality) {
                return jpegData
            }
        } else if let jpegData = image.jpegData(compressionQuality: compressionQuality), jpegData.count < data.count {
            return jpegData
        }

        return data
    }
}
