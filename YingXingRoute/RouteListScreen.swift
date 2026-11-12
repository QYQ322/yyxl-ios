import SwiftUI
import UniformTypeIdentifiers

/// 对应 Android: RouteActivity / HistoryActivity / RouteCreateActivity / ShareLibraryActivity
struct RouteListScreen: View {
    @EnvironmentObject var store: RouteStore
    @EnvironmentObject var engine: RoutePlaybackEngine
    @State private var showImporter = false
    @State private var editing: RouteDoc?

    var body: some View {
        NavigationView {
            List {
                Section("我的路线") {
                    ForEach(store.routes) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.name).font(.headline)
                            Text(String(format: "%d 点 · %.0f m · %.0f 秒 · %.1f m/s",
                                        r.points.count, r.totalDistance, r.estimatedDuration, r.speed))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { engine.start(r) }
                        .swipeActions {
                            Button("删除", role: .destructive) { store.delete(r) }
                            Button("复制") { store.duplicate(r) }
                        }
                    }
                }

                Section("导入 / 导出") {
                    Button("从文件导入 .route.json") { showImporter = true }
                    if let url = store.exportJSON(store.routes.first ?? .sample) {
                        ShareLink(item: url) { Text("导出当前路线") }
                    }
                }
            }
            .navigationTitle("路线库")
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let u = urls.first { store.import(from: u) }
            }
        }
    }
}
