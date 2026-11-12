import SwiftUI
import UIKit

struct CardDetailView: View {
    let cardID: UUID

    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var showRename = false
    @State private var newName = ""
    @State private var showDelete = false
    @State private var noteDraft = ""
    @State private var didCopy = false

    private var card: NFCCard? {
        store.cards.first { $0.id == cardID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let card {
                    content(card)
                } else {
                    Text("卡片已删除")
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(card?.name ?? "卡片详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            newName = card?.name ?? ""
                            showRename = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Menu("修改分类") {
                            ForEach(CardCategory.allCases) { category in
                                Button {
                                    store.setCategory(category, for: cardID)
                                } label: {
                                    Label(category.title, systemImage: category.symbol)
                                }
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Label("删除卡片", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .alert("重命名卡片", isPresented: $showRename) {
                TextField("卡片名称", text: $newName)
                Button("保存") { store.rename(newName, for: cardID) }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("删除这张卡片？", isPresented: $showDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    store.delete(id: cardID)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("卡片信息仅保存在本机，删除后无法恢复。")
            }
            .onAppear { noteDraft = card?.note ?? "" }
        }
    }

    private func content(_ card: NFCCard) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                hero(card)
                compatibilityCard(card)
                infoCard(card)
                noteCard(card)
                if !card.fields.isEmpty {
                    fieldsCard(card)
                }
                if !card.payloadHex.isEmpty {
                    hexCard(card)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
    }

    private func hero(_ card: NFCCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: card.category.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(card.category.tint)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
                Text(card.category.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(card.category.tint.opacity(0.16), in: Capsule())
                    .foregroundStyle(card.category.tint)
            }

            Text(card.name.isEmpty ? "未命名卡片" : card.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(card.uidDisplay)
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.6))
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [card.category.tint.opacity(0.30), .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func compatibilityCard(_ card: NFCCard) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: card.compatibility.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(card.compatibility.tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(card.compatibility.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(card.compatibility.tint)
                Text(card.compatibility.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                if card.compatibility != .full {
                    Text("提醒：iPhone 只能读取，不能模拟实体卡去开门。")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(card.compatibility.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(card.compatibility.tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func infoCard(_ card: NFCCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                Text("标签信息")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                KeyValueRow(title: "技术", value: card.cardType.title)
                KeyValueRow(title: "UID", value: card.uidDisplay, monospaced: true)
                if let capacity = card.capacity {
                    KeyValueRow(title: "容量", value: "\(capacity) 字节")
                }
                KeyValueRow(title: "首次", value: card.firstSeenAt.formatted(date: .numeric, time: .shortened))
                KeyValueRow(title: "最近", value: card.lastSeenAt.formatted(date: .numeric, time: .shortened))
                KeyValueRow(title: "次数", value: "\(card.scanCount) 次")

                ForEach(Array(card.details.enumerated()), id: \.offset) { _, line in
                    KeyValueRow(title: "附加", value: line, monospaced: true)
                }
            }
        }
    }

    private func noteCard(_ card: NFCCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("备注")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                TextField("例如：小区北门、电动车充电卡", text: $noteDraft, axis: .vertical)
                    .lineLimit(2...4)
                    .foregroundStyle(.white)
                if noteDraft != card.note {
                    Button {
                        store.setNote(noteDraft, for: card.id)
                        Haptics.success()
                    } label: {
                        Text("保存备注")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fieldsCard(_ card: NFCCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("NDEF 记录（\(card.fields.count)）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                ForEach(card.fields) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(field.typeName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                            Button {
                                copy(field.payloadHex)
                            } label: {
                                Label(didCopy ? "已复制" : "复制", systemImage: "doc.on.doc")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(field.value)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(field.payloadHex)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.35))
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func hexCard(_ card: NFCCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("原始 Hex")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Button {
                        copy(card.payloadHex)
                    } label: {
                        Label(didCopy ? "已复制" : "复制", systemImage: "doc.on.doc")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Text(card.payloadHex)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func copy(_ value: String) {
        UIPasteboard.general.string = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }
}
