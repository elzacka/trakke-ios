import SwiftUI

// MARK: - Shareable URL

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        // iPad requires a popover anchor; nil on iPhone (no-op).
        controller.popoverPresentationController?.permittedArrowDirections = []
        controller.popoverPresentationController?.sourceView = controller.view
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
