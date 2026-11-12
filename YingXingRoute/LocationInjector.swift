import Foundation
import CoreLocation

protocol LocationSink {
    var name: String { get }
    func start()
    func push(_ coordinate: CLLocationCoordinate2D, speed: Double)
    func stop()
}

/// 方案 A：App 内模拟。坐标只在本进程内生效（地图蓝点、里程、录制回放）。
final class InAppSink: LocationSink {
    let name = "App 内模拟"
    func start() {}
    func push(_ coordinate: CLLocationCoordinate2D, speed: Double) {}
    func stop() {}
}

/// 方案 B：越狱设备上的系统级改写。
/// 通过已安装的 relocate / LocationSimulator 命令行桥接，写入系统级模拟坐标。
/// 设备未越狱或没有该 helper 时 push() 静默返回 false -> 上层回落 App 内模拟。
final class JailbreakSink: LocationSink {
    let name = "越狱注入"
    private var helperPath: String?

    init() {
        for p in ["/usr/bin/relocate", "/usr/local/bin/relocate",
                  "/usr/bin/location_sim", "/var/jb/usr/bin/relocate"] {
            if FileManager.default.isExecutableFile(atPath: p) { helperPath = p; break }
        }
    }

    var available: Bool { helperPath != nil }

    func start() {}

    func push(_ coordinate: CLLocationCoordinate2D, speed: Double) {
        guard let path = helperPath else { return }
        let args = [path, "set", String(format: "%.6f", coordinate.latitude),
                    String(format: "%.6f", coordinate.longitude)]
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }
        var pid: pid_t = 0
        let rc = posix_spawn(&pid, path, nil, nil, argv, environ)
        if rc == 0 { waitpid(pid, nil, 0) }
    }

    func stop() {
        guard let path = helperPath else { return }
        let args = [path, "clear"]
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }
        var pid: pid_t = 0
        _ = posix_spawn(&pid, path, nil, nil, argv, environ)
        waitpid(pid, nil, 0)
    }
}
