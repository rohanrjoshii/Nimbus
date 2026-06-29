import SwiftUI

struct StatsWidgetView: View {
    @EnvironmentObject var stats: SystemStatsManager

    private var batteryGradient: [Color] {
        if stats.isBatteryCharging { return [Color(red: 0.3, green: 0.95, blue: 0.6), Color(red: 0.1, green: 0.8, blue: 0.55)] }
        if stats.batteryLevel < 20 { return [Color(red: 1.0, green: 0.5, blue: 0.35), Color(red: 0.95, green: 0.25, blue: 0.3)] }
        return [Color(red: 0.35, green: 0.92, blue: 0.6), Color(red: 0.15, green: 0.78, blue: 0.5)]
    }

    var body: some View {
        VStack(spacing: 14) {
            // ── Core gauges ──────────────────────────────────────────────
            HStack(spacing: 18) {
                StatGauge(value: stats.cpuUsage,
                          gradient: [Color(red: 0.3, green: 0.8, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 0.95)],
                          label: "CPU", icon: "cpu")
                StatGauge(value: stats.memoryUsage,
                          gradient: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.95)],
                          label: "RAM", icon: "memorychip")
                StatGauge(value: Double(stats.batteryLevel),
                          gradient: batteryGradient,
                          label: stats.isBatteryCharging ? "Charging" : "Battery",
                          icon: stats.isBatteryCharging ? "bolt.fill" : (stats.batteryLevel < 20 ? "battery.25" : "battery.100"))
            }
            .padding(.horizontal, 14)

            // ── Storage + Network card ───────────────────────────────────
            VStack(spacing: 11) {
                // Storage
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.45))
                        Text("Storage")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(stats.diskUsedGB)) / \(Int(stats.diskTotalGB)) GB")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.10)).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.7, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, min(geo.size.width * CGFloat(stats.diskUsedGB / max(1, stats.diskTotalGB)), geo.size.width)), height: 6)
                                .shadow(color: Color.blue.opacity(0.4), radius: 3)
                        }
                    }
                    .frame(height: 6)
                }

                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

                // Network
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Network")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    netRate("arrow.up", stats.networkUploadRate, Color(red: 0.3, green: 0.8, blue: 1.0))
                    netRate("arrow.down", stats.networkDownloadRate, Color(red: 0.35, green: 0.9, blue: 0.55))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
            )
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 12)
    }

    private func netRate(_ icon: String, _ rate: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold)).foregroundColor(color)
            Text(rate).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.white)
        }
        .frame(minWidth: 62, alignment: .trailing)
    }
}

struct StatGauge: View {
    let value: Double
    let gradient: [Color]
    let label: String
    let icon: String

    @State private var hover = false
    private var pct: CGFloat { CGFloat(min(max(value, 0), 100) / 100) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 6)
                    .frame(width: 62, height: 62)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: gradient + [gradient.first ?? .white]),
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (gradient.last ?? .white).opacity(0.45), radius: hover ? 7 : 3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)

                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
                    Text("\(Int(value.rounded()))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(hover ? 1.06 : 1.0)
            .onHover { h in withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { hover = h } }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}
