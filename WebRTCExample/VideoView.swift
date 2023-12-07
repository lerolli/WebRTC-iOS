import SwiftUI
import WebRTC

enum VideoType {
    case remote
    case local
}

protocol VideoViewDelegate: AnyObject {
    func startCapture(_ view: RTCMTLVideoView, type: VideoType)
}

struct VideoView: UIViewRepresentable {
    var delegate: VideoViewDelegate
    let type: VideoType
    
    func makeUIView(context: Context) -> UIView {
        let renderer = RTCMTLVideoView()
        renderer.videoContentMode = .scaleAspectFill
        renderer.backgroundColor = .black
        delegate.startCapture(renderer, type: type)
        return renderer
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
