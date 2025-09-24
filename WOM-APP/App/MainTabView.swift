import SwiftUI
import UIKit

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            FriendsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
        // SwiftUI API for iOS 16+: glass-like background on tab bar
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        // Fallback and finer control via UIKit appearance
        .onAppear(perform: applyGlassTabBarAppearance)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

private func applyGlassTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    appearance.backgroundColor = .clear

    // Optional: subtle separator line for definition
    appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}
