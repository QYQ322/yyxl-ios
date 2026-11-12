import Foundation
import CoreLocation

struct RoutePoint: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var lat: Double
    var lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct RouteDoc: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var speed: Double          // m/s，对应 Android 端 ServiceGo 的推进速率
    var loop: Bool
    var points: [RoutePoint]

    var totalDistance: Double {
        guard points.count > 1 else { return 0 }
        var d = 0.0
        for i in 1..<points.count {
            d += CLLocation(latitude: points[i - 1].lat, longitude: points[i - 1].lon)
                .distance(from: CLLocation(latitude: points[i].lat, longitude: points[i].lon))
        }
        return d
    }

    var estimatedDuration: TimeInterval {
        speed <= 0 ? 0 : totalDistance / speed
    }

    static let sample = RouteDoc(
        name: "样例路线·星海广场",
        speed: 1.4,
        loop: true,
        points: [
            RoutePoint(lat: 38.8721, lon: 121.5906),
            RoutePoint(lat: 38.8735, lon: 121.5921),
            RoutePoint(lat: 38.8748, lon: 121.5935),
            RoutePoint(lat: 38.8760, lon: 121.5942),
            RoutePoint(lat: 38.8772, lon: 121.5928)
        ]
    )
}

enum InjectMode: String, CaseIterable, Identifiable, Codable {
    case inApp      = "App 内模拟"
    case jailbreak  = "越狱注入 (relocate)"
    var id: String { rawValue }
}
