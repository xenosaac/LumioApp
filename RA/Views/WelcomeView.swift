import SwiftUI

struct WelcomeView: View {
    @State private var showingMainApp = false
    @State private var animateIcon = false
    @State private var animateText = false
    @State private var animateFeatures = false
    
    var body: some View {
        ZStack {
            // Gradient background matching app theme
            LinearGradient(
                colors: [.appPurple, .appPurpleDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and App Icon Section
                VStack(spacing: 24) {
                    // Custom sleepy alarm clock icon
                    ZStack {
                        // Outer glow effect
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .scaleEffect(animateIcon ? 1.0 : 0.8)
                            .animation(.easeOut(duration: 1.2).delay(0.3), value: animateIcon)
                        
                        // Main alarm clock body
                        Circle()
                            .fill(Color.appPurpleDark)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 4)
                            )
                            .scaleEffect(animateIcon ? 1.0 : 0.6)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: animateIcon)
                        
                        // Clock face
                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .scaleEffect(animateIcon ? 1.0 : 0.6)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.7), value: animateIcon)
                        
                        // Sleepy eyes
                        HStack(spacing: 24) {
                            // Left eye
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .frame(width: 16, height: 6)
                                .rotationEffect(.degrees(-10))
                            
                            // Right eye  
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .frame(width: 16, height: 6)
                                .rotationEffect(.degrees(10))
                        }
                        .offset(y: -8)
                        .opacity(animateIcon ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.5).delay(1.0), value: animateIcon)
                        
                        // Small smile
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: 0, y: 8),
                                radius: 12,
                                startAngle: .degrees(0),
                                endAngle: .degrees(180),
                                clockwise: false
                            )
                        }
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 24, height: 12)
                        .opacity(animateIcon ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.5).delay(1.2), value: animateIcon)
                        
                        // Clock hands
                        VStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 2, height: 25)
                                .offset(y: -12.5)
                        }
                        .rotationEffect(.degrees(120))
                        .opacity(animateIcon ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.3).delay(1.4), value: animateIcon)
                        
                        // Alarm bells
                        HStack(spacing: 80) {
                            // Left bell
                            VStack {
                                Circle()
                                    .fill(Color.appPurpleDark)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 3, height: 15)
                                    .rotationEffect(.degrees(-20))
                            }
                            .offset(x: -15, y: -30)
                            .rotationEffect(.degrees(animateIcon ? -10 : -30))
                            .animation(.spring(response: 0.6, dampingFraction: 0.4).delay(1.6), value: animateIcon)
                            
                            // Right bell
                            VStack {
                                Circle()
                                    .fill(Color.appPurpleDark)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 3, height: 15)
                                    .rotationEffect(.degrees(20))
                            }
                            .offset(x: 15, y: -30)
                            .rotationEffect(.degrees(animateIcon ? 10 : 30))
                            .animation(.spring(response: 0.6, dampingFraction: 0.4).delay(1.8), value: animateIcon)
                        }
                        .opacity(animateIcon ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.3).delay(1.4), value: animateIcon)
                        
                        // Clock legs
                        HStack(spacing: 60) {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 4, height: 25)
                                .rotationEffect(.degrees(-15))
                                .offset(y: 25)
                            
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 4, height: 25)
                                .rotationEffect(.degrees(15))
                                .offset(y: 25)
                        }
                        .opacity(animateIcon ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.3).delay(1.0), value: animateIcon)
                    }
                    
                    // LUMIO Logo
                    VStack(spacing: 8) {
                        Text("LUMIO")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(animateText ? 1.0 : 0)
                            .offset(y: animateText ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(2.0), value: animateText)
                        
                        Text("Your Personal Sleep & Dream Companion")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .opacity(animateText ? 1.0 : 0)
                            .offset(y: animateText ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(2.3), value: animateText)
                    }
                }
                
                Spacer()
                
                // Features Section
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "bed.double.fill",
                            title: "Smart Sleep Tracking",
                            description: "Monitor your sleep patterns with intelligent insights"
                        )
                        .opacity(animateFeatures ? 1.0 : 0)
                        .offset(x: animateFeatures ? 0 : -100)
                        .animation(.easeOut(duration: 0.6).delay(2.8), value: animateFeatures)
                        
                        FeatureRow(
                            icon: "alarm.fill", 
                            title: "Gentle Wake Alarms",
                            description: "Wake up naturally during your lightest sleep phase"
                        )
                        .opacity(animateFeatures ? 1.0 : 0)
                        .offset(x: animateFeatures ? 0 : 100)
                        .animation(.easeOut(duration: 0.6).delay(3.1), value: animateFeatures)
                        
                        FeatureRow(
                            icon: "moon.stars.fill",
                            title: "AI Dream Analysis", 
                            description: "Discover the meaning behind your dreams with AI insights"
                        )
                        .opacity(animateFeatures ? 1.0 : 0)
                        .offset(x: animateFeatures ? 0 : -100)
                        .animation(.easeOut(duration: 0.6).delay(3.4), value: animateFeatures)
                    }
                    
                    // Get Started Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showingMainApp = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                            Text("Get Started")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.appPurpleDark)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.appYellowDark)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        )
                    }
                    .scaleEffect(animateFeatures ? 1.0 : 0.8)
                    .opacity(animateFeatures ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(3.7), value: animateFeatures)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
        .fullScreenCover(isPresented: $showingMainApp) {
            ContentView()
        }
    }
    
    private func startAnimations() {
        animateIcon = true
        animateText = true
        animateFeatures = true
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.appYellowDark)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
} 