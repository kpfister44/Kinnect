// ABOUTME: Info screen for password management via Sign in with Apple
// ABOUTME: Provides guidance and deep link to iOS Settings app

import SwiftUI

struct ChangePasswordView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.igBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("Your password is managed through Sign in with Apple")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("To change your password, go to Settings → [Your Name] → Password & Security to manage your Apple ID password.")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.igBlue)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
    }
}
