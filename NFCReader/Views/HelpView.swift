import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    section(
                        title: "常见卡片对照",
                        rows: [
                            HelpRow(
                                icon: "checkmark.seal.fill",
                                tint: Theme.accent,
                                title: "NTAG / Ultralight",
                                detail: "UID 与 NDEF 全部可读，常见于贴纸标签、部分门禁卡。"
                            ),
                            HelpRow(
                                icon: "exclamationmark.circle.fill",
                                tint: Theme.warn,
                                title: "Mifare Classic（M1）",
                                detail: "小区门禁、电动车卡最常见。iPhone 拿不到加密扇区，多数表现为扫描超时。"
                            ),
                            HelpRow(
                                icon: "exclamationmark.circle.fill",
                                tint: Theme.warn,
                                title: "CPU 卡（ISO 7816）",
                                detail: "可读取 UID；应用数据需要物业指定的 AID，本应用未开启。"
                            ),
                            HelpRow(
                                icon: "checkmark.seal.fill",
                                tint: Theme.accent,
                                title: "ISO 15693",
                                detail: "可读取 UID 与 NDEF，常见于部分门禁、仓储标签。"
                            ),
                            HelpRow(
                                icon: "xmark.octagon.fill",
                                tint: Theme.danger,
                                title: "125kHz ID 卡",
                                detail: "iPhone 的 NFC 线圈不支持这个频率，完全无法读取。"
                            ),
                            HelpRow(
                                icon: "exclamationmark.circle.fill",
                                tint: Theme.warn,
                                title: "FeliCa",
                                detail: "可读取 IDm，门禁应用数据不对外开放。"
                            )
                        ]
                    )
                    section(
                        title: "为什么贴上去没反应？",
                        rows: [
                            HelpRow(icon: "iphone.radiowaves.left.and.right", tint: Theme.accent, title: "贴卡位置", detail: "NFC 天线在 iPhone 顶部、摄像头旁边，卡片要贴住这里。"),
                            HelpRow(icon: "case.fill", tint: Theme.accent, title: "手机壳", detail: "金属壳、磁吸卡包、带卡槽的壳都会屏蔽信号，先取下再试。"),
                            HelpRow(icon: "hourglass", tint: Theme.warn, title: "两次扫描间隔", detail: "系统 NFC 需要冷却，失败后等 2 秒再点扫描。"),
                            HelpRow(icon: "slider.horizontal.3", tint: Theme.accent, title: "扫描模式", detail: "门禁卡请用「标签模式」，NDEF 模式识别不到纯门禁卡。")
                        ]
                    )
                    section(
                        title: "能用手机开门吗？",
                        rows: [
                            HelpRow(
                                icon: "nosign",
                                tint: Theme.danger,
                                title: "iPhone 不能模拟门禁卡",
                                detail: "Core NFC 只提供读取能力，Apple 未开放卡模拟。任何 App 都无法把实体卡复制成手机里的门禁卡。"
                            ),
                            HelpRow(
                                icon: "building.2",
                                tint: Theme.accent,
                                title: "小区门禁",
                                detail: "询问物业是否支持官方 App、二维码或手机 NFC 录入；本应用可帮你存档卡号，方便报备与补卡。"
                            ),
                            HelpRow(
                                icon: "house",
                                tint: Theme.accent,
                                title: "家门",
                                detail: "更换支持 HomeKit / Matter 的智能锁，或使用门锁厂商 App 发放手机钥匙。"
                            ),
                            HelpRow(
                                icon: "bolt.car",
                                tint: Theme.accent,
                                title: "电动车",
                                detail: "使用车辆原厂 App 或蓝牙钥匙；实体刷卡卡无法写入 iPhone。"
                            )
                        ]
                    )
                    security
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("读取说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var intro: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("先看清楚，再动手", systemImage: "eye.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("本应用用 iPhone 自带的 NFC 读取卡片，能读到什么取决于卡片本身。把小区门禁、电动车、家门等卡片分别扫一次，卡包里会清楚标出每张卡的读取能力。")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var security: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 9) {
                Label("数据只在本机", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("卡片 UID、NDEF 内容与备注全部写入本机 Keychain，锁屏后不可读；应用不联网、不上传任何数据。卸载应用会一并清除。")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section(title: String, rows: [HelpRow]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: row.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(row.tint)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private struct HelpRow: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let detail: String
}
