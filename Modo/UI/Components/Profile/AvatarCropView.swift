import SwiftUI
import UIKit
import AVFoundation

struct AvatarCropView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var cropSize: CGFloat = 0
    @State private var imageDisplaySize: CGSize = .zero

    private let exportSize: CGFloat = 1024
    private let minCropSize: CGFloat = 512

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()

                GeometryReader { geo in
                    // Leave comfortable margins so the circle doesn't clip
                    let margin: CGFloat = 32
                    let rawSide = min(geo.size.width, geo.size.height) - (margin * 2)
                    // Also cap to 80% of the shorter side so the crop area isn't overwhelming
                    let cap = min(geo.size.width, geo.size.height) * 0.8
                    let side = max(1, min(rawSide, cap))
                    let cropRect = CGRect(x: (geo.size.width - side) / 2,
                                          y: (geo.size.height - side) / 2,
                                          width: side,
                                          height: side)

                    ZStack {
                        // Image layer
                        Image(uiImage: sourceImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .modifier(MeasureSizeModifier(size: $imageDisplaySize))
                            .frame(width: geo.size.width)
                            .offset(offset)
                            .scaleEffect(scale, anchor: .center)
                            .gesture(dragGesture.simultaneously(with: magnificationGesture))

                        // No global dimming to avoid "black screen" feel
                        EmptyView()

                        // Circular crop border
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                            .frame(width: side, height: side)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .allowsHitTesting(false)
                    }
                    .onAppear {
                        cropSize = side
                        autoFitInitial(geoSize: geo.size, cropSide: side)
                    }
                    .onChange(of: geo.size) { _, newValue in
                        let newRawSide = min(newValue.width, newValue.height) - (margin * 2)
                        let newSide = max(1, newRawSide)
                        cropSize = newSide
                        enforceBounds(cropSide: newSide)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .principal) {
                    Text("Adjust Avatar")
                        .foregroundColor(.black)
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let image = renderCroppedImage() {
                            onConfirm(image)
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(.black)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1.0, min(lastScale * value, 4.0))
            }
            .onEnded { _ in
                lastScale = scale
                enforceBounds(cropSide: cropSize)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
                enforceBounds(cropSide: cropSize)
            }
    }

    private func autoFitInitial(geoSize: CGSize, cropSide: CGFloat) {
        // Fit the image so that it at least covers the crop square
        let imgW = sourceImage.size.width
        let imgH = sourceImage.size.height
        guard imgW.isFinite && imgH.isFinite && imgW > 0 && imgH > 0 else { return }

        // Base fitted width equals geo width (contentMode .fit)
        let baseWidth = max(1, geoSize.width)
        let baseHeight = max(1, baseWidth * (imgH / imgW))
        imageDisplaySize = CGSize(width: baseWidth, height: baseHeight)

        let neededScaleToCover = max(cropSide / baseWidth, cropSide / baseHeight)
        scale = max(1.0, neededScaleToCover * 1.02)
        lastScale = scale
        offset = .zero
        lastOffset = .zero
    }

    private func enforceBounds(cropSide: CGFloat) {
        guard imageDisplaySize.width > 0 && imageDisplaySize.height > 0 else { return }
        let displayedWidth = imageDisplaySize.width * scale
        let displayedHeight = imageDisplaySize.height * scale

        let maxOffsetX = max(0, (displayedWidth - cropSide) / 2)
        let maxOffsetY = max(0, (displayedHeight - cropSide) / 2)

        let clampedX = max(-maxOffsetX, min(maxOffsetX, offset.width))
        let clampedY = max(-maxOffsetY, min(maxOffsetY, offset.height))
        offset = CGSize(width: clampedX, height: clampedY)
        lastOffset = offset

        // Ensure minimum scale keeps image covering the crop area
        let minScaleNeeded = max(cropSide / imageDisplaySize.width, cropSide / imageDisplaySize.height)
        if scale < minScaleNeeded {
            scale = minScaleNeeded
            lastScale = scale
        }
    }

    private func renderCroppedImage() -> UIImage? {
        // Map from on-screen points to source image PIXELS (use cgImage dimensions)
        guard imageDisplaySize.width > 0 && imageDisplaySize.height > 0 else { return nil }
        guard let cgImage = sourceImage.cgImage else { return nil }
        let sourcePixelW = CGFloat(cgImage.width)
        let sourcePixelH = CGFloat(cgImage.height)

        // Compute mapping using centers to avoid skew
        let displayedW = imageDisplaySize.width * scale
        let displayedH = imageDisplaySize.height * scale
        let cropSide = self.cropSize

        // Offset represents how much the image's center is shifted from the crop center (0,0)
        // Positive offset.x means image moved right, so crop center sees more of the LEFT source
        let sourceCenterX = sourcePixelW / 2 - offset.width * (sourcePixelW / displayedW)
        let sourceCenterY = sourcePixelH / 2 - offset.height * (sourcePixelH / displayedH)

        let sourceCropW = cropSide * (sourcePixelW / displayedW)
        let sourceCropH = cropSide * (sourcePixelH / displayedH)

        var sourceCropRect = CGRect(
            x: sourceCenterX - sourceCropW / 2,
            y: sourceCenterY - sourceCropH / 2,
            width: sourceCropW,
            height: sourceCropH
        ).integral

        // Clamp to image bounds
        if sourceCropRect.minX < 0 { sourceCropRect.origin.x = 0 }
        if sourceCropRect.minY < 0 { sourceCropRect.origin.y = 0 }
        if sourceCropRect.maxX > sourcePixelW { sourceCropRect.origin.x = max(0, sourcePixelW - sourceCropRect.width) }
        if sourceCropRect.maxY > sourcePixelH { sourceCropRect.origin.y = max(0, sourcePixelH - sourceCropRect.height) }

        guard let cropped = cgImage.cropping(to: sourceCropRect.integral)
        else { return nil }

        let croppedImage = UIImage(cgImage: cropped, scale: sourceImage.scale, orientation: .up)

        // Enforce minimum size and export to 1024x1024
        let target = CGSize(width: exportSize, height: exportSize)
        let renderer = UIGraphicsImageRenderer(size: target)
        let finalImage = renderer.image { _ in
            // Strict aspect-fill: ensure no margins around the image
            let scaleFill = max(target.width / croppedImage.size.width, target.height / croppedImage.size.height)
            let drawSize = CGSize(width: croppedImage.size.width * scaleFill,
                                  height: croppedImage.size.height * scaleFill)
            let origin = CGPoint(x: (target.width - drawSize.width) / 2,
                                 y: (target.height - drawSize.height) / 2)
            croppedImage.draw(in: CGRect(origin: origin, size: drawSize))
        }

        // Check minimum effective resolution
        if Int(finalImage.size.width) < Int(minCropSize) || Int(finalImage.size.height) < Int(minCropSize) {
            return nil
        }

        // Compress to JPEG ~0.85 and back to UIImage
        if let data = finalImage.jpegData(compressionQuality: 0.85), let out = UIImage(data: data) {
            return out
        }
        return finalImage
    }

    private func croppedPreview(in cropRect: CGRect) -> some View {
        GeometryReader { _ in
            Image(uiImage: sourceImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: max(1, cropRect.width))
                .offset(offset * (cropRect.width / (cropSize == 0 ? 1 : cropSize)))
                .scaleEffect(scale, anchor: .center)
        }
        .frame(width: max(1, cropRect.width), height: max(1, cropRect.width))
    }
}

private struct MeasureSizeModifier: ViewModifier {
    @Binding var size: CGSize
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.onAppear { size = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in size = newSize }
            }
        )
    }
}

private extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}


