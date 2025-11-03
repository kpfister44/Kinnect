// ABOUTME: Read-only view displaying user account information
// ABOUTME: Shows email, user ID, and account creation date

import SwiftUI

struct AccountInfoView: View {
    let email: String
    let userId: UUID
    let createdAt: Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(email)
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("User ID")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(userId.uuidString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Created")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(formattedDate)
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account Info")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
    }
}
