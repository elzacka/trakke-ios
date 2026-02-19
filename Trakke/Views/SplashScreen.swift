import SwiftUI

struct SplashScreen: View {
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.95
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logoSize: CGFloat = 96

    var body: some View {
        ZStack {
            Color.Trakke.background
                .ignoresSafeArea()

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .opacity(opacity)
                .scaleEffect(scale)
        }
        .onAppear {
            if reduceMotion {
                opacity = 1
                scale = 1
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    opacity = 1
                    scale = 1
                }
            }
        }
    }
}
