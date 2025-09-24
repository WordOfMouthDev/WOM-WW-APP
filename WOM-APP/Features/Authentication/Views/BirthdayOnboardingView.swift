import SwiftUI

struct BirthdayOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var selectedDate = Date()
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
    
    init() {
        // Initialize with a default date (June 14, 1971 as shown in the design)
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 1971, month: 6, day: 14)
        _selectedDate = State(initialValue: calendar.date(from: dateComponents) ?? Date())
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "#fcf4f2").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with icon
                    VStack(spacing: isIPad ? 32 : 24) {
                        Spacer()
                            .frame(height: isIPad ? 80 : 60)
                        
                        // Party icon with decorative elements
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(Color(hex: "#f4e4e1"))
                                .frame(width: iconSize + 40, height: iconSize + 40)
                            
                            // Main party icon
                            Image(systemName: "party.popper")
                                .font(.system(size: iconSize * 0.6, weight: .regular))
                                .foregroundColor(Color(hex: "#e8a598"))
                            
                            // Decorative elements around the icon
                            Group {
                                // Stars
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#e8a598"))
                                    .offset(x: -60, y: -30)
                                
                                Image(systemName: "star")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#e8a598"))
                                    .offset(x: 65, y: -20)
                                
                                // Sparkles
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#e8a598"))
                                    .offset(x: 50, y: 40)
                                
                                // Plus signs
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#e8a598"))
                                    .offset(x: -50, y: 45)
                                
                                // Circle
                                Circle()
                                    .fill(Color(hex: "#e8a598"))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 70, y: 10)
                                
                                // Square
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#e8a598"))
                                    .frame(width: 10, height: 10)
                                    .offset(x: -70, y: 15)
                            }
                        }
                        .frame(height: iconSize + 80)
                        
                        // Title and subtitle
                        VStack(spacing: isIPad ? 16 : 12) {
                            Text("Enter your date of birth")
                                .font(.system(size: isIPad ? 32 : 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#4c5c35"))
                                .multilineTextAlignment(.center)
                            
                            Text("This won't be part of your public profile")
                                .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                                .foregroundColor(Color(hex: "#7d8b68"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, horizontalPadding)
                        }
                        
                        Spacer()
                            .frame(height: isIPad ? 40 : 32)
                    }
                    
                    // Date input field (display only)
                    VStack(spacing: isIPad ? 24 : 20) {
                        HStack {
                            Text(formatDate(selectedDate))
                                .font(.system(size: isIPad ? 20 : 18, weight: .medium))
                                .foregroundColor(Color(hex: "#4c5c35"))
                            
                            Spacer()
                        }
                        .padding(isIPad ? 24 : 20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, horizontalPadding)
                        
                        Spacer()
                        
                        // Continue button
                        VStack(spacing: isIPad ? 20 : 16) {
                            Button {
                                onboardingViewModel.selectedDate = selectedDate
                                onboardingViewModel.completeBirthdayStep()
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
                                .background(Color(hex: "#b9bea0"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color(hex: "#b9bea0").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .disabled(onboardingViewModel.isLoading)
                            .padding(.horizontal, horizontalPadding)
                            
                            // Date picker wheels (showing current selection)
                            CustomDatePickerView(selectedDate: $selectedDate)
                                .frame(height: isIPad ? 200 : 180)
                                .padding(.horizontal, horizontalPadding)
                                .onChange(of: selectedDate) { _, newDate in
                                    onboardingViewModel.selectedDate = newDate
                                }
                        }
                        
                        Spacer()
                            .frame(height: isIPad ? 60 : 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            onboardingViewModel.selectedDate = selectedDate
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct CustomDatePickerView: View {
    @Binding var selectedDate: Date
    @State private var selectedDay = 14
    @State private var selectedMonth = 6
    @State private var selectedYear = 1971
    
    private let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    private let days = Array(1...31)
    private let years = Array(1930...2024).reversed()
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Month picker
            Picker("Month", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(months[month - 1])
                        .font(.system(size: isIPad ? 20 : 18, weight: .medium))
                        .foregroundColor(selectedMonth == month ? Color(hex: "#4c5c35") : Color(hex: "#7d8b68"))
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            
            // Day picker
            Picker("Day", selection: $selectedDay) {
                ForEach(days, id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: isIPad ? 20 : 18, weight: .medium))
                        .foregroundColor(selectedDay == day ? Color(hex: "#4c5c35") : Color(hex: "#7d8b68"))
                        .tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            
            // Year picker
            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text("\(year)")
                        .font(.system(size: isIPad ? 20 : 18, weight: .medium))
                        .foregroundColor(selectedYear == year ? Color(hex: "#4c5c35") : Color(hex: "#7d8b68"))
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: selectedDay) { _, _ in updateDate() }
        .onChange(of: selectedMonth) { _, _ in updateDate() }
        .onChange(of: selectedYear) { _, _ in updateDate() }
        .onAppear {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day, .month, .year], from: selectedDate)
            selectedDay = components.day ?? 14
            selectedMonth = components.month ?? 6
            selectedYear = components.year ?? 1971
        }
    }
    
    private func updateDate() {
        let calendar = Calendar.current
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: selectedDay)
        if let date = calendar.date(from: components) {
            selectedDate = date
        }
    }
}


#Preview {
    BirthdayOnboardingView()
        .environmentObject(OnboardingViewModel())
}
