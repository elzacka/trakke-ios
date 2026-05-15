import SwiftUI

/// Bottom-anchored info pill: "du har forlatt offline-området".
/// Auto-dismisses after 5 s and clears the flag on the view-model.
struct OfflineWarningToast: View {
    let viewModel: OfflineViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(String(localized: "offline.leftArea"))
            .font(Font.Trakke.caption)
            .foregroundStyle(Color.Trakke.textInverse)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.warning)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 80)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(reduceMotion ? nil : .default) {
                    viewModel.showLeftAreaWarning = false
                }
            }
    }
}

/// Bottom-anchored success pill: "kommune lastet ned ferdig".
/// Auto-dismisses after 4 s and clears the message.
struct DownloadCompleteToast: View {
    let viewModel: OfflineViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "checkmark.circle.fill")
            Text(String(localized: "offline.downloadComplete \(viewModel.completionMessage ?? "")"))
                .font(Font.Trakke.caption)
        }
        .foregroundStyle(Color.Trakke.textInverse)
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.brand)
        .clipShape(Capsule())
        .trakkeControlShadow()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 80)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(reduceMotion ? nil : .default) {
                viewModel.completionMessage = nil
            }
        }
    }
}
