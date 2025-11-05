// ABOUTME: Screen for exporting user data to a downloadable JSON file
// ABOUTME: Explains export contents and presents share sheet when ready

import SwiftUI

struct DataExportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.igBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("Download Your Data")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.igTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("This will export all of your data including:")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Profile information", systemImage: "person.circle")
                        Label("Posts you've shared", systemImage: "photo")
                        Label("Comments you've made", systemImage: "bubble.left")
                        Label("Activity history", systemImage: "bell")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.igTextPrimary)
                    .padding(.leading)

                    Text("The export is delivered as a JSON file that you can save or share for your records.")
                        .font(.system(size: 12))
                        .foregroundColor(.igTextSecondary)
                        .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }

            Section {
                Button {
                    Task {
                        await MainActor.run {
                            showShareSheet = false
                        }
                        await viewModel.exportUserData()
                        if viewModel.exportedDataURL != nil {
                            await MainActor.run {
                                showShareSheet = true
                            }
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Request Data Export")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.igBlue)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Download My Data")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.exportedDataURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { value in
                if !value {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .task {
            if case .authenticated(let userId) = authViewModel.authState {
                viewModel.userId = userId
            }
            await viewModel.fetchAccountInfo()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
