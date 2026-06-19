import SwiftUI
import AppKit
import LaunchAtLogin

// A bridge to NSVisualEffectView for native macOS frosted glass effect
struct SettingsVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Custom Glassmorphic Card Wrapper for Settings
struct SettingsCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.40))
                    .background(SettingsVisualEffectView(material: .hudWindow, blendingMode: .withinWindow).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.40), radius: 8, x: 0, y: 4)
    }
}

struct settingsView: View {
    @Binding var standardTimer: Int
    @Binding var shortBreak: Int
    @Binding var longBreak: Int
    
    @State private var isCloseHovered = false
    
    private let accentColor = Color(red: 241/255, green: 152/255, blue: 70/255)
    
    var body: some View {
        ZStack {
            // 1. Pitch-black base background
            Color.black
                .ignoresSafeArea()
            
            // 2. Ambient background lights for depth
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.06))
                    .frame(width: 200, height: 200)
                    .blur(radius: 65)
                    .offset(x: -80, y: -100)
                
                Circle()
                    .fill(accentColor.opacity(0.03))
                    .frame(width: 240, height: 240)
                    .blur(radius: 80)
                    .offset(x: 90, y: 100)
            }
            .allowsHitTesting(false)
            
            // 3. Subtle Vignette behind the content
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.60),
                    .init(color: Color.black.opacity(0.70), location: 1.0)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 280
            )
            .allowsHitTesting(false)
            
            // 4. Content VStack
            VStack(alignment: .leading, spacing: 16) {
                // Header (Close button + Title in a single row)
                HStack(spacing: 12) {
                    Button(action: {
                        for window in NSApplication.shared.windows {
                            if window.frameAutosaveName == "SettingsWindow" {
                                window.close()
                                break
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(isCloseHovered ? 0.95 : 0.55))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(isCloseHovered ? 0.20 : 0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isCloseHovered = hovering
                    }
                    
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    
                    Spacer()
                }
                .frame(height: 24)
                
                // General Settings Card (Launch at Login)
                SettingsCard {
                    HStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentColor)
                            .frame(width: 22, height: 22)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Circle())
                        
                        LaunchAtLogin.Toggle()
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                }
                
                // Timer Intervals settings Card
                SettingsCard {
                    HStack(spacing: 0) {
                        CustomTextField(label: "Standard", value: $standardTimer)
                        Spacer()
                        CustomTextField(label: "Short Break", value: $shortBreak)
                        Spacer()
                        CustomTextField(label: "Long Break", value: $longBreak)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 340, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

// Custom Glassmorphic Text Field for numerical inputs
struct CustomTextField: View {
    let label: String
    @Binding var value: Int
    
    var body: some View {
        VStack(spacing: 6) {
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(PlainTextFieldStyle())
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 241/255, green: 152/255, blue: 70/255))
                .frame(width: 76, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct settingsView_Previews: PreviewProvider {
    static var previews: some View {
        settingsView(standardTimer: .constant(25), shortBreak: .constant(5), longBreak: .constant(15))
    }
}
