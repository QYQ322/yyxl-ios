import Foundation
import Combine

/// 对应 Android: HistoryActivity / DataTransferActivity / ShareLibraryActivity 的持久化层
final class RouteStore: ObservableObject {
    @Published var routes: [RouteDoc] = []
    /// 输入路线点的坐标系基准。原 APK 走百度地图 SDK，导出点是 BD-09。
    @Published var inputDatum: CoordDatum = .bd09

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("routes.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([RouteDoc].self, from: data) else {
            routes = [RouteDoc.sample]
            save()
            return
        }
        routes = list
    }

    func save() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ route: RouteDoc) {
        if let i = routes.firstIndex(where: { $0.id == route.id }) {
            routes[i] = route
        } else {
            routes.append(route)
        }
        save()
    }

    func delete(_ route: RouteDoc) {
        routes.removeAll { $0.id == route.id }
        save()
    }

    func duplicate(_ route: RouteDoc) {
        var copy = route
        copy.id = UUID()
        copy.name += " 副本"
        routes.append(copy)
        save()
    }

    // 对应 Android: DataTransferActivity 的导入 / 导出
    func exportJSON(_ route: RouteDoc) -> URL? {
        guard let data = try? JSONEncoder().encode(route) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(route.name).route.json")
        try? data.write(to: url, options: .atomic)
        return url
    }

    func `import`(from url: URL) {
        guard url.startAccessingSecurityScopedResource() || true else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let r = try? JSONDecoder().decode(RouteDoc.self, from: data) else { return }
        var copy = r
        copy.id = UUID()
        routes.append(copy)
        save()
    }
}
