//
//  SearchView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)

                    Text("Search for friends")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.igTextPrimary)

                    Text("Find and follow your friends")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search users")
        }
    }
}

#Preview {
    SearchView()
}
