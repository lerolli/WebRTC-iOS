import Foundation
import WebRTC
import Combine

enum Signaling {
    case offer
    case answer
}

protocol WebRTCServiceDelegate: AnyObject {
    func gotIceCandidate(iceCandidate: RTCIceCandidate)
    func gotConnectionState(state: RTCIceConnectionState)
    func gotMessage(_ message: String)
}


protocol WebRTCServiceProtocol {
    var delegate: WebRTCServiceDelegate? { get set }
    
    func setLocalDescription(
        _ signaling: Signaling,
        completion: @escaping (Result<RTCSessionDescription, Error>) -> Void
    )
    func setRemoteDescription(sessionDescription: RTCSessionDescription)
    func setCandidate(_ candidate: RTCIceCandidate)
    func audioIsMuted(_ isMuted: Bool)
    func speakerIsMuted(_ isMuted: Bool)
    func startCaptureLocalVideo(renderer: RTCMTLVideoView)
    func stopCaptureLocalVideo()
    func renderRemoteVideo(to renderer: RTCMTLVideoView)
    func sendMessage(_ message: String)
}


final class WebRTCService: NSObject {
    weak var delegate: WebRTCServiceDelegate?
    
    private let factory: RTCPeerConnectionFactory
    private let peerConnection: RTCPeerConnection
    
    private var audioSession: RTCAudioSession?
    private var videoCapturer: RTCCameraVideoCapturer?

    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var localDataChannel: RTCDataChannel?
    
    private var remoteVideoTrack: RTCVideoTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var remoteDataChannel: RTCDataChannel?
    
    override init() {
        guard RTCInitializeSSL() else {
            fatalError("Cannot initialize SSL")
        }
        
        factory = RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
        
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually
        configuration.iceServers = [RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ])]
        
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )
        
        guard let peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        
        self.peerConnection = peerConnection
        super.init()
        configureAudioSession()
        
        
        createMediaSenders()
        self.peerConnection.delegate = self
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        
        // Cоздание аудиоканала
        let audioTrack = createAudioTrack()
        peerConnection.add(audioTrack, streamIds: [streamId])
        
        // Cоздание видеоканала
        let videoTrack = createVideoTrack()
        localVideoTrack = videoTrack
        peerConnection.add(videoTrack, streamIds: [streamId])
        remoteVideoTrack = peerConnection.transceivers
            .first { $0.mediaType == .video }?
            .receiver.track as? RTCVideoTrack
        
        // Cоздание data канала, например, для отправки сообщения
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            localDataChannel = dataChannel
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioSource = factory.audioSource(with: nil)
        let audioTrack = factory.audioTrack(
            with: audioSource,
            trackId: "audio0"
        )
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }
    
    // MARK: Data Channels
    private func createDataChannel() -> RTCDataChannel? {
        peerConnection.dataChannel(
            forLabel: "WebRTCData",
            configuration: RTCDataChannelConfiguration()
        )
    }
    
    private func configureAudioSession() {
        audioSession = .sharedInstance()
        audioSession?.lockForConfiguration()
        do {
            try audioSession?.setCategory(.playAndRecord)
            try audioSession?.setMode(.voiceChat)
        } catch let error {
            debugPrint("Error changing AVAudioSession category: \(error)")
        }
        audioSession?.unlockForConfiguration()
    }
    
    func setRemoteCandidate(_ candidate: RTCIceCandidate) {
        peerConnection.add(candidate) { error in
            if let error { print(error.localizedDescription) }
        }
    }
}

extension WebRTCService: WebRTCServiceProtocol {
    func setLocalDescription(
        _ signaling: Signaling,
        completion: @escaping (Result<RTCSessionDescription, Error>) -> Void
    ) {
        let handler: (RTCSessionDescription?, Error?) -> Void = { [weak self] localDescription, error in
            if let error { completion(.failure(error)) }
            
            guard let localDescription else { return }
            self?.peerConnection.setLocalDescription(localDescription) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(localDescription))
                }
            }
        }
        
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )
        
        switch signaling {
            case .offer:
                peerConnection.offer(for: constrains, completionHandler: handler)
            case .answer:
                peerConnection.answer(for: constrains, completionHandler: handler)
        }
    }
    
    func setRemoteDescription(sessionDescription: RTCSessionDescription) {
        peerConnection.setRemoteDescription(sessionDescription) { error in
            if let error { print(error.localizedDescription) }
        }
    }
    
    func setCandidate(_ candidate: RTCIceCandidate) {
        peerConnection.add(candidate) { error in
            if let error { print(error.localizedDescription) }
        }
    }
    
    func audioIsMuted(_ isMuted: Bool) {
        peerConnection.transceivers
            .compactMap { $0.sender.track as? RTCAudioTrack }
            .forEach { $0.isEnabled = isMuted }
        
    }
    
    func speakerIsMuted(_ isMuted: Bool) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            
            self.audioSession?.lockForConfiguration()
            do {
                try self.audioSession?.setCategory(.playAndRecord)
                if isMuted {
                    try self.audioSession?.overrideOutputAudioPort(.none)
                } else {
                    try self.audioSession?.overrideOutputAudioPort(.speaker)
                    try self.audioSession?.setActive(true)
                }
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.audioSession?.unlockForConfiguration()
        }
    }

    func startCaptureLocalVideo(renderer: RTCMTLVideoView) {
        guard let frontCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else { return }
        
        videoCapturer?.startCapture(
            with: frontCamera,
            format: frontCamera.activeFormat,
          
            fps: 30
        )
        localVideoTrack?.add(renderer)
    }
    
    func stopCaptureLocalVideo() {
        videoCapturer?.stopCapture()
    }
    
    func renderRemoteVideo(to renderer: RTCMTLVideoView) {
        remoteVideoTrack?.add(renderer)
    }
    
    func sendMessage(_ message: String) {
        guard let data = message.data(using: .utf8)
        else { return }
        
        let buffer = RTCDataBuffer(
            data: data,
            isBinary: true
        )
        remoteDataChannel?.sendData(buffer)
    }
}

extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange stateChanged: RTCSignalingState
    ) {}
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd stream: RTCMediaStream
    ) {}
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didRemove stream: RTCMediaStream
    ) {}
    
    func peerConnectionShouldNegotiate(
        _ peerConnection: RTCPeerConnection
    ) {}
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange newState: RTCIceConnectionState
    ) {
        delegate?.gotConnectionState(state: newState)
    }
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange newState: RTCIceGatheringState
    ) {
        print("peerConnection didChange RTCIceGatheringState \(newState)")
    }
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didGenerate candidate: RTCIceCandidate
    ) {
        delegate?.gotIceCandidate(iceCandidate: candidate)
    }
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didRemove candidates: [RTCIceCandidate]
    ) {
        print("peerConnection didRemove RTCIceCandidates \(candidates)")
    }
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didOpen dataChannel: RTCDataChannel
    ) {
        remoteDataChannel = dataChannel
        print("peerConnection didOpen dataChannel: RTCDataChannel")
    }
}

extension WebRTCService: RTCDataChannelDelegate {
    func dataChannelDidChangeState(
        _ dataChannel: RTCDataChannel
    ) {}
    
    func dataChannel(
        _ dataChannel: RTCDataChannel,
        didReceiveMessageWith buffer: RTCDataBuffer
    ) {
        let message = String(
            data: buffer.data,
            encoding: .utf8
        ) ?? "(Binary: \(buffer.data.count) bytes)"
        delegate?.gotMessage(message)
    }
}
