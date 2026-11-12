import SwiftUI

@main
struct YingXingRouteApp: App {
    @StateObject private var store = RouteStore()
    @StateObject private var engine = RoutePlaybackEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .onAppear { engine.attach(store: store) }
        }
    }
}
