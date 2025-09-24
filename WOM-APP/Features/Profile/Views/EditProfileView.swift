import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        ZStack {
                            Circle().fill(Color.secondary.opacity(0.1))
                                .frame(width: 72, height: 72)
                            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else if let urlString = auth.currentUserProfile?.profileImageURL,
                                      let url = URL(string: urlString), !urlString.isEmpty {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            Text("Choose Image")
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    await MainActor.run { self.selectedImageData = data }
                                }
                            }
                        }
                    }

                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                displayName = auth.currentUserProfile?.displayName ?? ""
            }
        }
    }

    private func save() {
        let data = selectedImageData
        auth.updateProfile(newDisplayName: displayName, imageData: data)
        dismiss()
    }
}

#Preview {
    EditProfileView().environmentObject(AuthViewModel())
}
