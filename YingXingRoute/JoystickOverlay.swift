import SwiftUI

/// 对应 Android: FloatingJoystickService / JoystickTeleportActivity / FloatingRouteService
/// iOS 不允许第三方 App 绘制系统级悬浮窗，此处用 App 内全屏摇杆 + 后台音频保活近似替代
struct JoystickOverlay: View {
    @EnvironmentObject var engine: RoutePlaybackEngine
    @State private var offset: CGSize = .zero
    @State private var step = 0.00002
    @State private var teleport = 0.002

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) * 0.28
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()

                // 摇杆底盘
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                    .frame(width: r * 2, height: r * 2)

                // 摇杆帽
                Circle()
                    .fill(Color(red: 0.05, green: 0.56, blue: 0.58))
                    .frame(width: r * 0.8, height: r * 0.8)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                let maxR = r * 0.6
                                var d = CGSize(width: v.translation.width, height: v.translation.height)
                                let len = sqrt(d.width * d.width + d.height * d.height)
                                if len > maxR {
                                    d = CGSize(width: d.width / len * maxR, height: d.height / len * maxR)
                                }
                                offset = d
                                engine.nudge(dLat: -Double(offset.height) * step,
                                             dLon: Double(offset.width) * step)
                            }
                            .onEnded { _ in offset = .zero }
                    )

                VStack {
                    Spacer()
                    Text("拖动摇杆微调坐标 · 双击传送")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("步进").font(.caption)
                        Slider(value: $step, in: 0.000002...0.0002)
                        Text(String(format: "%.6f", step)).font(.caption.monospaced())
                    }
                    HStack {
                        Text("传送").font(.caption)
                        Slider(value: $teleport, in: 0.0002...0.02)
                        Text(String(format: "%.4f", teleport)).font(.caption.monospaced())
                    }
                    if let c = engine.current {
                        Text(String(format: "%.6f, %.6f", c.latitude, c.longitude))
                            .font(.callout.monospaced())
                    }
                    HStack {
                        Button("↑") { engine.nudge(dLat: teleport, dLon: 0) }
                        Button("↓") { engine.nudge(dLat: -teleport, dLon: 0) }
                        Button("←") { engine.nudge(dLat: 0, dLon: -teleport) }
                        Button("→") { engine.nudge(dLat: 0, dLon: teleport) }
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 28)
                }
            }
        }
    }
}
