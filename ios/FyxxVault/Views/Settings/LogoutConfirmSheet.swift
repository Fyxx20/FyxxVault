import SwiftUI

struct LogoutConfirmSheet: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator space
            Spacer().frame(height: 8)

            // Icon
            ZStack {
                Circle()
                    .fill(FVColor.danger.opacity(0.10))
                    .frame(width: 64, height: 64)

                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FVColor.danger)
            }
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.8)

            // Title
            Text(String(localized: "logout.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Message
            VStack(spacing: 4) {
                Text(String(localized: "logout.message"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.smoke)
                    .multilineTextAlignment(.center)

                Text(String(localized: "logout.data.safe"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.ash)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.square")
                            .font(.system(size: 14, weight: .semibold))
                        Text(String(localized: "logout.button.confirm"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(FVColor.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text(String(localized: "logout.button.cancel"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(FVColor.smoke)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .background(Color(red: 0.08, green: 0.09, blue: 0.14))
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}
