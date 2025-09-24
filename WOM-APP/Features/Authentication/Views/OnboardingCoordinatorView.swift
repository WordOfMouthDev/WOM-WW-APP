import SwiftUI
import FirebaseAuth
import Combine

struct OnboardingCoordinatorView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if onboardingViewModel.isOnboardingComplete {
                // Onboarding is complete, refresh user profile to update ContentView
                MainTabView()
                    .onAppear {
                        if let uid = Auth.auth().currentUser?.uid {
                            authViewModel.loadUserProfile(uid: uid)
                        }
                    }
            } else {
                // Show the current onboarding step
                currentOnboardingView
            }
        }
        .environmentObject(onboardingViewModel)
        .onAppear {
            onboardingViewModel.loadOnboardingProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reload onboarding progress when app comes back to foreground
            onboardingViewModel.loadOnboardingProgress()
        }
    }
    
    @ViewBuilder
    private var currentOnboardingView: some View {
        if let currentStep = onboardingViewModel.currentStep {
            switch currentStep.id {
            case "birthday":
                BirthdayOnboardingView()
                    .environmentObject(onboardingViewModel)
                
            case "name_username":
                CreateProfileOnboardingView()
                    .environmentObject(onboardingViewModel)
                
            case "service_selection":
                ServiceSelectionOnboardingView()
                    .environmentObject(onboardingViewModel)
                
            case "location_permission":
                LocationPermissionOnboardingView()
                    .environmentObject(onboardingViewModel)
                
            case "business_selection":
                BusinessSelectionOnboardingView()
                    .environmentObject(onboardingViewModel)
                
            default:
                // Fallback to first incomplete step
                BirthdayOnboardingView()
                    .environmentObject(onboardingViewModel)
            }
        } else {
            // All steps complete, sho w main content
            MainTabView()
                .onAppear {
                    if let uid = Auth.auth().currentUser?.uid {
                        authViewModel.loadUserProfile(uid: uid)
                    }
                }
        }
    }
}

// Placeholder views for other onboarding steps

struct ServiceSelectionOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var selectedServices: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    // Responsive sizing properties
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var buttonHeight: CGFloat {
        isIPad ? 72 : 64
    }
    
    private var horizontalPadding: CGFloat {
        if isIPad {
            return max(60, (UIScreen.main.bounds.width - 600) / 2)
        } else {
            return max(24, UIScreen.main.bounds.width * 0.06)
        }
    }
    
    private var iconSize: CGFloat {
        isIPad ? 120 : 100
    }
    
    private var isValidSelection: Bool {
        selectedServices.count >= 3
    }
    
    // Grid layout
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "#fcf4f2").ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with shop icon
                        VStack(spacing: isIPad ? 32 : 24) {
                            Spacer()
                                .frame(height: isIPad ? 80 : 60)
                            
                            // Shop icon with scalloped awning
                            ZStack {
                                // Background circle
                                Circle()
                                    .fill(Color(hex: "#f4e4e1"))
                                    .frame(width: iconSize + 40, height: iconSize + 40)
                                
                                // Shop icon from asset
                                Image("ShopIcon")
                                    .resizable()
                                    .renderingMode(.template) // Treat the image as a mask
                                    .foregroundColor(Color(hex: "#e8a598")) // Apply the color to the mask
                                    .scaledToFit()
                                    .frame(width: iconSize * 0.9, height: iconSize * 0.9)

                            }
                            .frame(height: iconSize + 40)
                            
                            // Title and subtitle
                            VStack(spacing: isIPad ? 16 : 12) {
                                Text("Select Services you use")
                                    .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .multilineTextAlignment(.center)
                                
                                Text("We want to make you a perfect experience")
                                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalPadding)
                            }
                            
                            Spacer()
                                .frame(height: isIPad ? 40 : 32)
                        }
                        
                        // Services Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Service.allServices) { service in
                                ServiceSelectionButton(
                                    service: service,
                                    isSelected: selectedServices.contains(service.id)
                                ) {
                                    toggleService(service.id)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 40 : 32)
                        
                        // Selection count feedback
                        VStack(spacing: 8) {
                            Text("Select at least 3 services")
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(isValidSelection ? Color(hex: "#7d8b68") : Color(hex: "#e8a598"))
                            
                            Text("\(selectedServices.count) selected")
                                .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                                .foregroundColor(Color(hex: "#7d8b68"))
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 24 : 20)
                        
                        // Error Message
                        if let error = onboardingViewModel.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.bottom, isIPad ? 20 : 16)
                        }
                        
                        // Continue Button
                        Button {
                            completeServiceSelection()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Continue")
                                    .font(.system(size: isIPad ? 20 : 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isIPad ? 20 : 17, weight: .semibold))
                                Spacer()
                            }
                            .padding(isIPad ? 20 : 16)
                            .frame(height: buttonHeight)
                            .foregroundColor(.white)
                            .background(isValidSelection ? Color(hex: "#b9bea0") : Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: isValidSelection ? Color(hex: "#b9bea0").opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isValidSelection || onboardingViewModel.isLoading)
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 60 : 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func toggleService(_ serviceId: String) {
        if selectedServices.contains(serviceId) {
            selectedServices.remove(serviceId)
        } else {
            selectedServices.insert(serviceId)
        }
    }
    
    private func completeServiceSelection() {
        onboardingViewModel.completeServiceSelection(Array(selectedServices))
    }
}

struct ServiceSelectionButton: View {
    let service: Service
    let isSelected: Bool
    let action: () -> Void
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var buttonHeight: CGFloat {
        isIPad ? 52 : 44
    }
    
    var body: some View {
        Button(action: action) {
            Text(service.name)
                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#4c5c35"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .background(isSelected ? Color(hex: "#b9bea0") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color(hex: "#b9bea0") : Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: isSelected ? Color(hex: "#b9bea0").opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// LocationPermissionOnboardingView is now in its own file

#Preview {
    OnboardingCoordinatorView()
        .environmentObject(AuthViewModel())
}
