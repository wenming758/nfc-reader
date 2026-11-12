import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            VaultView(selectedTab: $selectedTab)
                .tabItem { Label("卡包", systemImage: "square.stack.3d.up.fill") }
                .tag(0)

            ScanView()
                .tabItem { Label("扫描", systemImage: "wave.3.right") }
                .tag(1)
        }
        .tint(Theme.accent)
    }
}
