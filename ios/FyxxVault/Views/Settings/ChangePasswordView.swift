import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "key.rotation")
                        .font(.system(size: 40))
                        .foregroundStyle(FVColor.cyan)
                        .padding(.top, 10)

                    Text("Changer le mot de passe maître")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if success {
                        Label("Mot de passe changé avec succès.", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(FVColor.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fvGlass()
                    } else {
                        VStack(spacing: 12) {
                            FVTextField(title: "Mot de passe actuel", text: $currentPassword, secure: true)
                            FVTextField(title: "Nouveau mot de passe", text: $newPassword, secure: true)

                            if !newPassword.isEmpty {
                                passwordRequirements
                            }

                            FVTextField(title: "Confirmer le nouveau mot de passe", text: $confirmPassword, secure: true)

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(FVColor.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            FVButton(title: "Changer le mot de passe") {
                                if let error = authManager.changeMasterPassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                    confirmPassword: confirmPassword
                                ) {
                                    errorMessage = error
                                } else {
                                    success = true
                                    currentPassword = ""
                                    newPassword = ""
                                    confirmPassword = ""
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .navigationTitle("Changer le mot de passe")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
        }
    }

    var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            FVRequirementRow(label: "12 caractères minimum", met: newPassword.count >= 12)
            FVRequirementRow(label: "1 majuscule", met: newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil)
            FVRequirementRow(label: "1 chiffre", met: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
            FVRequirementRow(label: "1 caractère spécial", met: newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
