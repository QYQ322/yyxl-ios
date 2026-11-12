import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RouteStore
    @EnvironmentObject var engine: RoutePlaybackEngine
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            MapScreen()
                .tabItem { Label("地图", systemImage: "map") }
                .tag(0)

            RouteListScreen()
                .tabItem { Label("路线", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                .tag(1)

            JoystickOverlay()
                .tabItem { Label("摇杆", systemImage: "arcade.stick") }
                .tag(2)

            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Color(red: 0.05, green: 0.56, blue: 0.58))
    }
}
