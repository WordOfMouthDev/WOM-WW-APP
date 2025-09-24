import SwiftUI
import AuthenticationServices

struct PreAuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.openURL) private var openURL

    @State private var showEmailSignIn = false

    // Exact background color from spec (#FCF4F2)
    private let surfaceColor = Color(red: 252/255, green: 244/255, blue: 242/255)
    private let emailColor = Color(hex: "#b9bea0")   // sage green to match other buttons

    // Replace with your real URLs
    private let termsURL = URL(string: "https://example.com/terms")!
    private let privacyURL = URL(string: "https://example.com/privacy")!
    
    // Responsive sizing properties
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var buttonHeight: CGFloat {
        isIPad ? 72 : 64
    }
    
    private var buttonMaxWidth: CGFloat {
        isIPad ? 500 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        if isIPad {
            return max(60, (UIScreen.main.bounds.width - 500) / 2)
        } else {
            return max(24, UIScreen.main.bounds.width * 0.06)
        }
    }
    
    private var buttonHorizontalPadding: CGFloat {
        isIPad ? 28 : 20
    }
    
    private var buttonSpacing: CGFloat {
        isIPad ? 24 : 20
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Base background color
                surfaceColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Collage header pinned to the top (gradient already in asset)
                    ZStack(alignment: .center) {
                        Image("PreAuthBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 420)
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
                            .clipped()
                            .edgesIgnoringSafeArea(.top)
                            

                        // Brand mark in the center; prefers a LOGO asset if present
                        Group {
                            if let ui = UIImage(named: "LOGO") {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 250)
                                    .colorInvert()
                                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 0)
                                    
                            } else {
                                Text("WOM")
                                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                                    .kerning(2)
                                    .foregroundStyle(.white)
                            }
                        }
                        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
                        .offset(y: 0)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    // Buttons and footer
                    VStack(spacing: buttonSpacing) {
                        emailButton
                        googleButton
                        appleButton
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .offset(y: -32)
                    
                    Spacer()
                    
                    footer
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 28)
                }
            }
            .navigationDestination(isPresented: $showEmailSignIn) {
                AuthView()
            }
        }
    }

    private var emailButton: some View {
        Button {
            showEmailSignIn = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image("MailIcon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .colorInvert()

                Text("Continue with Email")
                    .font(.system(size: isIPad ? 23 : 23, weight: .semibold))
                    .foregroundStyle(.white)

            }
            
            .padding(.horizontal, buttonHorizontalPadding)
            .frame(height: buttonHeight)
            .frame(maxWidth: buttonMaxWidth)
            .background(emailColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: emailColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueEmailButton")
    }

    private var googleButton: some View {
        Button {
            auth.signInWithGoogle()
        } label: {
            HStack(spacing: 14) {
                Image("GoogleIcon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text("Continue with Google")
                    .font(.system(size: isIPad ? 23 : 23, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, buttonHorizontalPadding)
            .frame(height: buttonHeight)
            .frame(maxWidth: buttonMaxWidth)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueGoogleButton")
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = []
        } onCompletion: { _ in }
        .signInWithAppleButtonStyle(.black)
        .frame(minHeight: buttonHeight, maxHeight: buttonHeight)
        .frame(maxWidth: buttonMaxWidth)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 6)
        .accessibilityIdentifier("continueAppleButton")
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button("Terms of Service") { openURL(termsURL) }
                    .font(.footnote.weight(.semibold))
                Text("•")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Privacy Policy") { openURL(privacyURL) }
                    .font(.footnote.weight(.semibold))
            }
        }
        .tint(.blue)
        .padding(.top, 4)
    }
}

#Preview {
    PreAuthView()
        .environmentObject(AuthViewModel())
}
