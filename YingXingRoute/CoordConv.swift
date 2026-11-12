import Foundation
import CoreLocation

enum CoordDatum: String, CaseIterable, Identifiable, Codable {
    case wgs84 = "WGS-84 (GPS 原始)"
    case gcj02 = "GCJ-02 (高德/腾讯/Apple 地图)"
    case bd09  = "BD-09 (百度地图)"
    var id: String { rawValue }
}

/// 国内三套坐标互转。原 APK 用百度地图 SDK，导出的点是 BD-09；
/// iOS MapKit(中国区数据) 要 GCJ-02，差 300~600 m，不转换就是"装了没法用"。
enum CoordConv {
    private static let a: Double = 6378245.0
    private static let ee: Double = 0.00669342162296594323
    private static let xPi: Double = Double.pi * 3000.0 / 180.0

    static func outOfChina(lat: Double, lon: Double) -> Bool {
        lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271
    }

    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        r += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        r += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        r += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return r
    }

    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        r += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        r += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        r += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return r
    }

    static func wgs84ToGcj02(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = c.latitude, lon = c.longitude
        if outOfChina(lat: lat, lon: lon) { return c }
        var dLat = transformLat(lon - 105.0, lat - 35.0)
        var dLon = transformLon(lon - 105.0, lat - 35.0)
        let radLat = lat / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)
        return CLLocationCoordinate2D(latitude: lat + dLat, longitude: lon + dLon)
    }

    static func gcj02ToWgs84(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let g = wgs84ToGcj02(c)
        return CLLocationCoordinate2D(latitude: c.latitude * 2 - g.latitude,
                                      longitude: c.longitude * 2 - g.longitude)
    }

    static func gcj02ToBd09(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let x = c.longitude, y = c.latitude
        let z = sqrt(x * x + y * y) + 0.00002 * sin(y * xPi)
        let t = atan2(y, x) + 0.000003 * cos(x * xPi)
        return CLLocationCoordinate2D(latitude: z * sin(t) + 0.006,
                                      longitude: z * cos(t) + 0.0065)
    }

    static func bd09ToGcj02(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let x = c.longitude - 0.0065, y = c.latitude - 0.006
        let z = sqrt(x * x + y * y) - 0.00002 * sin(y * xPi)
        let t = atan2(y, x) - 0.000003 * cos(x * xPi)
        return CLLocationCoordinate2D(latitude: z * sin(t), longitude: z * cos(t))
    }

    /// 把任意基准的点投影成 MapKit 可用的 GCJ-02
    static func project(_ c: CLLocationCoordinate2D, from datum: CoordDatum) -> CLLocationCoordinate2D {
        switch datum {
        case .wgs84: return wgs84ToGcj02(c)
        case .gcj02: return c
        case .bd09:  return bd09ToGcj02(c)
        }
    }
}
