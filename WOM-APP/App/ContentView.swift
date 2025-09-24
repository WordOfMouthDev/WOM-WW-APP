//
//  ContentView.swift
//  WOM-WW
//
//  Created by Jonathan Gardner on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                // Check if user needs onboarding
                if let profile = auth.currentUserProfile, !profile.onboardingProgress.isCompleted {
                    OnboardingCoordinatorView()
                        .environmentObject(auth)
                } else {
                    MainTabView()
                }
            } else {
                PreAuthView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
