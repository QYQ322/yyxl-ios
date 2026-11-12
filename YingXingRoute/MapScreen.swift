import SwiftUI
import MapKit

/// 地图层：对应 Android 端百度地图 SDK (BaiduMapSDK_map + libindoor 室内图)
/// iOS 侧用 MapKit 复刻；如必须与安卓端图层一致，可替换为百度地图 iOS SDK (BMKMapView)
struct MapScreen: View {
    @EnvironmentObject var store: RouteStore
    @EnvironmentObject var engine: RoutePlaybackEngine
    @State private var selected: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            MapKitView(
                routes: store.routes,
                selectedID: selected ?? store.routes.first?.id,
                current: engine.current.map { CoordConv.project($0, from: store.inputDatum) },
                datum: store.inputDatum
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                HStack {
                    Text(engine.currentRouteName)
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.1f%%", engine.progress * 100))
                        .monospacedDigit()
                }
                ProgressView(value: engine.progress)
                HStack(spacing: 12) {
                    Button(engine.isRunning ? "暂停" : "开始") {
                        if engine.isRunning { engine.pause() }
                        else if let r = store.routes.first(where: { $0.id == (selected ?? store.routes.first?.id) }) {
                            engine.start(r)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("停止") { engine.stop() }
                        .buttonStyle(.bordered)

                    Spacer()

                    if let c = engine.current {
                        Text(String(format: "%.6f, %.6f", c.latitude, c.longitude))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }
}

struct MapKitView: UIViewRepresentable {
    var routes: [RouteDoc]
    var selectedID: UUID?
    var current: CLLocationCoordinate2D?
    var datum: CoordDatum = .bd09

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.showsUserLocation = false
        mv.pointOfInterestFilter = .includingAll
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        mv.removeOverlays(mv.overlays)
        mv.removeAnnotations(mv.annotations)

        if let rid = selectedID, let r = routes.first(where: { $0.id == rid }), r.points.count > 1 {
            var coords = r.points.map { CoordConv.project($0.coordinate, from: datum) }
            let line = MKPolyline(coordinates: &coords, count: coords.count)
            mv.addOverlay(line)
            mv.addAnnotations(r.points.enumerated().map { idx, p in
                let a = MKPointAnnotation()
                a.coordinate = CoordConv.project(p.coordinate, from: datum)
                a.title = "P\(idx + 1)"
                return a
            })
            if context.coordinator.lastRouteID != rid {
                context.coordinator.lastRouteID = rid
                mv.setVisibleMapRect(line.boundingMapRect,
                                     edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 220, right: 40),
                                     animated: false)
            }
        }

        if let c = current {
            mv.removeAnnotations(mv.annotations.filter { $0.title == "●" })
            let a = MKPointAnnotation()
            a.coordinate = c
            a.title = "●"
            mv.addAnnotation(a)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastRouteID: UUID?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: line)
            r.strokeColor = UIColor(red: 0.05, green: 0.56, blue: 0.58, alpha: 1)
            r.lineWidth = 5
            r.lineJoin = .round
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation.title == "●" else { return nil }
            let id = "cur"
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.markerTintColor = .systemOrange
            v.glyphText = "●"
            return v
        }
    }
}
