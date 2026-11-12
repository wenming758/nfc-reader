import CoreNFC
import Foundation
import UIKit

/// 扫描方式：标签模式能拿到 UID 与技术类型，是门禁卡场景的首选。
enum NFCScanMode: String, CaseIterable, Identifiable {
    case tag
    case ndef

    var id: String { rawValue }

    var title: String {
        self == .tag ? "标签模式" : "NDEF 模式"
    }

    var caption: String {
        self == .tag ? "读 UID + 技术类型，门禁卡首选" : "只读 NDEF，兼容性最好"
    }
}

enum NFCScanState: Equatable {
    case idle
    case scanning
    case success(String)
    case failure(String)

    var isScanning: Bool { self == .scanning }
}

enum NFCScanError: LocalizedError {
    case unsupportedDevice
    case unsupportedTag
    case connectionFailed(String)
    case ndefReadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "当前设备不支持 NFC（模拟器或没有 NFC 芯片的机型）"
        case .unsupportedTag:
            return "暂不支持这类标签"
        case .connectionFailed(let reason):
            return "无法连接卡片：\(reason)"
        case .ndefReadFailed:
            return "NDEF 数据读取失败"
        }
    }
}

/// 封装两种 Core NFC 会话：
/// - `NFCTagReaderSession`：拿到 UID、技术类型，并尝试读取 NDEF；
/// - `NFCNDEFReaderSession`：只读 NDEF，用于兜底兼容。
/// 所有 UI 状态都在主线程发布，会话在退到后台时主动失效。
final class NFCManager: NSObject, ObservableObject {
    @Published private(set) var state: NFCScanState = .idle
    @Published private(set) var draft: NFCCard?
    @Published private(set) var mode: NFCScanMode = .tag
    @Published private(set) var isSupported: Bool

    private var tagSession: NFCTagReaderSession?
    private var ndefSession: NFCNDEFReaderSession?
    /// 用于区分「读取完成后的自动失效」与「异常失效」。
    private var didFinishSuccessfully = false
    private var reportedFailure = false
    /// 连续扫描时，等上一次会话真正释放后再启动新会话。
    private var isWaitingToRestart = false

    override init() {
        isSupported = NFCTagReaderSession.readingAvailable || NFCNDEFReaderSession.readingAvailable
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 对外控制

    func select(mode: NFCScanMode) {
        guard !state.isScanning else { return }
        self.mode = mode
    }

    func start() {
        guard isSupported else {
            state = .failure(NFCScanError.unsupportedDevice.localizedDescription)
            Haptics.error()
            return
        }

        // 上一次会话可能正在失效，稍等后再启动，避免「系统 NFC 忙」。
        if tagSession != nil || ndefSession != nil {
            guard !isWaitingToRestart else { return }
            isWaitingToRestart = true
            cancel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                self.isWaitingToRestart = false
                if self.tagSession == nil, self.ndefSession == nil {
                    self.start()
                } else {
                    self.state = .failure("系统 NFC 正忙，请稍后再试")
                }
            }
            return
        }

        didFinishSuccessfully = false
        reportedFailure = false
        draft = nil

        switch mode {
        case .tag: startTagSession()
        case .ndef: startNDEFSession()
        }
    }

    func cancel() {
        tagSession?.invalidate()
        ndefSession?.invalidate()
    }

    func clearDraft() {
        draft = nil
    }

    // MARK: - 会话创建

    private func startTagSession() {
        let session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        )
        session.alertMessage = "请将卡片贴近 iPhone 顶部"
        tagSession = session
        state = .scanning
        session.begin()
    }

    private func startNDEFSession() {
        let session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        session.alertMessage = "请将 NFC 标签靠近 iPhone 顶部"
        ndefSession = session
        state = .scanning
        session.begin()
    }

    // MARK: - 结果构建

    /// 把 Core NFC 的标签对象转换成可持久化的卡片模型。
    /// UID 一定能读到；NDEF 读取失败不会中断整个流程，只会降低可读性判定。
    private func makeCard(from tag: NFCTag) async throws -> NFCCard {
        var uid = ""
        var cardType: CardType = .miFareUnknown
        var details: [String] = []

        switch tag {
        case .miFare(let mifare):
            uid = mifare.identifier.hexString(separator: " ")
            switch mifare.mifareFamily {
            case .ultralight: cardType = .miFareUltralight
            case .plus: cardType = .miFarePlus
            case .desfire: cardType = .miFareDESFire
            default: cardType = .miFareUnknown
            }
            if let historical = mifare.historicalBytes {
                details.append("Historical Bytes：\(historical.hexString())")
            }
        case .iso15693(let iso15693):
            uid = iso15693.identifier.hexString(separator: " ")
            cardType = .iso15693
            details.append("厂商代码：\(iso15693.icManufacturerCode)")
            details.append("序列号：\(iso15693.icSerialNumber.hexString(separator: " "))")
        case .iso7816(let iso7816):
            uid = iso7816.identifier.hexString(separator: " ")
            cardType = .iso7816
            if let historical = iso7816.historicalBytes {
                details.append("Historical Bytes：\(historical.hexString())")
            }
            if let aid = iso7816.applicationData {
                details.append("AID 数据：\(aid.hexString())")
            }
        case .feliCa(let feliCa):
            uid = feliCa.currentIDm.hexString(separator: " ")
            cardType = .feliCa
            details.append(String(format: "系统码：0x%04X", feliCa.currentSystemCode))
        @unknown default:
            throw NFCScanError.unsupportedTag
        }

        var fields: [NDEFRecordField] = []
        var capacity: Int?
        var note = ""

        if let ndefTag = Self.ndefTag(from: tag) {
            do {
                let (status, ndefCapacity) = try await queryNDEFStatus(of: ndefTag)
                switch status {
                case .notSupported:
                    note = Self.readLimitNote(for: cardType)
                case .readOnly, .readWrite:
                    capacity = ndefCapacity
                    let message = try await readNDEF(from: ndefTag)
                    fields = message.records.map(Self.parse(payload:))
                default:
                    note = "未知的 NDEF 状态，可能是专用卡片。"
                }
            } catch {
                note = "NDEF 读取失败：\(Self.describe(error))"
            }
        }

        let compatibility: CardCompatibility
        if !fields.isEmpty {
            compatibility = .full
        } else if !uid.isEmpty {
            compatibility = .uidOnly
            if note.isEmpty {
                note = Self.readLimitNote(for: cardType)
            }
        } else {
            compatibility = .unsupported
            if note.isEmpty {
                note = "没有读取到 UID。"
            }
        }

        return NFCCard(
            name: "",
            category: .other,
            note: note,
            uid: uid,
            cardType: cardType,
            compatibility: compatibility,
            capacity: capacity,
            details: details,
            fields: fields,
            payloadHex: fields.map(\.payloadHex).joined(separator: "  |  ")
        )
    }

    private static func readLimitNote(for type: CardType) -> String {
        switch type {
        case .miFareUltralight:
            return "卡片未写入 NDEF，只记录 UID。"
        case .miFarePlus, .miFareDESFire, .miFareUnknown:
            return "Apple 不开放加密扇区访问，只能读取 UID，无法读取或复制门禁数据。"
        case .iso7816:
            return "CPU 卡需要指定 AID 才能读取应用数据，这里只记录 UID。"
        case .iso15693:
            return "仅记录 UID 与厂商信息。"
        case .feliCa:
            return "FeliCa 仅记录 IDm，门禁应用数据不对外开放。"
        case .ndef:
            return "未解析到 NDEF 记录。"
        }
    }

    // MARK: - NDEF 异步封装

    private func queryNDEFStatus(of tag: NFCNDEFTag) async throws -> (NFCNDEFStatus, Int) {
        try await withCheckedThrowingContinuation { continuation in
            tag.queryNDEFStatus { status, capacity, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (status, capacity))
                }
            }
        }
    }

    private func readNDEF(from tag: NFCNDEFTag) async throws -> NFCNDEFMessage {
        try await withCheckedThrowingContinuation { continuation in
            tag.readNDEF { message, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let message {
                    continuation.resume(returning: message)
                } else {
                    continuation.resume(throwing: NFCScanError.ndefReadFailed)
                }
            }
        }
    }

    // MARK: - 发布与反馈

    private func publish(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async(execute: updates)
        }
    }

    private func handleInvalidation(_ error: Error) {
        guard !didFinishSuccessfully, !reportedFailure else {
            publish { if case .scanning = self.state { self.state = .idle } }
            return
        }

        // NFCReaderError 的失效码：1/5 用户取消，2/6 超时，3/7 系统忙，4/8 首次读取完成。
        let code = (error as NSError).code
        switch code {
        case 0, 4, 8:
            publish { if case .scanning = self.state { self.state = .idle } }
        case 1, 5:
            publish { self.state = .idle }
        case 2, 6:
            publish {
                self.state = .failure("未识别到卡片。125kHz ID 卡或加密 M1 卡无法被 iPhone 读取，详见「读取说明」。")
            }
            Haptics.error()
        case 3, 7:
            publish { self.state = .failure("系统 NFC 服务忙，请稍后再试") }
            Haptics.error()
        default:
            publish { self.state = .failure("扫描结束：\(error.localizedDescription)") }
        }
    }

    @objc private func handleDidEnterBackground() {
        guard state.isScanning else { return }
        cancel()
    }

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static func ndefTag(from tag: NFCTag) -> NFCNDEFTag? {
        switch tag {
        case .miFare(let tag): return tag
        case .iso15693(let tag): return tag
        case .iso7816(let tag): return tag
        case .feliCa(let tag): return tag
        @unknown default: return nil
        }
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        tagSession = nil
        handleInvalidation(error)
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "未检测到可用卡片")
            return
        }
        guard tags.count == 1 else {
            session.invalidate(errorMessage: "检测到多张卡片，请一次只贴近一张")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await session.connect(to: tag)
                let card = try await self.makeCard(from: tag)
                session.alertMessage = "读取成功"
                self.didFinishSuccessfully = true
                self.publish {
                    self.draft = card
                    self.state = .success(card.uid.isEmpty ? "NDEF 数据已读取" : "UID \(card.uid)")
                }
                Haptics.success()
                session.invalidate()
            } catch {
                let message = Self.describe(error)
                self.reportedFailure = true
                session.invalidate(errorMessage: message)
                self.publish { self.state = .failure(message) }
                Haptics.error()
            }
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        ndefSession = nil
        handleInvalidation(error)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let fields = messages.flatMap { $0.records }.map(Self.parse(payload:))
        let card = NFCCard(
            name: "",
            category: .other,
            note: fields.isEmpty ? "未解析到可显示的 NDEF 记录。" : "",
            uid: "",
            cardType: .ndef,
            compatibility: fields.isEmpty ? .unsupported : .full,
            fields: fields,
            payloadHex: fields.map(\.payloadHex).joined(separator: "  |  ")
        )

        didFinishSuccessfully = true
        publish {
            self.draft = card
            self.state = .success(fields.isEmpty ? "已读取（无记录）" : "NDEF 数据已读取")
        }
        Haptics.success()
    }
}

// MARK: - NDEF 解析

extension NFCManager {
    /// iPhone 上最常见的 URI 前缀，索引对应 NFC Forum URI Record 的首字节。
    private static let uriPrefixes = [
        "", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:",
        "ftp://anonymous:anonymous@", "ftp://ftp.", "ftps://", "sftp://", "smb://", "nfs://",
        "ftp://", "dav://", "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:",
        "sip:", "sips:", "tftp:", "btspp://", "btl2cap://", "btgoep://", "tcpobex://",
        "irdaobex://", "file://", "urn:epc:id:", "urn:epc:tag:", "urn:epc:pat:",
        "urn:epc:raw:", "urn:epc:", "urn:nfc:"
    ]

    private static func parse(payload: NFCNDEFPayload) -> NDEFRecordField {
        let typeString = String(data: payload.type, encoding: .utf8) ?? ""
        let hex = payload.payload.hexString()

        switch payload.typeNameFormat {
        case .nfcWellKnown:
            if typeString == "T", let text = decodeText(payload.payload) {
                return NDEFRecordField(typeName: "文本 (T)", value: text, payloadHex: hex)
            }
            if typeString == "U", let uri = decodeURI(payload.payload) {
                return NDEFRecordField(typeName: "链接 (U)", value: uri, payloadHex: hex)
            }
            return NDEFRecordField(typeName: "NDEF 记录 (\(typeString))", value: hex, payloadHex: hex)

        case .media:
            let mime = typeString.isEmpty ? "未知 MIME" : typeString
            let value = String(data: payload.payload, encoding: .utf8) ?? hex
            return NDEFRecordField(typeName: "MIME (\(mime))", value: value, payloadHex: hex)

        case .absoluteURI:
            let uri = typeString.isEmpty ? hex : typeString
            return NDEFRecordField(typeName: "绝对 URI", value: uri, payloadHex: hex)

        case .nfcExternal:
            return NDEFRecordField(typeName: "外部类型 (\(typeString))", value: hex, payloadHex: hex)

        case .empty:
            return NDEFRecordField(typeName: "空记录", value: "—", payloadHex: hex)

        default:
            return NDEFRecordField(typeName: "未知记录", value: hex, payloadHex: hex)
        }
    }

    /// Text 记录首字节：最高位是编码（0 = UTF-8，1 = UTF-16），低 6 位是语言码长度。
    private static func decodeText(_ data: Data) -> String? {
        guard let statusByte = data.first else { return nil }
        let languageLength = Int(statusByte & 0x3F)
        guard data.count > 1 + languageLength else { return nil }
        let textData = data.subdata(in: (1 + languageLength)..<data.count)
        let encoding: String.Encoding = (statusByte & 0x80) != 0 ? .utf16 : .utf8
        return String(data: textData, encoding: encoding)
    }

    /// URI 记录首字节是前缀索引，剩余部分为 UTF-8 字符串。
    private static func decodeURI(_ data: Data) -> String? {
        guard let prefixIndex = data.first,
              Int(prefixIndex) < uriPrefixes.count,
              data.count > 1,
              let rest = String(data: data.dropFirst(), encoding: .utf8) else {
            return nil
        }
        return uriPrefixes[Int(prefixIndex)] + rest
    }
}

// MARK: - 触觉反馈

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
