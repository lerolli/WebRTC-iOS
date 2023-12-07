import Foundation
import WebRTC

enum SessionDescriptionType: String, Codable {
    case offer
    case prAnswer
    case answer
    case rollback
    
    func toRTCSessionDescriptionType() -> RTCSdpType {
        switch self {
            case .offer:
                return .offer
            case .answer:
                return .answer
            case .prAnswer: 
                return .prAnswer
            case .rollback: 
                return .rollback
        }
    }
}

struct SessionDescription: Codable {
    let sdp: String
    let type: SessionDescriptionType
    
    init(from rtcSessionDescription: RTCSessionDescription) {
        self.sdp = rtcSessionDescription.sdp
        
        switch rtcSessionDescription.type {
            case .offer:
                self.type = .offer
            case .prAnswer: 
                self.type = .prAnswer
            case .answer:   
                self.type = .answer
            case .rollback: 
                self.type = .rollback
            default:
                fatalError("Unknown RTCSessionDescription type: \(rtcSessionDescription.type.rawValue)")
        }
    }
    
    func toRTCSessionDescription() -> RTCSessionDescription {
        RTCSessionDescription(
            type: type.toRTCSessionDescriptionType(),
            sdp: sdp
        )
    }
}
