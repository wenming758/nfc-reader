import SwiftUI
import UIKit

struct VaultView: View {
    @EnvironmentObject private var store: CardStore
    @Binding var selectedTab: Int

    @State private var selectedCard: NFCCard?
    @State private var showHelp = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statsHeader

                    if store.cards.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(store.cards) { card in
                                Button {
                                    selectedCard = card
                                } label: {
                                    cardTile(card)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.delete(id: card.id)
                                        Haptics.success()
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if let error = store.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.warn)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("我的卡包")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(item: $selectedCard) { card in
                CardDetailView(cardID: card.id)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 10) {
            statPill(value: "\(store.cards.count)", label: "张卡片", tint: Theme.accent)
            statPill(
                value: "\(store.cards.filter { $0.compatibility == .full }.count)",
                label: "可完整读取",
                tint: Color(red: 0.5, green: 0.85, blue: 1.0)
            )
            statPill(
                value: "\(store.cards.filter { $0.compatibility == .uidOnly }.count)",
                label: "仅 UID",
                tint: Theme.warn
            )
        }
    }

    private func statPill(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent.opacity(0.9))
            Text("还没有保存的卡片")
                .font(.headline)
                .foregroundStyle(.white)
            Text("扫描小区门禁、电动车、家门等卡片，\n给它们起个名字，集中管理在这一页。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button {
                selectedTab = 1
            } label: {
                Label("去扫描", systemImage: "wave.3.right")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Theme.buttonGradient, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func cardTile(_ card: NFCCard) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: card.category.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(card.category.tint)
                    .frame(width: 32, height: 32)
                    .background(
                        card.category.tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                Spacer(minLength: 4)
                Text(card.compatibility.title)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(card.compatibility.tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(card.compatibility.tint)
            }

            Text(card.name.isEmpty ? "未命名卡片" : card.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(card.uidDisplay)
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack {
                Text(card.category.title)
                    .font(.caption2)
                    .foregroundStyle(card.category.tint.opacity(0.9))
                Spacer(minLength: 4)
                Text(card.lastSeenAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [card.category.tint.opacity(0.18), .white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
