//
//  WOM_WWApp.swift
//  WOM-WW
//
//  Created by Jonathan Gardner on 8/27/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct WOM_WWApp: App {
    @StateObject private var auth = AuthViewModel()
    init() {
        // Configure Firebase with optimized settings
        FirebaseConfig.configure()
        
        // Disable verbose Firebase logging in development
        FirebaseConfig.enableFirestoreLogging(false)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
