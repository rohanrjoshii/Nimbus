import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case behavior = "Behavior"
    case about = "About"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .behavior: return "sparkles"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var activeTab: SettingsTab = .general
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List
            VStack(alignment: .leading, spacing: 6) {
                // App Logo Title
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .bold))
                    Text("Nimbus Settings")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        HapticManager.shared.triggerClick()
                        activeTab = tab
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(activeTab == tab ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeTab == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Footer
                Text("Version 1.0.0 (Beta)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
            }
            .frame(width: 160)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content View
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch activeTab {
                    case .general:
                        generalSettings
                    case .appearance:
                        appearanceSettings
                    case .behavior:
                        behaviorSettings
                    case .about:
                        aboutView
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.2))
        }
        .frame(width: 540, height: 380)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - General Settings
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Preferences")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Launch at login
                SettingCard {
                    Toggle(isOn: $appState.launchAtLogin) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Start Nimbus automatically when your Mac boots.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: appState.launchAtLogin) {
                        HapticManager.shared.triggerClick()
                    }
                }

                // Screen Capture Protection
                SettingCard {
                    Toggle(isOn: $appState.hideFromCapture) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide from Screen Capture")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Hides the Dynamic Island from system screenshots and screen recording clips.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: appState.hideFromCapture) {
                        HapticManager.shared.triggerClick()
                        // This updates the window sharing type property in AppDelegate
                    }
                }
                
                // Preferred Audio Source
                SettingCard {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Preferred Audio Source")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Force Spotify or Apple Music, or auto-detect active system playing. If a forced app is not running, Nimbus resolves to an idle state rather than opening it.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Picker("", selection: $appState.audioSource) {
                            Text("Auto").tag(0)
                            Text("Spotify").tag(1)
                            Text("Apple Music").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 250)
                        .onChange(of: appState.audioSource) {
                            HapticManager.shared.triggerClick()
                            MusicManager.shared.updateTrackInfo()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Appearance Settings
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance Preferences")
                .font(.system(size: 16, weight: .bold))
            
            VStack(spacing: 12) {
                // Translucency Slider
                SettingCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Island Background Opacity")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.0f%%", appState.opacityValue * 100))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        
                        Slider(value: $appState.opacityValue, in: 0.3...1.0)
                            .tint(.blue)
                    }
                }
                
                // Top offset positioning slider
                SettingCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Vertical Spacing Offset")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.0f pt", appState.topOffset))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        
                        Slider(value: $appState.topOffset, in: 0...40)
                            .tint(.blue)
                    }
                }
                
                // Color Picker Row
                SettingCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent Tint Color")
                            .font(.system(size: 12, weight: .semibold))
                        
                        HStack(spacing: 12) {
                            ColorPickerDot(color: .white, isSelected: appState.accentColorIndex == 0, label: "Auto") {
                                appState.accentColorIndex = 0
                            }
                            ColorPickerDot(color: .cyan, isSelected: appState.accentColorIndex == 1, label: "Cyan") {
                                appState.accentColorIndex = 1
                            }
                            ColorPickerDot(color: .purple, isSelected: appState.accentColorIndex == 2, label: "Purple") {
                                appState.accentColorIndex = 2
                            }
                            ColorPickerDot(color: .orange, isSelected: appState.accentColorIndex == 3, label: "Orange") {
                                appState.accentColorIndex = 3
                            }
                            ColorPickerDot(color: .green, isSelected: appState.accentColorIndex == 4, label: "Green") {
                                appState.accentColorIndex = 4
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Behavior Settings
    private var behaviorSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Behavior Preferences")
                .font(.system(size: 16, weight: .bold))
            
            VStack(spacing: 12) {
                SettingCard {
                    Toggle(isOn: $appState.useNotchIntegration) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Snap flush to display top")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Attaches Nimbus directly inside or flush under display notches.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }

                SettingCard {
                    Toggle(isOn: $appState.lockSoundEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock / Unlock Sound")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Play a sound when your screen locks and unlocks. Drop lock.aiff / unlock.aiff into a Sounds/ folder to use your own.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: appState.lockSoundEnabled) { HapticManager.shared.triggerClick() }
                }
            }
        }
    }
    
    // MARK: - About View
    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Rotating magic sparkle logo
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text("Nimbus")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Mystical Dynamic Island overlay for macOS")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text("A zero-dependency floating HUD with glassmorphic design, spring-driven morphing, and live music, weather, calendar, and system activity.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("Made with ♥ by Akshay Joshi")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// Custom wrapper to keep setting cards clean & premium
struct SettingCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            content
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(isHovered ? 0.05 : 0.02))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(isHovered ? 0.1 : 0.04), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
    }
}

// Picker dot selection component
struct ColorPickerDot: View {
    let color: Color
    let isSelected: Bool
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.triggerClick()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 26, height: 26)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}
