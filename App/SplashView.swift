import SwiftUI

struct SplashView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 22) {
                Image("GameIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(geometry.size.width * 0.62, 280))
                    .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Image("GameTitle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(geometry.size.width * 0.84, 360))
                        .accessibilityLabel("Color Flow")
                        .accessibilityIdentifier("splash-title")
                    Text("for Luisa")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.88, blue: 0.94))
                        .accessibilityIdentifier("splash-subtitle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.067, green: 0.094, blue: 0.153).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splash")
        .preferredColorScheme(.dark)
    }
}
