//
//  Images.swift
//  PaintBook
//
//  Cross-platform image loading, pixel sampling, thumbnails and the camera.
//

import SwiftUI
import ImageIO
import CoreGraphics

nonisolated enum ImageLoader {
    /// Decodes image data into an upright CGImage no larger than `maxPixelSize`.
    /// Works the same on iOS and macOS, and applies the photo's EXIF orientation.
    static func cgImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Same as `cgImage(from:maxPixelSize:)`, but off the main thread.
    @concurrent
    static func loadImage(from data: Data, maxPixelSize: Int) async -> CGImage? {
        cgImage(from: data, maxPixelSize: maxPixelSize)
    }

    /// Average sRGB colour of the square of pixels around `point`
    /// (in image pixel coordinates, origin top-left).
    static func averageColor(in image: CGImage, at point: CGPoint, radius: Int = 4) -> RGB? {
        let size = radius * 2 + 1
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            // Core Graphics puts the origin bottom-left, so flip the row.
            let px = Int(point.x.rounded(.down))
            let py = image.height - 1 - Int(point.y.rounded(.down))
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: radius - px, y: radius - py,
                                           width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }

        var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3])
            guard alpha > 0 else { continue } // outside the image edge
            red += Double(pixels[i]) / alpha
            green += Double(pixels[i + 1]) / alpha
            blue += Double(pixels[i + 2]) / alpha
            count += 1
        }
        guard count > 0 else { return nil }
        return RGB(red: red / count, green: green / count, blue: blue / count)
    }
}

/// A square photo thumbnail that decodes in the background.
struct PhotoThumbnail: View {
    let data: Data
    var size: CGFloat = 80

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 8))
        .task(id: data) {
            image = await ImageLoader.loadImage(from: data, maxPixelSize: Int(size * 3))
        }
    }
}

#if os(iOS)
import UIKit

/// Wraps the system camera. Returns the photo as JPEG data.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
