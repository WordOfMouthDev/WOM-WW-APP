import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isRegistering = false
    @State private var showResetSent = false
    @State private var animateForm = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var confirmPassword = ""
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    // Responsive sizing properties - matching PreAuthView
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
    
    private var fieldSpacing: CGFloat {
        isIPad ? 20 : 16
    }
    
    private var sectionSpacing: CGFloat {
        isIPad ? 32 : 24
    }
    
    // Simplified layout system that accounts for keyboard
    private var minTopOffset: CGFloat {
        // Minimum distance from top to prevent collision with background image
        isIPad ? 280 : 160
    }
    
    private var availableHeight: CGFloat {
        // Available space accounting for keyboard
        UIScreen.main.bounds.height - keyboardHeight - minTopOffset - 100 // 100 for safe margins
    }
    
    private var shouldUseCompactLayout: Bool {
        // Use compact layout when keyboard is visible or space is limited
        keyboardHeight > 0 || availableHeight < (isRegistering ? 400 : 300)
    }
    
    // Password strength calculation
    private var passwordStrength: (score: Int, label: String, color: Color) {
        let password = auth.password
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...1:
            return (score, "Weak", Color.red)
        case 2:
            return (score, "Fair", Color.orange)
        case 3:
            return (score, "Good", Color.yellow)
        case 4:
            return (score, "Strong", Color.green)
        case 5:
            return (score, "Very Strong", Color.blue)
        default:
            return (0, "Weak", Color.red)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Solid background color
                Color(hex: "#fcf4f2").ignoresSafeArea()

                // Layer 2: Static header image, pinned to the top
                Image("AuthBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .overlay {
                        Color.black.opacity(0.3) // Adjust opacity for desired darkness
                    }
                    .mask(
                        LinearGradient(gradient: Gradient(stops: [
                            .init(color: .black, location: 0),   // Top of the image is fully opaque
                            .init(color: .black, location: 0.7), // Start fading around 70% down
                            .init(color: .clear, location: 1)    // Bottom of the image is fully transparent
                        ]), startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        Image("LOGO")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .colorInvert()
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 0)
                            .offset(y: 20)
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()

                // Layer 3: Keyboard-aware scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        // Dynamic spacer to push content below image
                        Spacer()
                            .frame(height: shouldUseCompactLayout ? minTopOffset - 50 : minTopOffset + 50)
                        
                        // Form Content
                        VStack(spacing: shouldUseCompactLayout ? (sectionSpacing * 0.75) : sectionSpacing) {
                            // Back button and Header section
                            VStack(spacing: 16) {
                                // Back button and title using ZStack for proper centering
                                ZStack {
                                    // Title text - centered on screen
                                    Text(isRegistering ? "Create Account" : "Sign In")
                                        .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "#4c5c35"))
                                        .frame(maxWidth: .infinity) // Center the title
                                    
                                    // Back button - positioned on the leading edge
                                    HStack {
                                        Button {
                                            print("Content back button tapped!")
                                            dismiss()
                                            presentationMode.wrappedValue.dismiss()
                                        } label: {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: isIPad ? 48 : 44, height: isIPad ? 48 : 44)
                                                .background(Color(hex: "#b9bea0"))
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                .shadow(color: Color(hex: "#b9bea0").opacity(0.4), radius: 8, x: 0, y: 4)
                                        }
                                        Spacer()
                                    }
                                }
                                
                                // Subtitle text below
                                Text(isRegistering ? "Join the community and start your journey" : "Sign in to continue your journey")
                                    .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#7d8b68"))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity) // Center the subtitle
                            }
                    
                    // Form Fields
                    VStack(spacing: fieldSpacing) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(Color(hex: "#646b4e"))
                            
                            TextField("Enter your email", text: $auth.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
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
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                .foregroundColor(Color(hex: "#646b4e"))
                            
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Enter your password", text: $auth.password)
                                            .textContentType(.password)
                                    } else {
                                        SecureField("Enter your password", text: $auth.password)
                                            .textContentType(.password)
                                    }
                                }
                                .font(.system(size: isIPad ? 18 : 16))
                                .foregroundColor(Color(hex: "#4c5c35"))
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(Color(hex: "#646b4e"))
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(isIPad ? 20 : 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Password strength meter (only show when registering and password is not empty)
                            if isRegistering && !auth.password.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Password Strength:")
                                            .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                                            .foregroundColor(Color(hex: "#646b4e"))
                                        
                                        Text(passwordStrength.label)
                                            .font(.system(size: isIPad ? 14 : 12, weight: .semibold))
                                            .foregroundColor(passwordStrength.color)
                                    }
                                    
                                    // Strength meter bars
                                    HStack(spacing: 4) {
                                        ForEach(0..<5, id: \.self) { index in
                                            RoundedRectangle(cornerRadius: 2)
                                                .frame(height: 4)
                                                .foregroundColor(index < passwordStrength.score ? passwordStrength.color : Color.gray.opacity(0.3))
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        if isRegistering {
                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#646b4e"))
                                
                                HStack {
                                    Group {
                                        if showConfirmPassword {
                                            TextField("Type password again", text: $confirmPassword)
                                                .textContentType(.password)
                                        } else {
                                            SecureField("Type password again", text: $confirmPassword)
                                                .textContentType(.password)
                                        }
                                    }
                                    .font(.system(size: isIPad ? 18 : 16))
                                    .foregroundColor(Color(hex: "#4c5c35"))
                                    
                                    Button {
                                        showConfirmPassword.toggle()
                                    } label: {
                                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Color(hex: "#646b4e"))
                                            .frame(width: 20, height: 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(isIPad ? 20 : 16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(confirmPassword.isEmpty || confirmPassword == auth.password ? Color.black.opacity(0.1) : Color.red.opacity(0.5), lineWidth: 1)
                                )
                                
                                // Password match indicator
                                if !confirmPassword.isEmpty && confirmPassword != auth.password {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: isIPad ? 14 : 12))
                                        Text("Passwords don't match")
                                            .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 4)
                                } else if !confirmPassword.isEmpty && confirmPassword == auth.password {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: isIPad ? 14 : 12))
                                        Text("Passwords match")
                                            .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                                            .foregroundColor(.green)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
                    // Error Message
                    if let error = auth.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Primary Action Button
                    Button(action: primaryAction) {
                        HStack {
                            Spacer()
                            Text(isRegistering ? "Create Account" : "Sign In")
                                .font(.system(size: isIPad ? 20 : 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: isIPad ? 20 : 17, weight: .semibold))
                            Spacer()
                        }
                        .padding(isIPad ? 20 : 16)
                        .frame(height: buttonHeight)
                        .frame(maxWidth: formMaxWidth)
                        .foregroundColor(.white)
                        .background(Color(hex: "#b9bea0")) // sage
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(hex: "#b9bea0").opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .disabled(auth.isLoading)
                    
                    // Toggle Auth Mode
                    Button(isRegistering ? "Have an account? Sign in" : "New here? Create account") {
                        withAnimation(.easeInOut) {
                            isRegistering.toggle()
                        }
                    }
                    .font(.system(size: isIPad ? 17 : 15, weight: .medium))
                    .foregroundColor(Color(hex: "#50603a")) // leaf
                    
                        }
                        .frame(maxWidth: formMaxWidth)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, shouldUseCompactLayout ? (isIPad ? 24 : 20) : (isIPad ? 40 : 32))
                        .background(Color(hex: "#fcf4f2").opacity(0.95))
                        .cornerRadius(24)
                        
                        // Bottom spacer for keyboard
                        Spacer()
                            .frame(height: max(100, keyboardHeight + 20))
                    }
                }
                .frame(height: geometry.size.height)
            }
        }
        .onAppear {
            addKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .navigationBarHidden(true)
    }

    private func primaryAction() {
        if isRegistering { auth.register() } else { auth.signIn() }
    }
    
    // Keyboard handling functions
    private func addKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
