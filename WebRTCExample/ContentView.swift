import SwiftUI
import WebRTC

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(spacing: 20.0) {
            HStack() {
                Text("WebRTC Example")
                    .font(.title)
                    .bold()
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Socket connection status")
                        .bold()
                    Text(viewModel.signallingStatus)
                }
                Spacer()
            }
            
            HStack(spacing: 20.0) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Local SDP")
                            .bold()
                        Text(String(viewModel.localCandidates))
                    }
                    Text(viewModel.localSDP)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Remote SDP")
                            .bold()
                        Text(String(viewModel.remoteCandidates))
                    }
                    Text(viewModel.remoteSDP)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("WebRTC connection status")
                        .bold()
                    Text(viewModel.webRTCStatus)
                }
                Spacer()
            }
            
            HStack {
                VideoView(delegate: viewModel, type: .remote)
                VideoView(delegate: viewModel, type: .local)
            }
            .frame(maxWidth: 200, maxHeight: 200)
            
            HStack {
                Button("Mute audio") {
                    viewModel.muteAudio()
                }.disabled(viewModel.webRTCStatus != "connected")
                
                Spacer()
                
                Button("Mute speaker") {
                    viewModel.muteSpeaker()
                }.disabled(viewModel.webRTCStatus != "connected")
            }
            
            HStack {
                TextField(
                    "Send a message",
                    text: $viewModel.message
                )
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.webRTCStatus != "connected")
                
                Button("Send") {
                    viewModel.sendMessage()
                }.disabled(viewModel.webRTCStatus != "connected")
                
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Last speaker message")
                        .bold()
                    
                    Text(viewModel.lastSpeakerMessage)
                }
                Spacer()
            }
            
            HStack {
                Button("Send offer") {
                    viewModel.sendOffer()
                }.buttonStyle(.borderedProminent)
                
                Button("Send answer") {
                    viewModel.sendAnswer()
                }.buttonStyle(.borderedProminent)
            }
            
                        
            
            Spacer()
            
        }
        .padding(.horizontal, 16.0)
    }
}


#Preview {
    ContentView(
        viewModel: .init(
            networkService: NetworkService(),
            webRTCService: WebRTCService()
        )
    ).previewDevice("iPhone 13 pro")
}
