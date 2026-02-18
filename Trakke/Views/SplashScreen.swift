import SwiftUI

struct SplashScreen: View {
    @State private var contentOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var scale: Double = 0.95

    private let iconSize: CGFloat = 34
    private let fontSize: CGFloat = 36

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Image("SplashIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.2237))

                    Text("Tråkke")
                        .font(Font.Trakke.brand(size: fontSize))
                        .tracking(1.5)
                        .foregroundStyle(Color.Trakke.brand)
                }
                .opacity(contentOpacity)
                .scaleEffect(scale)

                Text(String(localized: "app.tagline"))
                    .font(.system(size: 13, weight: .light))
                    .tracking(0.5)
                    .foregroundStyle(Color.Trakke.brand.opacity(0.5))
                    .padding(.top, 10)
                    .opacity(taglineOpacity)
            }
            .offset(y: -20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
                scale = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                taglineOpacity = 1
            }
        }
    }
}
