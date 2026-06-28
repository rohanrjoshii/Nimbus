import SwiftUI

struct TimerWidgetView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var selectedMinutes: Int = 5
    
    var body: some View {
        Group {
            if timerManager.isActive {
                if timerManager.isPomodoroMode {
                    activePomodoroLayout
                } else {
                    activeTimerLayout
                }
            } else {
                setupTimerLayout
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Setup Mode Layout
    private var setupTimerLayout: some View {
        VStack(spacing: 8) {
            // Mode toggle header
            HStack {
                Text("Select Timer Mode")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            
            // Standard presets
            HStack(spacing: 8) {
                PresetButton(minutes: 1, currentSelection: $selectedMinutes)
                PresetButton(minutes: 5, currentSelection: $selectedMinutes)
                PresetButton(minutes: 10, currentSelection: $selectedMinutes)
                PresetButton(minutes: 15, currentSelection: $selectedMinutes)
                PresetButton(minutes: 30, currentSelection: $selectedMinutes)
            }
            
            // Adjuster and Start Buttons
            HStack(spacing: 10) {
                // Custom Adjuster
                HStack(spacing: 8) {
                    Button(action: { if selectedMinutes > 1 { selectedMinutes -= 1 } }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(selectedMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 38)
                    
                    Button(action: { if selectedMinutes < 999 { selectedMinutes += 1 } }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Pomodoro Start Button
                Button(action: {
                    HapticManager.shared.triggerClick()
                    timerManager.startPomodoro()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.fill")
                        Text("Pomo")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.4), lineWidth: 0.5)
                    )
                }
                .buttonStyle(ControlButtonStyle())
                
                // Standard Start Button
                Button(action: {
                    HapticManager.shared.triggerClick()
                    timerManager.start(seconds: TimeInterval(selectedMinutes * 60))
                }) {
                    Text("Start")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.orange)
                        .cornerRadius(12)
                        .shadow(color: Color.orange.opacity(0.4), radius: 6)
                }
                .buttonStyle(ControlButtonStyle())
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Active Standard Layout
    private var activeTimerLayout: some View {
        HStack(spacing: 20) {
            // Circle countdown
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.timeRemaining)
                
                VStack(spacing: 2) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    
                    Text(timerManager.timeFormatted)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown Active")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Button(action: {
                        HapticManager.shared.triggerClick()
                        if timerManager.isPaused {
                            timerManager.resume()
                        } else {
                            timerManager.pause()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                            Text(timerManager.isPaused ? "Resume" : "Pause")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(ControlButtonStyle())
                    
                    Button(action: {
                        HapticManager.shared.triggerClick()
                        timerManager.reset()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.25))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ControlButtonStyle())
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Active Pomodoro Layout
    private var activePomodoroLayout: some View {
        HStack(spacing: 20) {
            // Circle countdown using Pomo dynamic theme color
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(pomoColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.timeRemaining)
                
                VStack(spacing: 2) {
                    Image(systemName: timerManager.pomodoroStage == .work ? "brain" : "cup.and.saucer.fill")
                        .font(.system(size: 10))
                        .foregroundColor(pomoColor)
                    
                    Text(timerManager.timeFormatted)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(timerManager.pomodoroStage.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(pomoColor)
                
                // Cycles completed tracker (Pips indicator)
                HStack(spacing: 5) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < timerManager.pomodoroCyclesCompleted % 4 ? pomoColor : Color.white.opacity(0.15))
                            .frame(width: 6, height: 6)
                    }
                    Text("Cycle \(timerManager.pomodoroCyclesCompleted)/4")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 4)
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        HapticManager.shared.triggerClick()
                        if timerManager.isPaused {
                            timerManager.resume()
                        } else {
                            timerManager.pause()
                        }
                    }) {
                        Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ControlButtonStyle())
                    
                    Button(action: {
                        HapticManager.shared.triggerClick()
                        timerManager.reset()
                    }) {
                        Text("Quit")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.25))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ControlButtonStyle())
                }
                .padding(.top, 2)
            }
            Spacer()
        }
    }
    
    private var pomoColor: Color {
        switch timerManager.pomodoroStage {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

// Preset Button helper
struct PresetButton: View {
    let minutes: Int
    @Binding var currentSelection: Int
    
    var body: some View {
        Button(action: { currentSelection = minutes }) {
            Text("\(minutes)m")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(currentSelection == minutes ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(currentSelection == minutes ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
