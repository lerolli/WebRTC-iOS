import SwiftUI
import WebRTC

@main
struct WebRTCExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: .init(
                    networkService: NetworkService(),
                    webRTCService: WebRTCService()
                )
            )
        }
    }
}
