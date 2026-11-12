import Foundation
import Combine
import CoreLocation

/// 对应 Android: com.zcshou.service.ServiceGo + RouteRunActivity
/// 沿折线按 speed(m/s) 推进，输出当前坐标给 sink
final class RoutePlaybackEngine: ObservableObject {
    @Published var isRunning = false
    @Published var current: CLLocationCoordinate2D?
    @Published var progress: Double = 0
    @Published var mode: InjectMode = .inApp { didSet { rebuildSink() } }
    @Published var currentRouteName: String = "—"

    private weak var store: RouteStore?
    private var route: RouteDoc?
    private var distance: Double = 0        // 已推进距离 (m)
    private var timer: Timer?
    private var sink: LocationSink = InAppSink()
    private let jb = JailbreakSink()

    func attach(store: RouteStore) { self.store = store }

    private func rebuildSink() {
        sink = (mode == .jailbreak && jb.available) ? jb : InAppSink()
    }

    func start(_ route: RouteDoc) {
        guard route.points.count > 1 else { return }
        self.route = route
        currentRouteName = route.name
        distance = 0
        isRunning = true
        sink.start()
        timer?.invalidate()
        let tick = 0.2
        timer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            self?.advance(dt: tick)
        }
        advance(dt: 0)
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        pause()
        sink.stop()
        distance = 0
        progress = 0
        current = nil
        currentRouteName = "—"
    }

    private func advance(dt: Double) {
        guard let r = route, r.points.count > 1 else { return }
        distance += r.speed * dt
        let total = r.totalDistance
        if total > 0 && distance >= total {
            if r.loop { distance = distance.truncatingRemainder(dividingBy: total) }
            else { distance = total; pause() }
        }
        let c = interpolate(r.points, distance)
        current = c
        progress = total > 0 ? min(distance / total, 1) : 0
        sink.push(c, speed: r.speed)
    }

    /// 沿折线按累计距离插值
    private func interpolate(_ pts: [RoutePoint], _ target: Double) -> CLLocationCoordinate2D {
        var acc = 0.0
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let seg = CLLocation(latitude: a.lat, longitude: a.lon)
                .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
            if acc + seg >= target {
                let t = seg > 0 ? (target - acc) / seg : 0
                return CLLocationCoordinate2D(
                    latitude: a.lat + (b.lat - a.lat) * t,
                    longitude: a.lon + (b.lon - a.lon) * t)
            }
            acc += seg
        }
        let last = pts[pts.count - 1]
        return CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon)
    }

    /// 摇杆操控：对应 FloatingJoystickService / JoystickTeleportActivity
    func nudge(dLat: Double, dLon: Double) {
        guard let c = current else { return }
        let n = CLLocationCoordinate2D(latitude: c.latitude + dLat, longitude: c.longitude + dLon)
        current = n
        sink.push(n, speed: 0)
    }
}
