import Foundation
import Combine
import WebRTC

final class ContentViewModel: ObservableObject {
    @Published var signallingStatus = "Not connected ❌"
    @Published var localSDP = "Not found ❌"
    @Published var localCandidates = 0
    @Published var remoteSDP = "Not found ❌"
    @Published var remoteCandidates = 0
    @Published var webRTCStatus = "New"
    @Published var message = ""
    @Published var lastSpeakerMessage = ""
    
    private var networkService: NetworkService
    private var webRTCService: WebRTCServiceProtocol
    
    init(
        networkService: NetworkService,
        webRTCService: WebRTCServiceProtocol
    ) {
        self.networkService = networkService
        self.webRTCService = webRTCService
        
        self.networkService.delegate = self
        self.webRTCService.delegate = self
        
        connect()
    }
    
    func connect() {
        networkService.connect()
    }
    
    func sendOffer() {
        webRTCService.setLocalDescription(.offer) { [weak self] result in
            switch result {
                case let .success(sessionDescription):
                    DispatchQueue.main.async {
                        self?.localSDP = "Found ✅"
                    }
                    let message = Message.sdp(
                        SessionDescription(from: sessionDescription)
                    )
                    self?.networkService.send(message: message)
                case .failure(_):
                    print("failure offer")
                    break
            }
        }
    }
    
    func sendAnswer() {
        webRTCService.setLocalDescription(.answer) { [weak self] result in
            switch result {
                case let .success(localDescription):
                    self?.networkService.send(message: Message.sdp(SessionDescription(from: localDescription)))
                case .failure(_):
                    print("failure answer")
                    break
            }
        }
    }
    
    func sendMessage() {
        webRTCService.sendMessage(message)
    }
    
    func muteSpeaker() {
        webRTCService.speakerIsMuted(true)
    }
    
    func muteAudio() {
        webRTCService.audioIsMuted(true)
    }
}

extension ContentViewModel: NetworkServiceDelegate {
    func gotSessionDescription(sdp: SessionDescription) {
        webRTCService.setRemoteDescription(
            sessionDescription: sdp.toRTCSessionDescription()
        )
        DispatchQueue.main.async { [weak self] in
            self?.remoteSDP = "Found ✅"
        }
        
    }
    
    func gotIceCandidate(candidate: IceCandidate) {
        webRTCService.setCandidate(candidate.toRTCIceCandidate())
        DispatchQueue.main.async { [weak self] in
            self?.remoteCandidates += 1
        }
    }
    
    func socketConnected() {
        DispatchQueue.main.async { [weak self] in
            self?.signallingStatus = "Connected ✅"
        }
    }
}

extension ContentViewModel: WebRTCServiceDelegate {
    func gotIceCandidate(iceCandidate: RTCIceCandidate) {
        networkService.send(message: Message.candidate(IceCandidate(from: iceCandidate)))
        DispatchQueue.main.async { [weak self] in
            self?.localSDP = "Found ✅"
            self?.localCandidates += 1
        }
    }
    
    func gotConnectionState(state: RTCIceConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.webRTCStatus = state.description
        }
    }
    
    func gotMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastSpeakerMessage = message
        }
    }
}

extension ContentViewModel: VideoViewDelegate {
    func startCapture(_ view: RTCMTLVideoView, type: VideoType) {
        switch type {
            case .remote:
                webRTCService.renderRemoteVideo(to: view)
            case .local:
                webRTCService.startCaptureLocalVideo(renderer: view)
        }
        
    }
}
