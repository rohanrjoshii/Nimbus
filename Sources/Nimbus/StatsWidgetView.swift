import SwiftUI

struct StatsWidgetView: View {
    @EnvironmentObject var stats: SystemStatsManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Core Gauges
            HStack(spacing: 24) {
                // CPU Gauge
                StatGauge(
                    value: stats.cpuUsage,
                    color: Color(red: 0.15, green: 0.65, blue: 0.95),
                    label: "CPU",
                    icon: "cpu"
                )
                
                // RAM Gauge
                StatGauge(
                    value: stats.memoryUsage,
                    color: Color(red: 0.65, green: 0.35, blue: 0.95),
                    label: "RAM",
                    icon: "memorychip"
                )
                
                // Battery Gauge
                StatGauge(
                    value: Double(stats.batteryLevel),
                    color: stats.isBatteryCharging ? Color.green : (stats.batteryLevel < 20 ? Color.red : Color.green.opacity(0.85)),
                    label: stats.isBatteryCharging ? "Charging" : "Battery",
                    icon: stats.isBatteryCharging ? "bolt.fill" : (stats.batteryLevel < 20 ? "battery.0" : "battery.100")
                )
            }
            .padding(.horizontal, 10)
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 8)
            
            // Bottom Row: Storage & Network Rates
            HStack(alignment: .center, spacing: 20) {
                // Disk storage info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Disk Space")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text(String(format: "%.0f GB / %.0f GB", stats.diskUsedGB, stats.diskTotalGB))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Simple custom progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 5)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, min(geo.size.width * CGFloat(stats.diskUsedGB / max(1, stats.diskTotalGB)), geo.size.width)), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
                
                // Network Bandwidth Rates
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Network Activity")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.cyan)
                            Text(stats.networkUploadRate)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                            Text(stats.networkDownloadRate)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 140)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}

struct StatGauge: View {
    let value: Double
    let color: Color
    let label: String
    let icon: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4.5)
                    .frame(width: 58, height: 58)
                
                // Active Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(value / 100.0))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
                
                // Central Percentage / Icon
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(isHovered ? color : .white.opacity(0.5))
                        .offset(y: -1)
                    
                    Text(String(format: "%.0f%%", value))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .shadow(color: isHovered ? color.opacity(0.3) : Color.clear, radius: 4)
            .onHover { hovering in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}
