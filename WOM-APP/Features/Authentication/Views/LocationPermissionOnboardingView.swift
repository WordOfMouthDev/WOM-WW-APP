import SwiftUI
import CoreLocation
import MapKit
import UIKit

struct LocationPermissionOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var showingMapPicker = false
    @State private var selectedMapLocation: CLLocationCoordinate2D?
    @State private var selectedLocationAddress = ""
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
            return max(60, (UIScreen.main.bounds.width - 500) / 2)
        } else {
            return max(24, UIScreen.main.bounds.width * 0.06)
        }
    }
    
    private var iconSize: CGFloat {
        isIPad ? 120 : 100
    }
    
    private var hasLocation: Bool {
        locationManager.location != nil || selectedMapLocation != nil
    }
    
    private var locationPermissionStatus: LocationPermissionStatus {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways:
            return .granted
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
    
    enum LocationPermissionStatus {
        case notDetermined, granted, denied
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "#fcf4f2").ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with location icon
                        VStack(spacing: isIPad ? 32 : 24) {
                            Spacer()
                                .frame(height: isIPad ? 80 : 60)
                            
                            // Location icon in circle
                            ZStack {
                                // Background circle
                                Circle()
                                    .stroke(Color(hex: "#e8a598"), lineWidth: 3)
                                    .frame(width: iconSize + 20, height: iconSize + 20)
                                
                                // Navigation arrow icon
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: iconSize * 0.5, weight: .medium))
                                    .foregroundColor(Color(hex: "#e8a598"))
                                    .rotationEffect(.degrees(45)) // Point northeast like in your design
                            }
                            .frame(height: iconSize + 40)
                            
                            // Title and subtitle
                            VStack(spacing: isIPad ? 16 : 12) {
                                Text("Enable Location Services")
                                    .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                
                                Text("We want to find they spots you already love")
                                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalPadding)
                            }
                            
                            Spacer()
                                .frame(height: isIPad ? 40 : 32)
                        }
                        
                        // Permission status and actions
                        VStack(spacing: isIPad ? 24 : 20) {
                            // Show different content based on permission status
                            switch locationPermissionStatus {
                            case .notDetermined:
                                // Show permission request
                                permissionRequestView
                                
                            case .granted:
                                // Show success state
                                permissionGrantedView
                                
                            case .denied:
                                // Show map picker option
                                permissionDeniedView
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 40 : 32)
                        
                        // Error Message
                        if let error = onboardingViewModel.errorMessage ?? locationManager.errorMessage,
                           !error.isEmpty {
                            Text(error)
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.bottom, isIPad ? 20 : 16)
                        }
                        
                        // Bottom buttons
                        HStack(spacing: isIPad ? 20 : 16) {
                            // Back Button
                            Button {
                                // Navigate back to previous onboarding step
                                onboardingViewModel.goBackToStep("service_selection")
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#4c5c35"))
                                .frame(height: buttonHeight)
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "#e5e5e5"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Continue Button
                            Button {
                                completeLocationStep()
                            } label: {
                                HStack {
                                    Text("Continue")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(height: buttonHeight)
                                .frame(maxWidth: .infinity)
                                .background(hasLocation ? Color(hex: "#e8a598") : Color.gray.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: hasLocation ? Color(hex: "#e8a598").opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                            }
                            .disabled(!hasLocation || onboardingViewModel.isLoading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 60 : 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingMapPicker) {
            MapLocationPickerView(
                selectedLocation: $selectedMapLocation,
                selectedAddress: $selectedLocationAddress,
                initialRegion: selectedMapLocation != nil ? 
                    MKCoordinateRegion(
                        center: selectedMapLocation!,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ) : nil
            )
        }
        .onAppear {
            // Automatically request permission when view appears if not determined
            if locationManager.authorizationStatus == .notDetermined {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    locationManager.requestLocationPermission()
                }
            }
        }
    }
    
    @ViewBuilder
    private var permissionRequestView: some View {
        VStack(spacing: isIPad ? 24 : 20) {
            // Information text
            VStack(spacing: 12) {
                Text("We need your location to find services near you")
                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                    .foregroundColor(Color(hex: "#4c5c35"))
                    .multilineTextAlignment(.center)
                
                Text("Your location will be used to recommend nearby services and improve your experience")
                    .font(.system(size: isIPad ? 16 : 14, weight: .regular))
                    .foregroundColor(Color(hex: "#7d8b68"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            // Action buttons
            VStack(spacing: isIPad ? 16 : 12) {
                // Enable Location button
                Button {
                    locationManager.requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: "location")
                            .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                        Text("Enable Location Services")
                            .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonHeight - 10)
                    .background(Color(hex: "#e8a598"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(hex: "#e8a598").opacity(0.4), radius: 4, x: 0, y: 2)
                }
                
                // Manual selection button
                Button {
                    showingMapPicker = true
                } label: {
                    HStack {
                        Image(systemName: "map")
                            .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                        Text("Select Location Manually")
                            .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#4c5c35"))
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonHeight - 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#e8a598"), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var permissionGrantedView: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: isIPad ? 24 : 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Access Granted")
                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#4c5c35"))
                    
                    if let placemark = locationManager.placemark {
                        Text(formatPlacemark(placemark))
                            .font(.system(size: isIPad ? 16 : 14, weight: .regular))
                            .foregroundColor(Color(hex: "#7d8b68"))
                    } else if locationManager.isLoading {
                        Text("Getting your location...")
                            .font(.system(size: isIPad ? 16 : 14, weight: .regular))
                            .foregroundColor(Color(hex: "#7d8b68"))
                    }
                }
                
                Spacer()
            }
            .padding(isIPad ? 20 : 16)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Permission denied message
            HStack {
                Image(systemName: "location.slash")
                    .foregroundColor(Color(hex: "#e8a598"))
                    .font(.system(size: isIPad ? 24 : 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Access Denied")
                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#4c5c35"))
                    
                    Text("Please select your location manually")
                        .font(.system(size: isIPad ? 16 : 14, weight: .regular))
                        .foregroundColor(Color(hex: "#7d8b68"))
                }
                
                Spacer()
            }
            .padding(isIPad ? 20 : 16)
            .background(Color(hex: "#e8a598").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "#e8a598").opacity(0.3), lineWidth: 1)
            )
            
            // Map picker button
            Button {
                showingMapPicker = true
            } label: {
                HStack {
                    Image(systemName: "map")
                        .font(.system(size: isIPad ? 20 : 18, weight: .medium))
                    
                    Text(selectedMapLocation == nil ? "Select Location on Map" : "Change Location")
                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight - 20)
                .background(Color(hex: "#e8a598"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color(hex: "#e8a598").opacity(0.4), radius: 4, x: 0, y: 2)
            }
            
            // Show selected location
            if let coordinate = selectedMapLocation {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: isIPad ? 20 : 18))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Location")
                            .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#4c5c35"))
                        
                        Text(selectedLocationAddress.isEmpty ? 
                            String(format: "Lat: %.4f, Lng: %.4f", coordinate.latitude, coordinate.longitude) : 
                            selectedLocationAddress)
                            .font(.system(size: isIPad ? 14 : 12, weight: .regular))
                            .foregroundColor(Color(hex: "#7d8b68"))
                    }
                    
                    Spacer()
                }
                .padding(isIPad ? 16 : 12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        if let locality = placemark.locality { components.append(locality) }
        if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
        return components.joined(separator: ", ")
    }
    
    private func completeLocationStep() {
        var userLocation: UserLocation?
        
        // Create location from either GPS or manual selection
        if let coordinate = selectedMapLocation {
            userLocation = UserLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                isPermissionGranted: false
            )
        } else if locationManager.location != nil {
            userLocation = locationManager.createUserLocation()
        }
        
        guard let finalLocation = userLocation else {
            onboardingViewModel.errorMessage = "Please select a location to continue"
            return
        }
        
        onboardingViewModel.completeLocationStep(finalLocation)
    }
}

struct MapLocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedAddress: String
    let initialRegion: MKCoordinateRegion?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showingSearchResults = false
    @State private var currentAddress = ""
    @Environment(\.dismiss) private var dismiss
    
    private var centerCoordinate: CLLocationCoordinate2D {
        region.center
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search for a location...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                searchForLocation()
                            }
                            .onChange(of: searchText) { _, newValue in
                                if newValue.isEmpty {
                                    searchResults = []
                                    showingSearchResults = false
                                }
                            }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    
                    // Selected address display
                    if !currentAddress.isEmpty {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(currentAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color(.systemBackground))
                
                ZStack {
                    // Custom Map View
                    InteractiveMapView(region: $region) { coordinate in
                        updateAddressForCoordinate(coordinate)
                    }
                    
                    // Center pin with drop shadow
                    VStack {
                        Spacer()
                        ZStack {
                            // Shadow
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.black.opacity(0.3))
                                .offset(x: 2, y: 2)
                            
                            // Main pin
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    
                    // Search results overlay
                    if showingSearchResults && !searchResults.isEmpty {
                        VStack {
                            Spacer()
                            
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(searchResults, id: \.self) { item in
                                        SearchResultRow(item: item) {
                                            selectSearchResult(item)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .frame(maxHeight: 200)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 8)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedLocation = centerCoordinate
                        if currentAddress.isEmpty {
                            selectedAddress = String(format: "Lat: %.4f, Lng: %.4f", centerCoordinate.latitude, centerCoordinate.longitude)
                        } else {
                            selectedAddress = currentAddress
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Use initialRegion if provided (previously selected location)
            if let initialRegion = initialRegion {
                region = initialRegion
            } else if let userLocation = LocationManager.shared.location {
                // Otherwise use user's current location as starting point
                region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            // Update address for initial location
            updateAddressForCoordinate(region.center)
        }
    }
    
    private func searchForLocation() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    searchResults = response.mapItems
                    showingSearchResults = !searchResults.isEmpty
                } else {
                    searchResults = []
                    showingSearchResults = false
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        let address = formatMapItem(item)
        currentAddress = address
        searchText = item.name ?? ""
        showingSearchResults = false
        searchResults = []
    }
    
    private func scheduleAddressUpdate() {
        // Simplified - just update immediately when called
        updateAddressForCoordinate(region.center)
    }
    
    private func updateAddressForCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self.currentAddress = self.formatPlacemark(placemark)
                }
            }
        }
    }
    
    private func formatMapItem(_ item: MKMapItem) -> String {
        var components: [String] = []
        
        if let name = item.name {
            components.append(name)
        }
        
        if let locality = item.placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = item.placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "mappin.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let address = formatAddress(item.placemark) {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatAddress(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// Custom UIKit-based Map View for smooth interaction
struct InteractiveMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let onRegionChange: ((CLLocationCoordinate2D) -> Void)?
    
    init(region: Binding<MKCoordinateRegion>, onRegionChange: ((CLLocationCoordinate2D) -> Void)? = nil) {
        self._region = region
        self.onRegionChange = onRegionChange
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.isUserInteractionEnabled = true
        mapView.showsUserLocation = false
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update if the region has changed significantly to avoid conflicts
        let currentCenter = mapView.region.center
        let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
            .distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude))
        
        if distance > 100 { // Only update if moved more than 100 meters
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: InteractiveMapView
        private var updateTimer: Timer?
        
        init(_ parent: InteractiveMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update the binding when user moves the map
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
            
            // Debounced address update
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.parent.onRegionChange?(mapView.region.center)
                }
            }
        }
    }
}

#Preview {
    LocationPermissionOnboardingView()
        .environmentObject(OnboardingViewModel())
}
