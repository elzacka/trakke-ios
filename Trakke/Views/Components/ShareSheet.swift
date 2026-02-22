import SwiftUI

// MARK: - Shareable URL

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        // iPad requires a popover anchor; nil on iPhone (no-op).
        controller.popoverPresentationController?.permittedArrowDirections = []
        controller.popoverPresentationController?.sourceView = controller.view

        controller.completionWithItemsHandler = { _, _, _, _ in
            // Clean up temp files after share sheet dismissal
            for item in activityItems {
                if let url = item as? URL, url.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            onDismiss?()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        uiViewController.popoverPresentationController?.sourceRect = CGRect(
            x: uiViewController.view.bounds.midX,
            y: uiViewController.view.bounds.midY,
            width: 0,
            height: 0
        )
    }
}
