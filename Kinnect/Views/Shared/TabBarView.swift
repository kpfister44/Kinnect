//
//  TabBarView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .feed

    enum Tab {
        case feed
        case search
        case upload
        case activity
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            FeedView()
                .tabItem {
                    Image(systemName: selectedTab == .feed ? "house.fill" : "house")
                    Text("Feed")
                }
                .tag(Tab.feed)

            // Search Tab
            SearchView()
                .tabItem {
                    Image(systemName: selectedTab == .search ? "magnifyingglass" : "magnifyingglass")
                    Text("Search")
                }
                .tag(Tab.search)

            // Upload Tab
            UploadView()
                .tabItem {
                    Image(systemName: selectedTab == .upload ? "plus.square.fill" : "plus.square")
                    Text("Upload")
                }
                .tag(Tab.upload)

            // Activity Tab
            ActivityView()
                .tabItem {
                    Image(systemName: selectedTab == .activity ? "heart.fill" : "heart")
                    Text("Activity")
                }
                .tag(Tab.activity)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == .profile ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .tint(.igBlack) // Instagram uses black for selected tab items
    }
}

#Preview {
    TabBarView()
}
