import SwiftUI

enum ToastType {
    case success
    case error
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval
    
    init(message: String, type: ToastType, duration: TimeInterval = 3.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
}

@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: ToastMessage?
    
    func show(_ message: String, type: ToastType, duration: TimeInterval = 3.0) {
        currentToast = ToastMessage(message: message, type: type, duration: duration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if self.currentToast?.message == message {
                self.currentToast = nil
            }
        }
    }
    
    func showSuccess(_ message: String) {
        show(message, type: .success)
    }
    
    func showError(_ message: String) {
        show(message, type: .error)
    }
    
    func showInfo(_ message: String) {
        show(message, type: .info)
    }
    
    func dismiss() {
        currentToast = nil
    }
}

struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
            
            Text(toast.message)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toast.type.color)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if let toast = toastManager.currentToast {
                        Spacer()
                        ToastView(toast: toast) {
                            toastManager.dismiss()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastManager.currentToast)
                        .padding(.bottom, 100) // Above tab bar
                    }
                }
                .allowsHitTesting(false)
            )
    }
}

extension View {
    func toast(_ toastManager: ToastManager) -> some View {
        modifier(ToastModifier(toastManager: toastManager))
    }
}
