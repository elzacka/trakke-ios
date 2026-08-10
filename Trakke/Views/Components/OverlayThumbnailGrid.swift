import SwiftUI

/// Kartlag-velgeren i Innstillinger: ett kort per `OverlayLayer` med bundlet
/// forhåndsvisning (Assets.xcassets/OverlayThumbs, generert av
/// Scripts/generate_overlay_thumbnails.swift). Trykk toggler laget av/på;
/// ingen, ett eller flere lag kan være aktive samtidig.
///
/// Kortene sorteres alfabetisk på norsk visningsnavn – aldri manuell
/// rekkefølge, så et nytt lag ikke kan havne feil eller bli glemt i listen.
struct OverlayThumbnailGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sortedOverlays: [OverlayLayer] {
        OverlayLayer.allCases.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize >= .accessibility1 ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: .Trakke.sm), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: .Trakke.sm) {
            ForEach(sortedOverlays) { overlay in
                OverlayThumbnailCard(overlay: overlay)
            }
        }
    }
}

/// Ett trykkbart kort: forhåndsvisning + navn. Aktiv tilstand markeres med
/// både ramme og hake – aldri farge alene (WCAG 1.4.1).
struct OverlayThumbnailCard: View {
    let overlay: OverlayLayer
    @AppStorage private var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(overlay: OverlayLayer) {
        self.overlay = overlay
        // Dynamisk nøkkel per kort holder tilstanden på samme UserDefaults-
        // nøkler som MapViewModel observerer – ingen mellomlagring.
        self._isOn = AppStorage(wrappedValue: false, overlay.storageKey)
    }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            cardLabel
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(overlay.displayName)
        .accessibilityValue(isOn
            ? String(localized: "accessibility.enabled")
            : String(localized: "accessibility.disabled"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var cardLabel: some View {
        VStack(alignment: .leading, spacing: .Trakke.xs) {
            thumbnail
            Text(overlay.displayName)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        Image(overlay.thumbnailAssetName)
            .resizable()
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: .TrakkeRadius.sm)
                    .strokeBorder(
                        isOn ? Color.Trakke.brand : Color.Trakke.border,
                        lineWidth: isOn ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Trakke.brandLight)
                        .padding(.Trakke.xs)
                        .background(Circle().fill(Color.Trakke.surface))
                        .padding(.Trakke.xs)
                }
            }
    }
}
