import Foundation
import SocketIO
import Combine

protocol NetworkServiceDelegate: AnyObject {
    func gotSessionDescription(sdp: SessionDescription)
    func gotIceCandidate(candidate: IceCandidate)
    func socketConnected()
}

final class NetworkService {
    weak var delegate: NetworkServiceDelegate?
    
    private let host: URL
    private let manager: SocketManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var socket: SocketIOClient?
    
    init() {
        guard let url = URL(string: "http://localhost:8080") else {
            fatalError("Incorrect host")
        }
        
        host = url
        manager = SocketManager(
            socketURL: host,
            config: [.compress]
        )
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }
        
    func connect() {
        socket = manager.defaultSocket

        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            self?.delegate?.socketConnected()
        }
        
        socket?.connect()
        
        socket?.on("stream") { [weak self] data, ack in
            guard let data = data.first as? Data
            else { return }
            self?.decodeMessage(data)
        }
    }
    
    func decodeMessage(_ data: Data) {
        let message: Message
        do {
            message = try decoder.decode(Message.self, from: data)
        }
        catch {
            print("ERROR, \(error)")
            return
        }
        
        switch message {
            case .sdp(let sessionDescription):
                delegate?.gotSessionDescription(sdp: sessionDescription)
            case .candidate(let iceCandidate):
                delegate?.gotIceCandidate(candidate: iceCandidate)
        } 
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
    }
    
    func send(message: Message) {
        do {
            let data = try encoder.encode(message)
            socket?.emit("stream", data)
        }
        catch {}
    }
}
