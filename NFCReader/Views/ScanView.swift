import SwiftUI
import UIKit

struct ScanView: View {
    @EnvironmentObject private var nfc: NFCManager
    @EnvironmentObject private var store: CardStore
    @AppStorage("lastCategory") private var lastCategoryRaw = CardCategory.access.rawValue

    @State private var pulse = false
    @State private var draftName = ""
    @State private var draftCategory: CardCategory = .access
    @State private var didSave = false
    @State private var saveMessage: String?
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    if !nfc.isSupported {
                        unsupportedBanner
                    }

                    modePicker
                    scanPad

                    if case .failure = nfc.state {
                        helpBanner
                    }

                    if let draft = nfc.draft {
                        draftCard(draft)
                    }

                    tipsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("扫描卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
            .onAppear { pulse = true }
            .onChange(of: nfc.draft) { _, newValue in
                resetDraftForm(for: newValue)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(subline)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var headline: String {
        switch nfc.state {
        case .idle: return "准备就绪"
        case .scanning: return "正在寻找卡片…"
        case .success: return "读取完成"
        case .failure: return "这张卡没有读出来"
        }
    }

    private var subline: String {
        switch nfc.state {
        case .idle:
            return nfc.mode.caption
        case .scanning:
            return "把卡片贴近 iPhone 顶部，保持 1–2 秒"
        case .success(let message):
            return message
        case .failure(let message):
            return message
        }
    }

    private var unsupportedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warn)
            Text("当前设备不支持 NFC（模拟器或较早机型）。请使用 iPhone 7 及更新机型在真机上运行。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.warn.opacity(0.3), lineWidth: 1)
        )
    }

    private var helpBanner: some View {
        Button { showHelp = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                Text("看看哪些卡片 iPhone 能读、哪些不能")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(Theme.accent)
            .padding(13)
            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 模式与扫描按钮

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(NFCScanMode.allCases) { mode in
                Button {
                    nfc.select(mode: mode)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 3) {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                        Text(mode.caption)
                            .font(.caption2)
                            .opacity(0.7)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(nfc.mode == mode ? Theme.accent.opacity(0.18) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                nfc.mode == mode ? Theme.accent.opacity(0.6) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(nfc.mode == mode ? Theme.accent : Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .disabled(nfc.state.isScanning)
            }
        }
    }

    private var scanPad: some View {
        VStack(spacing: 14) {
            Button(action: toggleScan) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Theme.accent.opacity(nfc.state.isScanning ? 0.5 : 0), lineWidth: 1.5)
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulse && nfc.state.isScanning ? 1.6 : 0.9)
                            .opacity(pulse && nfc.state.isScanning ? 0 : 0.7)
                            .animation(
                                .easeOut(duration: 2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.5),
                                value: pulse
                            )
                    }

                    Circle()
                        .fill(Theme.buttonGradient)
                        .frame(width: 128, height: 128)
                        .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: Theme.accent.opacity(0.4), radius: 24, y: 12)

                    VStack(spacing: 6) {
                        Image(systemName: nfc.state.isScanning ? "xmark" : "wave.3.right")
                            .font(.system(size: 34, weight: .semibold))
                        Text(nfc.state.isScanning ? "取消" : "开始扫描")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Theme.ink)
                }
                .frame(height: 196)
            }
            .buttonStyle(.plain)
            .disabled(!nfc.isSupported)
            .opacity(nfc.isSupported ? 1 : 0.45)
            .accessibilityLabel(nfc.state.isScanning ? "取消扫描" : "开始扫描 NFC 卡片")

            Text(nfc.state.isScanning ? "轻点取消" : "轻点开始，再把卡片贴近手机顶部")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func toggleScan() {
        if nfc.state.isScanning {
            nfc.cancel()
        } else {
            nfc.start()
        }
    }

    // MARK: - 扫描结果

    private func draftCard(_ card: NFCCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Image(systemName: card.compatibility.symbol)
                        .foregroundStyle(card.compatibility.tint)
                    Text(card.compatibility == .unsupported ? "读到了卡片，但数据受限" : "发现卡片")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 6)
                    Text(card.cardType.title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("UID")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(card.uidDisplay)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text("\(card.compatibility.title)：\(card.compatibility.detail)")
                        .font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(card.compatibility.tint)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    card.compatibility.tint.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if !card.fields.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(card.fields.prefix(3)) { field in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.typeName)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(field.value)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }
                        if card.fields.count > 3 {
                            Text("还有 \(card.fields.count - 3) 条记录，保存后可在详情中查看")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }

                if !card.note.isEmpty, card.compatibility != .full {
                    Text(card.note)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if card.compatibility != .unsupported {
                    Divider().overlay(Color.white.opacity(0.08))
                    if didSave {
                        savedPanel
                    } else {
                        saveForm
                    }
                } else {
                    Button { nfc.start() } label: {
                        Label("换一张卡再试", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("存到卡包")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))

            TextField("给这张卡起个名字", text: $draftName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)

            HStack(spacing: 7) {
                ForEach(CardCategory.allCases) { category in
                    Button {
                        selectCategory(category)
                    } label: {
                        Text(category.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                draftCategory == category
                                    ? category.tint.opacity(0.20)
                                    : Color.white.opacity(0.05),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    draftCategory == category ? category.tint.opacity(0.55) : .clear,
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(draftCategory == category ? category.tint : Color.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button { saveDraft() } label: {
                    Label("保存到卡包", systemImage: "tray.and.arrow.down.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.buttonGradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)

                Button { nfc.start() } label: {
                    Label("下一张", systemImage: "wave.3.right")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var savedPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(saveMessage ?? "已保存到卡包")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)

            Button { nfc.start() } label: {
                Label("继续扫描下一张", systemImage: "wave.3.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
    }

    private var tipsCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("读卡小贴士", systemImage: "lightbulb.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warn)
                Text("• 贴卡位置在 iPhone 顶部，摄像头旁边\n• 金属壳、磁吸卡包会屏蔽信号，建议先取下\n• 加密 M1 卡和 125kHz ID 卡无法被 iPhone 读取\n• 同一张卡再次扫描会更新记录，不会重复添加")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 动作

    private func resetDraftForm(for card: NFCCard?) {
        guard card != nil else {
            draftName = ""
            didSave = false
            saveMessage = nil
            return
        }
        let category = CardCategory(rawValue: lastCategoryRaw) ?? .access
        draftCategory = category
        draftName = store.defaultName(for: category)
        didSave = false
        saveMessage = nil
    }

    private func selectCategory(_ category: CardCategory) {
        let previousDefault = store.defaultName(for: draftCategory)
        if draftName.isEmpty || draftName == previousDefault {
            draftName = store.defaultName(for: category)
        }
        draftCategory = category
        lastCategoryRaw = category.rawValue
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveDraft() {
        guard var card = nfc.draft else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        card.name = trimmed.isEmpty ? store.defaultName(for: draftCategory) : trimmed
        card.category = draftCategory

        let isNew = store.upsert(card)
        lastCategoryRaw = draftCategory.rawValue
        didSave = true
        saveMessage = isNew ? "已保存到卡包" : "这张卡已在卡包中，已更新读取记录"
        Haptics.success()
    }
}
