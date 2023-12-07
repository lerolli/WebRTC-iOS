import Foundation
import WebRTC

struct IceCandidate: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    
    init(from iceCandidate: RTCIceCandidate) {
        sdpMLineIndex = iceCandidate.sdpMLineIndex
        sdpMid = iceCandidate.sdpMid
        sdp = iceCandidate.sdp
    }
    
    func toRTCIceCandidate() -> RTCIceCandidate {
        RTCIceCandidate(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: self.sdpMid
        )
    }
}
