import SwiftUI

struct WeatherWidgetView: View {
    @ObservedObject private var weather = WeatherManager.shared
    @State private var iconPulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main Weather Header
            HStack(spacing: 16) {
                // Live condition icon
                Image(systemName: weather.symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(weather.symbolColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 48, height: 48)
                    .scaleEffect(iconPulse ? 1.04 : 0.96)
                    .shadow(color: weather.symbolColor.opacity(0.35), radius: 6)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: iconPulse)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 2) {
                        Text(weather.isLoaded ? "\(weather.temperature)" : "—")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(weather.unitSymbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                    .foregroundColor(.white)

                    Text(weather.conditionText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(weather.locationName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if weather.isLoaded {
                        Text("H: \(weather.high)° L: \(weather.low)°")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Hourly Forecast Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if weather.hourly.isEmpty {
                        ForEach(0..<6, id: \.self) { _ in HourlyItem.placeholder }
                    } else {
                        ForEach(weather.hourly) { point in
                            HourlyItem(time: point.label,
                                       temp: "\(point.temp)°",
                                       icon: point.symbol,
                                       color: point.color)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 58)
            .padding(.bottom, 12)
        }
        .onAppear { iconPulse = true }
    }
}

// Hourly item cell helper
struct HourlyItem: View {
    let time: String
    let temp: String
    let icon: String
    let color: Color

    @State private var isHovered = false

    static let placeholder = HourlyItem(time: "—", temp: "–°", icon: "cloud.fill", color: .gray)

    var body: some View {
        VStack(spacing: 4) {
            Text(time)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)

            Text(temp)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 42)
        .padding(.vertical, 4)
        .background(Color.white.opacity(isHovered ? 0.06 : 0.0))
        .cornerRadius(6)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
