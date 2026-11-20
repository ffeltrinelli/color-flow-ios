import ColorFlowCore
import SwiftUI

struct BoardAphorism: View {
    let aphorism: Aphorism
    let size: CGFloat
    let revealedFraction: Double
    let reducedMotion: Bool

    var body: some View {
        VStack(spacing: size * 0.025) {
            Text("“")
                .font(.system(size: size * 0.14, design: .serif))
                .foregroundStyle(Color(red: 1, green: 0.79, blue: 0.31))
                .frame(height: size * 0.09)
            Text(aphorism.text)
                .font(.system(size: size * 0.071, design: .serif).italic())
                .foregroundStyle(Color(red: 1, green: 0.96, blue: 0.84))
            Text(aphorism.author)
                .font(.system(size: size * 0.037, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.78, green: 0.72, blue: 0.62))
        }
        .multilineTextAlignment(.center)
        .frame(width: size * 0.86)
        .frame(width: size, height: size)
        .opacity(revealedFraction)
        .animation(reducedMotion || revealedFraction == 0 ? nil : .easeOut(duration: 0.1),
                   value: revealedFraction)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}

struct AphorismCard: View {
    let aphorism: Aphorism
    let maxHeight: CGFloat
    private let teal = Color(red: 0.14, green: 0.40, blue: 0.41)
    private let gold = Color(red: 0.77, green: 0.64, blue: 0.43)

    var body: some View {
        ViewThatFits(in: .vertical) {
            content.fixedSize(horizontal: false, vertical: true)
            ScrollView { content }
                .frame(maxHeight: maxHeight)
        }
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.99, blue: 0.95),
                                              Color(red: 0.97, green: 0.91, blue: 0.78)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 15).strokeBorder(gold.opacity(0.55), lineWidth: 1)
                }
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            Text("Aphorism unlocked")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(teal)
            HStack(spacing: 9) {
                Rectangle().fill(gold).frame(width: 28, height: 1)
                Text("“")
                    .font(.system(size: 33, design: .serif))
                    .foregroundStyle(teal)
                    .frame(height: 18)
                Rectangle().fill(gold).frame(width: 28, height: 1)
            }
            .accessibilityHidden(true)
            Text(aphorism.text)
                .font(.system(.title2, design: .serif).italic())
                .accessibilityIdentifier("unlocked-aphorism")
            VStack(spacing: 2) {
                Text(aphorism.author).font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(aphorism.work).font(.system(.footnote, design: .serif).italic())
            }
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}
