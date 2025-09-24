import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showSettings = false
    @State private var showEditProfile = false
    @StateObject private var placesViewModel = PlacesViewModel(repository: FirestorePlacesRepository())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Profile image circle under name/username
                    Group {
                        if let urlString = auth.currentUserProfile?.profileImageURL, !urlString.isEmpty {
                            // Cache-bust the image when profile updates
                            let bust = auth.imageCacheBuster
                            let sep = urlString.contains("?") ? "&" : "?"
                            let composed = bust > 0 ? "\(urlString)\(sep)t=\(bust)" : urlString
                            AsyncImage(url: URL(string: composed)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .padding(.top, 8)

                    // Additional content can go here
                    Spacer(minLength: 12)

                    PlacesSection(
                        state: placesViewModel.state,
                        userId: auth.currentUserProfile?.uid,
                        onRetry: { placesViewModel.retry() },
                        onFindNearby: { handleFindNearby() }
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            }
            .toolbar {
                // Display name with username directly under it in the title area
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        let title = (auth.currentUserProfile?.displayName.isEmpty == false)
                        ? (auth.currentUserProfile?.displayName ?? "Profile")
                        : "Profile"
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        let uname = auth.currentUserProfile?.username ?? ""
                        if !uname.isEmpty {
                            Text("@\(uname)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("@username")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .redacted(reason: .placeholder)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Profile") { showEditProfile = true }
                        Divider()
                        Button(role: .destructive) { auth.logout() } label: { Text("Logout") }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(auth)
            }
            .onAppear { updatePlacesSubscription() }
            .onChange(of: auth.currentUserProfile?.uid) { _ in
                updatePlacesSubscription()
            }
            .onDisappear {
                placesViewModel.stop()
            }
        }
    }

    private func updatePlacesSubscription() {
        guard let uid = auth.currentUserProfile?.uid else {
            placesViewModel.stop()
            return
        }
        placesViewModel.watchPlaces(for: uid)
    }

    private func handleFindNearby() {
        // Placeholder action until nearby search is wired up.
        print("Find businesses near me tapped")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
