import SwiftUI

/// Image source for the full-screen image viewer.
enum ImageViewerSource {
    /// Image from the asset catalog (bundled article images).
    case asset(name: String)
    /// Pre-loaded UIImage (species images from Artsdatabanken).
    case uiImage(UIImage)
}

/// Full-screen image viewer with pinch-to-zoom and drag-to-dismiss.
/// Accepts either an asset catalog image or a pre-loaded UIImage.
struct ImageViewerView: View {
    let source: ImageViewerSource
    let caption: String
    var attribution: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    /// Convenience initializer for asset catalog images.
    init(name: String, caption: String) {
        self.source = .asset(name: name)
        self.caption = caption
    }

    /// Convenience initializer for species images (UIImage + Artsdatabanken attribution).
    init(uiImage: UIImage, caption: String, attribution: String? = nil) {
        self.source = .uiImage(uiImage)
        self.caption = caption
        self.attribution = attribution
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            imageContent
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnifyGesture)
                .gesture(dragGesture)
                .accessibilityLabel(caption)
                .accessibilityAddTraits(.isImage)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                    }
                    .accessibilityLabel(String(localized: "image.viewer.close"))
                }
                .padding(.trailing, .Trakke.md)
                .padding(.top, .Trakke.sm)

                Spacer()

                if !caption.isEmpty || attribution != nil {
                    VStack(spacing: .Trakke.xs) {
                        if !caption.isEmpty {
                            Text(caption)
                                .font(Font.Trakke.bodyRegular)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        if let attribution {
                            Text(attribution)
                                .font(Font.Trakke.captionSoft)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, .Trakke.sheetHorizontal)
                    .padding(.vertical, .Trakke.lg)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    )
                }
            }
        }
        .statusBarHidden()
    }

    // MARK: - Image Content

    @ViewBuilder
    private var imageContent: some View {
        switch source {
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .uiImage(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = lastScale * value.magnification
            }
            .onEnded { _ in
                let animation = reduceMotion ? Animation?.none : .easeOut(duration: 0.2)
                if scale < 1.0 {
                    withAnimation(animation) {
                        scale = 1.0
                        offset = .zero
                    }
                    lastScale = 1.0
                } else {
                    lastScale = min(scale, 5.0)
                    scale = lastScale
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale <= 1.0 {
                    offset = CGSize(width: 0, height: value.translation.height)
                } else {
                    offset = value.translation
                }
            }
            .onEnded { value in
                let animation = reduceMotion ? Animation?.none : .easeOut(duration: 0.2)
                if scale <= 1.0 && abs(value.translation.height) > 100 {
                    dismiss()
                } else {
                    withAnimation(animation) {
                        offset = .zero
                    }
                }
            }
    }
}
