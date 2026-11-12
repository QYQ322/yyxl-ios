import Foundation
import CoreNFC
import CoreLocation

/// 对应 Android: NfcJumpActivity + android.hardware.nfc 权限
/// NDEF 内容约定: "yyxl:route:<路线名>" 或 "yyxl:coord:<lat>,<lon>"
final class NfcBridge: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var lastPayload: String?
    @Published var status: String = "空闲"

    private var session: NFCNDEFReaderSession?
    var onRoute: ((String) -> Void)?
    var onCoordinate: ((CLLocationCoordinate2D) -> Void)?

    func scan() {
        guard NFCNDEFReaderSession.readingAvailable else {
            status = "本机不支持 NFC 读取"
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "将 NFC 标签靠近手机顶部"
        session?.begin()
        status = "扫描中…"
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { self.status = "结束: \(error.localizedDescription)" }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for m in messages {
            for rec in m.records {
                guard let s = String(data: rec.payload, encoding: .utf8) else { continue }
                let text = s.replacingOccurrences(of: "\u{02}zh", with: "")
                    .replacingOccurrences(of: "\u{02}en", with: "")
                DispatchQueue.main.async {
                    self.lastPayload = text
                    self.status = "读到: \(text)"
                    self.handle(text)
                }
            }
        }
    }

    private func handle(_ text: String) {
        if text.hasPrefix("yyxl:route:") {
            onRoute?(String(text.dropFirst("yyxl:route:".count)))
        } else if text.hasPrefix("yyxl:coord:") {
            let parts = text.dropFirst("yyxl:coord:".count).split(separator: ",")
            if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
                onCoordinate?(CLLocationCoordinate2D(latitude: a, longitude: b))
            }
        }
    }
}
