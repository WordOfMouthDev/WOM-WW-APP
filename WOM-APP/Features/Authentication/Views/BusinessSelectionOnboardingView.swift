import SwiftUI
import MapKit
import CoreLocation

struct BusinessSelectionOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var businessSearchManager = BusinessSearchManager()
    @State private var selectedBusinesses: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
        isIPad ? 80 : 60
    }
    
    // Service categories based on user's selected services
    private var businessCategories: [BusinessCategory] {
        guard let selectedServices = onboardingViewModel.selectedServices else { return [] }
        
        return BusinessCategory.allCategories.filter { category in
            selectedServices.contains { service in
                category.matchesService(service)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "#fcf4f2").ignoresSafeArea()
                
                // Main content with padding for bottom buttons
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: isIPad ? 32 : 24) {
                            Spacer()
                                .frame(height: isIPad ? 80 : 60)
                            
                            // Location icon
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#f4e4e1"))
                                    .frame(width: iconSize + 20, height: iconSize + 20)
                                
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: iconSize * 0.6))
                                    .foregroundColor(Color(hex: "#e8a598"))
                            }
                            
                            // Title and subtitle
                            VStack(spacing: isIPad ? 16 : 12) {
                                Text("Select locations you've been to")
                                    .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .multilineTextAlignment(.center)
                                
                                Text("These locations will be stored in your profile")
                                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalPadding)
                            }
                            
                            Spacer()
                                .frame(height: isIPad ? 20 : 16)
                        }
                        
                        // Select All / Clear All buttons
                        HStack {
                            Button("Select All") {
                                selectAllBusinesses()
                            }
                            .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                            .foregroundColor(.blue)
                            
                            Text("•")
                                .foregroundColor(Color(hex: "#7d8b68"))
                            
                            Button("Clear All") {
                                selectedBusinesses.removeAll()
                            }
                            .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                            .foregroundColor(.blue)
                            
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, isIPad ? 24 : 20)
                        
                        // Business list
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Finding businesses near you...")
                                    .font(.system(size: isIPad ? 16 : 14))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                            }
                            .frame(height: 200)
                        } else if businessSearchManager.businesses.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                
                                Text("No businesses found in your area")
                                    .font(.system(size: isIPad ? 16 : 14))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                
                                Button("Try Again") {
                                    searchForBusinesses()
                                }
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            .frame(height: 200)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(businessSearchManager.businesses) { business in
                                    BusinessSelectionRow(
                                        business: business,
                                        isSelected: selectedBusinesses.contains(business.id)
                                    ) {
                                        toggleBusiness(business.id)
                                    }
                                    .onAppear {
                                        // Load more when approaching the end
                                        if business.id == businessSearchManager.businesses.last?.id {
                                            Task {
                                                await businessSearchManager.loadMoreBusinesses()
                                            }
                                        }
                                    }
                                }
                                
                                // Loading more indicator
                                if businessSearchManager.isLoadingMore {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading more businesses...")
                                            .font(.system(size: isIPad ? 14 : 12))
                                            .foregroundColor(Color(hex: "#7d8b68"))
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
                        
                        // Add more button
                        if !businessSearchManager.businesses.isEmpty {
                            Button("Want to add more? Add now") {
                                // TODO: Implement add custom business functionality
                            }
                            .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.top, isIPad ? 24 : 20)
                        }
                        
                        // Error Message
                        if let error = errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.bottom, isIPad ? 20 : 16)
                        }
                        
                        // Bottom padding to account for floating buttons
                        Spacer()
                            .frame(height: buttonHeight + (isIPad ? 100 : 80))
                    }
                }
                
                // Floating bottom buttons overlay
                VStack {
                    Spacer()
                    
                    // Floating button container
                    VStack(spacing: 0) {
                        // Gradient fade to make content behind less visible
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#fcf4f2").opacity(0),
                                Color(hex: "#fcf4f2").opacity(0.8),
                                Color(hex: "#fcf4f2")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        
                        // Button container with background
                        HStack(spacing: isIPad ? 20 : 16) {
                            // Back Button
                            Button {
                                onboardingViewModel.goBackToStep("location_permission")
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#4c5c35"))
                                .frame(maxWidth: .infinity)
                                .frame(height: buttonHeight - 20)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "#e8a598"), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            // Continue Button
                            Button {
                                completeBusinessSelection()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Continue (\(selectedBusinesses.count))")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .frame(height: buttonHeight - 20)
                                .background(Color(hex: "#b9bea0"))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color(hex: "#b9bea0").opacity(0.4), radius: 4, x: 0, y: 2)
                            }
                            .disabled(onboardingViewModel.isLoading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : isIPad ? 40 : 20)
                        .background(Color(hex: "#fcf4f2"))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            searchForBusinesses()
        }
        .onChange(of: onboardingViewModel.selectedServices) { _, _ in
            // Re-search when selected services change
            searchForBusinesses()
        }
        .onChange(of: onboardingViewModel.userLocation) { _, _ in
            // Re-search when user location changes
            searchForBusinesses()
        }
    }
    
    private func toggleBusiness(_ businessId: String) {
        if selectedBusinesses.contains(businessId) {
            selectedBusinesses.remove(businessId)
        } else {
            selectedBusinesses.insert(businessId)
        }
    }
    
    private func selectAllBusinesses() {
        selectedBusinesses = Set(businessSearchManager.businesses.map { $0.id })
    }
    
    private func searchForBusinesses() {
        guard let userLocation = onboardingViewModel.userLocation else {
            errorMessage = "Location not available. Please enable location services."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let coordinate = CLLocationCoordinate2D(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        
        Task {
            do {
                try await businessSearchManager.searchBusinesses(
                    near: coordinate,
                    categories: businessCategories
                )
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to find businesses: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func completeBusinessSelection() {
        let selectedBusinessObjects = businessSearchManager.businesses.filter { business in
            selectedBusinesses.contains(business.id)
        }
        
        onboardingViewModel.completeBusinessSelection(selectedBusinessObjects)
    }
}

struct BusinessSelectionRow: View {
    let business: Business
    let isSelected: Bool
    let action: () -> Void
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isIPad ? 16 : 12) {
                // Business image placeholder
                AsyncImage(url: business.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "building.2")
                                .font(.system(size: isIPad ? 24 : 20))
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: isIPad ? 80 : 60, height: isIPad ? 80 : 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Business info
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.name)
                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#4c5c35"))
                        .multilineTextAlignment(.leading)
                    
                    if let address = business.address {
                        Text(address)
                            .font(.system(size: isIPad ? 14 : 12))
                            .foregroundColor(Color(hex: "#7d8b68"))
                            .multilineTextAlignment(.leading)
                    }
                    
                    if let rating = business.rating {
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .font(.system(size: isIPad ? 12 : 10))
                                    .foregroundColor(.orange)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: isIPad ? 12 : 10))
                                .foregroundColor(Color(hex: "#7d8b68"))
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#e8a598") : Color.white)
                        .frame(width: isIPad ? 32 : 28, height: isIPad ? 32 : 28)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#e8a598"), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: isIPad ? 16 : 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(isIPad ? 16 : 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#e8a598") : Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color(hex: "#e8a598").opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BusinessSelectionOnboardingView()
        .environmentObject(OnboardingViewModel())
}
