import Foundation

/// 卡片持久化仓库：以 JSON 写入 Keychain，最多保留 200 张。
/// 相同 UID + 相同技术类型的卡片再次扫描时只更新读取时间与内容，不会重复添加。
final class CardStore: ObservableObject {
    @Published private(set) var cards: [NFCCard] = []
    @Published private(set) var lastError: String?

    private let account = "nfc.card.vault"
    private let limit = 200

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        load()
    }

    /// 返回 true 表示新增，false 表示更新了已有卡片。
    @discardableResult
    func upsert(_ card: NFCCard) -> Bool {
        if let index = cards.firstIndex(where: { matches($0, card) }) {
            cards[index].lastSeenAt = Date()
            cards[index].scanCount += 1
            cards[index].details = card.details
            cards[index].fields = card.fields
            cards[index].payloadHex = card.payloadHex
            cards[index].capacity = card.capacity
            if cards[index].note.isEmpty {
                cards[index].note = card.note
            }
            persist()
            return false
        }

        var newCard = card
        newCard.firstSeenAt = Date()
        newCard.lastSeenAt = Date()
        newCard.scanCount = 1
        cards.insert(newCard, at: 0)
        if cards.count > limit {
            cards.removeLast(cards.count - limit)
        }
        persist()
        return true
    }

    func rename(_ name: String, for id: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].name = trimmed
        persist()
    }

    func setCategory(_ category: CardCategory, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].category = category
        persist()
    }

    func setNote(_ note: String, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func delete(id: UUID) {
        cards.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        cards.removeAll()
        KeychainStore.delete(account: account)
    }

    func defaultName(for category: CardCategory) -> String {
        let count = cards.filter { $0.category == category }.count + 1
        return "\(category.title) \(count)"
    }

    private func matches(_ lhs: NFCCard, _ rhs: NFCCard) -> Bool {
        guard !lhs.uid.isEmpty, !rhs.uid.isEmpty else { return false }
        return lhs.uid == rhs.uid && lhs.cardType == rhs.cardType
    }

    private func load() {
        guard let data = KeychainStore.load(account: account) else { return }
        do {
            cards = try decoder.decode([NFCCard].self, from: data)
        } catch {
            lastError = "卡片数据解析失败：\(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try KeychainStore.save(encoder.encode(cards), account: account)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
