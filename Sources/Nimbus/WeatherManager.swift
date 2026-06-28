import Foundation
import CoreLocation
import SwiftUI
import Combine

/// Live weather via the free, key-less Open-Meteo API.
///
/// Location is resolved with CoreLocation when the user grants it; if location
/// is denied or unavailable, it falls back to coarse IP-based geolocation so the
/// widget always shows real conditions rather than placeholder data.
final class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()

    struct HourlyPoint: Identifiable {
        let id = UUID()
        let label: String
        let temp: Int
        let symbol: String
        let color: Color
    }

    @Published var temperature: Int = 0
    @Published var high: Int = 0
    @Published var low: Int = 0
    @Published var conditionText: String = "—"
    @Published var symbol: String = "cloud.fill"
    @Published var symbolColor: Color = .gray
    @Published var locationName: String = "Locating…"
    @Published var hourly: [HourlyPoint] = []
    @Published var isLoaded: Bool = false
    @Published var coordinate: CLLocationCoordinate2D? = nil

    private let locationManager = CLLocationManager()
    private var refreshTimer: Timer?
    private var didResolveLocation = false

    /// Fahrenheit for US locales, Celsius elsewhere — matches user expectation.
    private let useFahrenheit: Bool = Locale.current.measurementSystem == .us
    private var unitSuffix: String { useFahrenheit ? "fahrenheit" : "celsius" }
    var unitSymbol: String { useFahrenheit ? "°F" : "°C" }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        resolveLocation()
        // Refresh conditions every 15 minutes.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.resolveLocation()
        }
    }

    // MARK: - Location

    private func resolveLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            locationManager.requestLocation()
        default:
            // Denied / restricted → coarse IP fallback.
            fetchViaIPFallback()
        }

        // Safety net: if CoreLocation never calls back, fall back to IP.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, !self.didResolveLocation else { return }
            self.fetchViaIPFallback()
        }
    }

    private func fetchViaIPFallback() {
        guard !didResolveLocation else { return }
        guard let url = URL(string: "https://ipapi.co/json/") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lat = json["latitude"] as? Double,
                  let lon = json["longitude"] as? Double else { return }
            let city = (json["city"] as? String) ?? "Your Location"
            self.didResolveLocation = true
            DispatchQueue.main.async { self.locationName = city }
            self.fetchWeather(lat: lat, lon: lon)
        }.resume()
    }

    // MARK: - Open-Meteo

    private func fetchWeather(lat: Double, lon: Double) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "temperature_unit", value: unitSuffix),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "2"),
        ]
        guard let url = comps.url else { return }
        DispatchQueue.main.async { self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon) }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let resp = try? JSONDecoder().decode(OMResponse.self, from: data) else { return }
            self.apply(resp)
        }.resume()
    }

    private func apply(_ resp: OMResponse) {
        let isDay = resp.current.is_day == 1
        let cond = WeatherCode.describe(resp.current.weather_code, isDay: isDay)

        // Build the next-6-hours forecast starting at the current hour.
        let currentHourKey = String(resp.current.time.prefix(13)) // "yyyy-MM-ddTHH"
        let startIndex = resp.hourly.time.firstIndex { $0.hasPrefix(currentHourKey) }
            ?? resp.hourly.time.firstIndex { $0 >= resp.current.time } ?? 0
        var points: [HourlyPoint] = []
        for offset in 0..<6 {
            let i = startIndex + offset
            guard i < resp.hourly.time.count else { break }
            let c = WeatherCode.describe(resp.hourly.weather_code[i], isDay: hourIsDay(resp.hourly.time[i]))
            points.append(HourlyPoint(
                label: offset == 0 ? "Now" : Self.hourLabel(resp.hourly.time[i]),
                temp: Int(resp.hourly.temperature_2m[i].rounded()),
                symbol: c.symbol,
                color: c.color
            ))
        }

        DispatchQueue.main.async {
            self.temperature = Int(resp.current.temperature_2m.rounded())
            self.high = Int((resp.daily.temperature_2m_max.first ?? 0).rounded())
            self.low = Int((resp.daily.temperature_2m_min.first ?? 0).rounded())
            self.conditionText = cond.text
            self.symbol = cond.symbol
            self.symbolColor = cond.color
            self.hourly = points
            self.isLoaded = true
        }
    }

    /// Rough day/night for a forecast hour (06:00–19:00 treated as day).
    private func hourIsDay(_ iso: String) -> Bool {
        guard let h = Self.hour24(iso) else { return true }
        return h >= 6 && h < 19
    }

    private static func hour24(_ iso: String) -> Int? {
        let chars = Array(iso)
        guard chars.count >= 13 else { return nil }
        return Int(String(chars[11...12]))
    }

    private static func hourLabel(_ iso: String) -> String {
        guard let h = hour24(iso) else { return "" }
        let period = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12) \(period)"
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            fetchViaIPFallback()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        didResolveLocation = true
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        fetchWeather(lat: lat, lon: lon)
        reverseGeocode(lat: lat, lon: lon)
    }

    /// Keyless reverse geocoding (no CoreLocation/MapKit deprecation, works on every target).
    private func reverseGeocode(lat: Double, lon: Double) {
        guard let url = URL(string: "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=\(lat)&longitude=\(lon)&localityLanguage=en") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let name = (json["city"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (json["locality"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (json["principalSubdivision"] as? String)
                ?? "Your Location"
            DispatchQueue.main.async { self.locationName = name }
        }.resume()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fetchViaIPFallback()
    }
}

// MARK: - Open-Meteo response model

private struct OMResponse: Codable {
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Codable {
        let time: String
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }
    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
    }
    struct Daily: Codable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }
}

// MARK: - WMO weather code → SF Symbol + label + colour

enum WeatherCode {
    static func describe(_ code: Int, isDay: Bool) -> (text: String, symbol: String, color: Color) {
        switch code {
        case 0:
            return isDay ? ("Clear", "sun.max.fill", .orange)
                         : ("Clear", "moon.stars.fill", Color(red: 0.55, green: 0.55, blue: 0.95))
        case 1, 2:
            return isDay ? ("Partly Cloudy", "cloud.sun.fill", .yellow)
                         : ("Partly Cloudy", "cloud.moon.fill", Color(red: 0.6, green: 0.6, blue: 0.9))
        case 3:
            return ("Overcast", "cloud.fill", Color(white: 0.75))
        case 45, 48:
            return ("Fog", "cloud.fog.fill", Color(white: 0.7))
        case 51, 53, 55, 56, 57:
            return ("Drizzle", "cloud.drizzle.fill", .blue)
        case 61, 63, 65, 66, 67:
            return ("Rain", "cloud.rain.fill", .blue)
        case 71, 73, 75, 77:
            return ("Snow", "cloud.snow.fill", .cyan)
        case 80, 81, 82:
            return ("Showers", "cloud.heavyrain.fill", .blue)
        case 85, 86:
            return ("Snow Showers", "cloud.snow.fill", .cyan)
        case 95:
            return ("Thunderstorm", "cloud.bolt.rain.fill", .purple)
        case 96, 99:
            return ("Hailstorm", "cloud.bolt.rain.fill", .purple)
        default:
            return ("Cloudy", "cloud.fill", Color(white: 0.75))
        }
    }
}
