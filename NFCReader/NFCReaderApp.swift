import SwiftUI

@main
struct NFCReaderApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var nfc = NFCManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(nfc)
                .preferredColorScheme(.dark)
        }
    }
}
