import SwiftUI

/// 对应 Android: SettingsActivity / UtilityCenterActivity / EnhancedToolsActivity / TutorialActivity
struct SettingsScreen: View {
    @EnvironmentObject var engine: RoutePlaybackEngine
    @EnvironmentObject var store: RouteStore
    @StateObject private var nfc = NfcBridge()
    @State private var host = "127.0.0.1"
    @State private var port = "8266"

    var body: some View {
        NavigationView {
            Form {
                Section("注入方式") {
                    Picker("模式", selection: $engine.mode) {
                        ForEach(InjectMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    Text("越狱注入需要设备已越狱，且存在 /usr/bin/relocate helper；否则自动回落 App 内模拟。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("坐标基准") {
                    Picker("输入路线坐标系", selection: $store.inputDatum) {
                        ForEach(CoordDatum.allCases) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Text("百度地图 SDK 导出的路线是 BD-09；直接画到 MapKit 会偏 300~600 m，必须选对后再回放。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("NFC") {
                    Button("扫描 NFC 标签触发路线") {
                        nfc.onRoute = { name in
                            if let r = store.routes.first(where: { $0.name.contains(name) }) {
                                engine.start(r)
                            }
                        }
                        nfc.onCoordinate = { c in
                            engine.nudge(dLat: c.latitude, dLon: c.longitude)
                        }
                        nfc.scan()
                    }
                    Text(nfc.status).font(.caption).foregroundStyle(.secondary)
                }

                Section("数据链路") {
                    TextField("Host", text: $host).textInputAutocapitalization(.never)
                    TextField("Port", text: $port).keyboardType(.numberPad)
                    Button("测试连接") { ping() }
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.21.18 (12118)")
                    LabeledContent("Android 包名", value: "com.fyguiji.prp")
                    LabeledContent("iOS Bundle ID", value: "com.fyguiji.prp.ios")
                }
            }
            .navigationTitle("设置")
        }
    }

    private func ping() {
        guard let p = Int(port), let url = URL(string: "http://\(host):\(p)/") else { return }
        URLSession.shared.dataTask(with: url) { _, resp, _ in
            DispatchQueue.main.async {
                engine.currentRouteName = resp == nil ? "连接失败" : "连接成功"
            }
        }.resume()
    }
}
