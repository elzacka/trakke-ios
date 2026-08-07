import Foundation

/// Artsbilder som ligger i appen fordi Artsdatabankens åpne bildekatalog
/// (ai.artsdatabanken.no/taxon/images, ca. 1000 arter) mangler arten.
/// Håndplukket fra Wikimedia Commons med fri lisens. Fotograf og lisens
/// skal alltid vises i bildeteksten – fjern aldri krediteringen.
///
/// Sjekk katalogen før du legger til flere: finnes arten der, skal den
/// hentes derfra (`ArtsdatabankenImageService`), ikke bundles.
struct BundledSpeciesImage {
    let assetName: String
    let credit: String

    static let byScientificName: [String: BundledSpeciesImage] = [
        "Allium ursinum": BundledSpeciesImage(
            assetName: "species-allium-ursinum",
            credit: "Foto: Anneli Salo (CC BY-SA 3.0, Wikimedia Commons)"
        ),
        "Cicuta virosa": BundledSpeciesImage(
            assetName: "species-cicuta-virosa",
            credit: "Foto: Amdb73 (CC BY-SA 3.0, Wikimedia Commons)"
        ),
        "Ursus arctos": BundledSpeciesImage(
            assetName: "species-ursus-arctos",
            credit: "Foto: Per Harald Olsen (CC BY-SA 4.0, Wikimedia Commons)"
        ),
        "Amanita phalloides": BundledSpeciesImage(
            assetName: "species-amanita-phalloides",
            credit: "Foto: Archenzo (CC BY-SA 3.0, Wikimedia Commons)"
        ),
        "Heracleum mantegazzianum": BundledSpeciesImage(
            assetName: "species-heracleum-mantegazzianum",
            credit: "Foto: Lucas Kendall (CC BY-SA 4.0, Wikimedia Commons)"
        ),
        "Ixodes ricinus": BundledSpeciesImage(
            assetName: "species-ixodes-ricinus",
            credit: "Foto: Slimguy (CC BY 4.0, Wikimedia Commons)"
        ),
    ]
}
