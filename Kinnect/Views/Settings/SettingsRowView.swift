// ABOUTME: Reusable row component for settings menu items
// ABOUTME: Displays SF Symbol icon with title text in consistent layout

import SwiftUI

struct SettingsRowView: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.igTextPrimary)

            Spacer()
        }
    }
}
