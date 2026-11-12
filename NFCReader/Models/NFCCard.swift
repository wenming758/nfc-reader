import Foundation

/// 卡片用途分类，用于卡包分组与命名。
enum CardCategory: String, Codable, CaseIterable, Identifiable {
    case access
    case scooter
    case home
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .access: return "小区门禁"
        case .scooter: return "电动车"
        case .home: return "家门"
        case .other: return "其他"
        }
    }
}

/// Core NFC 实际能识别到的卡片技术类型。
enum CardType: String, Codable {
    case ndef
    case miFareUltralight
    case miFarePlus
    case miFareDESFire
    case miFareUnknown
    case iso15693
    case iso7816
    case feliCa

    var title: String {
        switch self {
        case .ndef: return "NDEF 标签"
        case .miFareUltralight: return "Mifare Ultralight / NTAG"
        case .miFarePlus: return "Mifare Plus"
        case .miFareDESFire: return "Mifare DESFire"
        case .miFareUnknown: return "Mifare 卡片"
        case .iso15693: return "ISO 15693 (NFC-V)"
        case .iso7816: return "CPU 卡 (ISO 7816)"
        case .feliCa: return "FeliCa (NFC-F)"
        }
    }
}

/// 这张卡在本机上到底能读到什么，避免用户误以为已经“复制”了门禁卡。
enum CardCompatibility: String, Codable {
    case full
    case uidOnly
    case unsupported

    var title: String {
        switch self {
        case .full: return "可完整读取"
        case .uidOnly: return "仅能读取 UID"
        case .unsupported: return "无法读取"
        }
    }

    var detail: String {
        switch self {
        case .full: return "UID 与 NDEF 内容均已读取。"
        case .uidOnly: return "iPhone 只开放 UID 与公开技术信息，加密扇区无法读取。"
        case .unsupported: return "iPhone 无法读取这类卡片。"
        }
    }
}

/// 单条 NDEF 记录的展示模型。
struct NDEFRecordField: Identifiable, Codable, Hashable {
    let id: UUID
    let typeName: String
    let value: String
    let payloadHex: String

    init(id: UUID = UUID(), typeName: String, value: String, payloadHex: String) {
        self.id = id
        self.typeName = typeName
        self.value = value
        self.payloadHex = payloadHex
    }
}

/// 保存在卡包里的一张卡片。
struct NFCCard: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: CardCategory
    var note: String
    let uid: String
    let cardType: CardType
    let compatibility: CardCompatibility
    var capacity: Int?
    var details: [String]
    var fields: [NDEFRecordField]
    var payloadHex: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var scanCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: CardCategory,
        note: String = "",
        uid: String,
        cardType: CardType,
        compatibility: CardCompatibility,
        capacity: Int? = nil,
        details: [String] = [],
        fields: [NDEFRecordField] = [],
        payloadHex: String = "",
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        scanCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.note = note
        self.uid = uid
        self.cardType = cardType
        self.compatibility = compatibility
        self.capacity = capacity
        self.details = details
        self.fields = fields
        self.payloadHex = payloadHex
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.scanCount = scanCount
    }

    var uidDisplay: String { uid.isEmpty ? "无 UID" : uid }
}

extension NFCCard {
    static let sample = NFCCard(
        name: "小区北门",
        category: .access,
        note: "物业发的蓝色圆卡",
        uid: "04 8A 2F 1A 6C 61 80",
        cardType: .miFareUltralight,
        compatibility: .full,
        capacity: 137,
        details: ["Historical Bytes：03 00"],
        fields: [
            NDEFRecordField(typeName: "文本 (T)", value: "访客通行证 · A-1024", payloadHex: "02 7A 68"),
            NDEFRecordField(typeName: "链接 (U)", value: "https://example.com/pass/a-1024", payloadHex: "04 65 78")
        ],
        payloadHex: "02 7A 68  |  04 65 78"
    )
}

extension Data {
    /// 统一的 Hex 展示格式，例如 `04 8A 2F`。
    func hexString(separator: String = " ") -> String {
        map { String(format: "%02X", $0) }.joined(separator: separator)
    }
}
