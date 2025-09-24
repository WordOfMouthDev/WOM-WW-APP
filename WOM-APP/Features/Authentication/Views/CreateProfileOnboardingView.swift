import SwiftUI

struct CreateProfileOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var phoneNumber = ""
    @State private var fullName = ""
    @State private var username = ""
    @State private var isUsernameAvailable = true
    @State private var isCheckingUsername = false
    @State private var usernameCheckTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    // Responsive sizing properties
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var buttonHeight: CGFloat {
        isIPad ? 72 : 64
    }
    
    private var formMaxWidth: CGFloat {
        isIPad ? 500 : .infinity
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
    
    private var isFormValid: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isUsernameAvailable &&
        !isCheckingUsername
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "#fcf4f2").ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with profile icon
                        VStack(spacing: isIPad ? 32 : 24) {
                            Spacer()
                                .frame(height: isIPad ? 80 : 60)
                            
                            // Profile icon
                            ZStack {
                                // Background circle
                                Circle()
                                    .fill(Color(hex: "#f4e4e1"))
                                    .frame(width: iconSize + 40, height: iconSize + 40)
                                
                                // Profile icon
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: iconSize * 0.8, weight: .regular))
                                    .foregroundColor(Color(hex: "#e8a598"))
                            }
                            .frame(height: iconSize + 40)
                            
                            // Title and subtitle
                            VStack(spacing: isIPad ? 16 : 12) {
                                Text("Create Profile")
                                    .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .multilineTextAlignment(.center)
                                
                                Text("This is how your friends will find you")
                                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalPadding)
                            }
                            
                            Spacer()
                                .frame(height: isIPad ? 40 : 32)
                        }
                        
                        // Form Fields
                        VStack(spacing: isIPad ? 24 : 20) {
                            // Phone Number Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone #")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                
                                TextField("Enter your phone #", text: $phoneNumber)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .autocorrectionDisabled()
                                    .padding(isIPad ? 20 : 16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .font(.system(size: isIPad ? 18 : 16))
                            }
                            
                            // Full Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                
                                TextField("Enter your full name", text: $fullName)
                                    .textContentType(.name)
                                    .autocorrectionDisabled()
                                    .padding(isIPad ? 20 : 16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .font(.system(size: isIPad ? 18 : 16))
                            }
                            
                            // Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                
                                TextField("Enter a unique username", text: $username)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(isIPad ? 20 : 16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(usernameFieldBorderColor, lineWidth: 1)
                                    )
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    .font(.system(size: isIPad ? 18 : 16))
                                    .onChange(of: username) { _, _ in
                                        checkUsernameAvailability()
                                    }
                                
                                // Username validation feedback
                                if !username.isEmpty {
                                    HStack(spacing: 8) {
                                        if isCheckingUsername {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Image(systemName: isUsernameAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(isUsernameAvailable ? .green : .red)
                                                .font(.system(size: isIPad ? 16 : 14))
                                        }
                                        
                                        Text(usernameStatusText)
                                            .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                                            .foregroundColor(isUsernameAvailable ? .green : .red)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 40 : 32)
                        
                        // Error Message
                        if let error = onboardingViewModel.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.bottom, isIPad ? 20 : 16)
                        }
                        
                        // Buttons
                        HStack(spacing: isIPad ? 20 : 16) {
                            // Back Button
                            Button {
                                // Go back to previous onboarding step
                                dismiss()
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
                                completeProfileStep()
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
                                .background(isFormValid ? Color(hex: "#b9bea0") : Color.gray.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: isFormValid ? Color(hex: "#b9bea0").opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                            }
                            .disabled(!isFormValid || onboardingViewModel.isLoading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                            .frame(height: isIPad ? 60 : 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var usernameFieldBorderColor: Color {
        if username.isEmpty {
            return Color.black.opacity(0.1)
        } else if isCheckingUsername {
            return Color.blue.opacity(0.5)
        } else {
            return isUsernameAvailable ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
        }
    }
    
    private var usernameStatusText: String {
        if isCheckingUsername {
            return "Checking availability..."
        } else {
            return isUsernameAvailable ? "Username is available" : "Username is already taken"
        }
    }
    
    private func checkUsernameAvailability() {
        // Cancel previous timer
        usernameCheckTimer?.invalidate()
        
        // Don't check empty usernames
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isUsernameAvailable = true
            isCheckingUsername = false
            return
        }
        
        // Validate username format
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidUsernameFormat(trimmedUsername) else {
            isUsernameAvailable = false
            isCheckingUsername = false
            return
        }
        
        // Set timer to check availability after user stops typing
        usernameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task {
                await checkUsernameInFirebase(trimmedUsername)
            }
        }
    }
    
    private func isValidUsernameFormat(_ username: String) -> Bool {
        // Username should be 3-20 characters, alphanumeric and underscores only
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    @MainActor
    private func checkUsernameInFirebase(_ username: String) async {
        isCheckingUsername = true
        
        do {
            let isAvailable = try await onboardingViewModel.checkUsernameAvailability(username)
            isUsernameAvailable = isAvailable
        } catch {
            // If check fails, assume username might be taken
            isUsernameAvailable = false
        }
        
        isCheckingUsername = false
    }
    
    private func completeProfileStep() {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        onboardingViewModel.completeProfileStep(
            phoneNumber: trimmedPhone,
            fullName: trimmedName,
            username: trimmedUsername
        )
    }
}

#Preview {
    CreateProfileOnboardingView()
        .environmentObject(OnboardingViewModel())
}
