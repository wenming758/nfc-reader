# NFC 卡包 · iOS 原生应用

用 iPhone 读取小区门禁、电动车、家门等实体卡，按用途命名、分类并保存在本机卡包里。每张卡都会明确标注 **可完整读取 / 仅能读取 UID / 无法读取**，并解释原因。

> 重要前提：`Core NFC` 只提供**读取**能力，Apple 不允许 App 模拟门禁卡。因此本应用解决的是「读卡、辨卡、归档」，而不是「把实体卡复制进手机去开门」。125kHz ID 卡 iPhone 完全不支持；加密 M1 卡（多数小区门禁、电动车卡）只能拿到卡的存在性，读不到扇区数据。

---

## 一、你手上这三张卡怎么用

| 步骤 | 操作 |
| --- | --- |
| 1 | 在 iPhone（iPhone 7 及更新机型）上运行 App，点击「扫描」 |
| 2 | 保持「标签模式」，手机顶部贴近卡片 1–2 秒 |
| 3 | 读取成功后，把名字改成「小区门禁 / 电动车 / 家门」，选择对应分类，点「保存到卡包」 |
| 4 | 点「继续扫描下一张」，依次扫完三张 |
| 5 | 读不出的卡，打开右上角「?」对照卡型判断原因 |

三张卡可能的读取结果：

- **小区门禁卡**：多为 Mifare Classic（M1）或 CPU 卡。CPU 卡能读 UID；M1 卡通常直接超时（iPhone 不开放加密扇区）。若是 NTAG/Ultralight 卡，则可以完整读取。
- **电动车卡**：常见 125kHz ID 卡或 M1 卡，两者大概率都读不到；少数 NFC 钥匙卡能读到 UID。
- **家门卡**：若为智能锁配套卡，通常是 M1/CPU 卡，只能读到 UID；真正用手机开门需要门锁支持 HomeKit / Matter 或厂商 App 发手机钥匙。

卡包会把这些差异直接标在每张卡上，避免误以为「已经复制成功」。

---

## 二、功能

- 两种扫描模式：`标签模式`（读 UID + 技术类型，门禁卡首选）、`NDEF 模式`（只读 NDEF，兼容性兜底）。
- 自动识别卡片技术类型：Mifare Ultralight / Plus / DESFire、ISO 7816 CPU 卡、ISO 15693、FeliCa、NDEF。
- NDEF 解析：文本（T）、链接（U）、MIME、外部类型、原始 Hex。
- 卡包管理：命名、分类（小区门禁 / 电动车 / 家门 / 其他）、备注、重命名、删除。
- 同一张卡（相同 UID + 相同卡型）再次扫描只更新读取时间与内容，不重复添加。
- 每张卡带能力徽章与说明，详情页可查看 UID、容量、附加信息、NDEF 记录、原始 Hex，并支持复制。
- 全部数据写入本机 Keychain（`WhenUnlockedThisDeviceOnly`），不联网、不上传；卸载即清除。
- 扫描成功/失败触觉反馈；退到后台自动结束 NFC 会话；深色玻璃质感界面。

---

## 三、目录结构

```
nfc/
├─ NFCReader.xcodeproj/                 Xcode 工程（含共享 Scheme）
│  ├─ project.pbxproj
│  └─ xcshareddata/xcschemes/NFCReader.xcscheme
├─ NFCReader/
│  ├─ NFCReaderApp.swift                App 入口 + TabView
│  ├─ Info.plist                        NFC 权限文案、启动屏、方向、深色模式
│  ├─ NFCReader.entitlements            NFC 能力：NDEF + TAG
│  ├─ Models/
│  │  └─ NFCCard.swift                  卡片、分类、兼容性、NDEF 字段、Hex 扩展
│  ├─ Managers/
│  │  ├─ NFCManager.swift               Core NFC 会话、UID、NDEF 解析、错误映射
│  │  ├─ CardStore.swift                卡包增删改、去重、持久化
│  │  └─ KeychainStore.swift            Keychain 最小封装
│  ├─ Views/
│  │  ├─ Theme.swift                    配色、玻璃卡片、通用行
│  │  ├─ ContentView.swift              卡包 / 扫描两个 Tab
│  │  ├─ VaultView.swift                卡包网格与统计
│  │  ├─ ScanView.swift                 扫描、命名、分类、保存、连续扫描
│  │  ├─ CardDetailView.swift           详情、重命名、分类、备注、Hex
│  │  └─ HelpView.swift                 卡型对照与限制说明
│  └─ Assets.xcassets/
│     ├─ AppIcon.appiconset/            9 个尺寸图标（20/29/40/60 + 1024）
│     └─ AccentColor.colorset/
├─ Artwork/
│  ├─ AppIcon-1024-raw.png              生成原始图（右下角带生成水印）
│  ├─ AppIcon-1024-master.png           清理水印后的母版
│  ├─ clean_icon.py                     水印清理脚本
│  ├─ make_app_icons.py                 母版切图脚本
│  └─ README.md                         图标制作说明
└─ README.md                            本文件
```

---

## 四、在 Xcode 中打开与运行

1. 把整个 `nfc` 文件夹拷贝到 Mac。
2. 双击 `NFCReader.xcodeproj`（Xcode 14 及以上可直接打开，推荐 Xcode 16+）。
3. 选中 `NFCReader` Target → **Signing & Capabilities**：
   - 选择自己的 Team；
   - 如 Bundle Identifier `com.diy.nfcreader` 冲突，改成自己的唯一域名；
   - 确认存在 **Near Field Communication Tag Reading** 能力（工程已带 entitlements：`NDEF`、`TAG`）。
4. 连接 iPhone 真机运行（模拟器没有 NFC，会显示「当前设备不支持 NFC」）。
5. 首次贴卡时，系统会按 `NFCReaderUsageDescription` 弹出授权说明。

> NFC 能力需要已加入 Apple Developer Program 的账号。若签名提示 entitlement 不受支持，请检查 App ID 是否勾选 NFC Tag Reading，以及使用的证书类型。
>
> 需要 `.ipa` 文件？见「十、生成 IPA」。

### 版本与兼容性

- 部署目标：**iOS 17.0**，Swift 5，UIKit + SwiftUI。
- 你指定的 **iOS 27.2.1** 目前不是公开版本。工程按「未来系统」处理：使用当前最新 SDK 构建，只依赖 Core NFC 长期稳定的 API（`NFCTagReaderSession`、`NFCNDEFReaderSession`、`NFCNDEFTag`）。所有 NFC 相关代码集中在 `NFCManager.swift`，若未来系统调整 API，只需改这一处。
- 代码对设备能力做了运行时检查：`NFCTagReaderSession.readingAvailable`，不支持时界面给出明确提示，不会崩溃。

---

## 五、卡片兼容性说明

| 卡片类型 | 典型场景 | iPhone 能读到 | 能否用手机开门 |
| --- | --- | --- | --- |
| NTAG / Ultralight | 贴纸、部分门禁 | UID + NDEF | 否（只读） |
| Mifare Classic（M1） | 小区门禁、电动车最常见 | 通常扫描超时，读不到扇区 | 否 |
| Mifare Plus / DESFire | 高端门禁、校园卡 | UID（可能含 NDEF） | 否 |
| CPU 卡（ISO 7816） | 门禁、充电卡 | UID；应用数据需 AID 白名单 | 否 |
| ISO 15693 | 部分门禁、仓储标签 | UID + NDEF | 否 |
| FeliCa | 部分门锁、交通 | IDm | 否 |
| 125kHz ID 卡 | 老小区、电动车 | 完全不支持（频率不同） | 否 |

“用手机开门”的现实路径：门禁侧支持官方 App / 二维码 / 手机录入，或家门换成支持 HomeKit / Matter 的智能锁。本应用的 UID 归档可用于报备、补卡、区分卡片。

---

## 六、技术实现要点

1. **会话层**：`NFCTagReaderSession` 同时轮询 `.iso14443`、`.iso15693`、`.iso18092`，同时覆盖 M1/CPU 卡、NFC-V 标签和 FeliCa；`NFCNDEFReaderSession` 作为只读兜底。
2. **UID 读取**：按 `NFCTag` 枚举分支取 `identifier` / `currentIDm`，并记录 MiFare 家族、ISO15693 厂商码与序列号、ISO7816 Historical Bytes / AID 等附加信息。
3. **NDEF 读取**：`queryNDEFStatus` 与 `readNDEF` 用 `withCheckedThrowingContinuation` 包成 async，逐张卡容错——NDEF 失败不影响 UID 结果。
4. **NDEF 解析**：按 `typeNameFormat` 解析文本记录（状态字节区分 UTF-8/UTF-16 与语言码长度）与 URI 记录（首字节前缀表），其余保留原始 Hex。
5. **线程与状态**：所有 `@Published` 状态统一经主线程发布；失效码 1/5 视为用户取消，2/6 视为超时并给出「M1 / ID 卡」提示，3/7 提示系统 NFC 忙。
6. **生命周期**：监听 `didEnterBackgroundNotification`，退后台立即 `invalidate()`，避免会话悬挂；Core NFC 本身不支持后台读卡。
7. **存储**：`CardStore` 将 `[NFCCard]` 编码为 JSON 写入 Keychain（`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`），相同 UID + 卡型做 upsert 去重，上限 200 张。
8. **可访问性/反馈**：扫描按钮、卡片徽章均有语义标签；成功/失败使用 `UINotificationFeedbackGenerator`。

---

## 七、图标制作过程

1. 使用 ImageGen 生成 1024×1024 母图，提示词要点：
   > iOS app icon, full-bleed square, deep midnight navy to teal gradient, centered white contactless card with three concentric NFC arcs, soft cyan glow, flat premium vector style, no text, no border, no rounded corners.
2. 原图保存为 `Artwork/AppIcon-1024-raw.png`（右下角有「AI生成」水印）。
3. `Artwork/clean_icon.py` 自动定位右下角水印区域，用同高度背景色逐行填补并做羽化模糊，输出无 Alpha 的 `AppIcon-1024-master.png`。
4. `Artwork/make_app_icons.py` 用 Pillow（LANCZOS）从母版生成 9 个尺寸：40/60、58/87、80/120、120/180、1024，统一 `RGB` 避免 App Store 图标透明通道报错。
5. 输出目录：`NFCReader/Assets.xcassets/AppIcon.appiconset/`，`Contents.json` 已包含 iPhone 全套尺寸与 `ios-marketing`。

需要重新出图时执行：

```bash
cd Artwork
python clean_icon.py
python make_app_icons.py
```

---

## 八、已知限制

- 只读：无法模拟实体卡，无法写入 M1 加密块。
- M1 加密卡与 125kHz ID 卡无法读取，这是 iOS 与硬件层面的限制，不是本应用可绕过的问题。
- `NDEF 模式` 拿不到 UID；对 NDEF 卡重复扫描会新增记录（没有 UID 可用于去重）。
- ISO7816 卡的应用数据需要 `com.apple.developer.nfc.readersession.iso7816.select-identifiers` 白名单，本工程未启用。
- NFC 会话只能在前台进行；锁屏/切后台会结束扫描。
- 金属手机壳、磁吸卡包会显著削弱 NFC 信号。

---

## 九、真机测试清单

- [ ] 模拟器启动：显示「当前设备不支持 NFC」，按钮置灰不崩溃
- [ ] NDEF 贴纸：能读到文本/链接，Hex 可复制
- [ ] M1 门禁卡：约 60 秒内超时，提示 M1/ID 卡限制
- [ ] 125kHz ID 卡：无响应，提示频率不支持
- [ ] CPU 卡：能显示 UID 与「仅能读取 UID」徽章
- [ ] 同一张卡扫两次：卡包不重复，次数 +1
- [ ] 重命名、改分类、备注、删除均持久化
- [ ] 杀进程重开：卡包数据仍在（Keychain）
- [ ] 扫描中切到后台：会话结束，回前台可重新扫描

---

## 十、生成 IPA

当前目录是 Windows 上生成的源码工程，没有编译产物。IPA 必须由 **macOS + Xcode** 编译，并经过 Apple 签名后才能装进 iPhone。

### 方式 A：Mac 本地一键打包

```bash
chmod +x Scripts/build_ipa.sh
./Scripts/build_ipa.sh
```

产物：`build/NFCReader-unsigned.ipa`（未签名）。

- 真机直接使用：用 Xcode 打开工程，选自己的 Team，连接 iPhone 运行。
- 导出已签名 IPA：Xcode → Product → Archive → Distribute App → Development → Export，得到只能安装在已登记设备上的 IPA。

### 方式 B：GitHub Actions 云端生成

1. 把工程推到 GitHub 仓库（`.github/workflows/build-ipa.yml` 已就绪）；
2. 仓库 → Actions → **Build IPA** → Run workflow；
3. 结束后在 Artifacts 下载 `NFCReader-unsigned-ipa`；推送 `v*` 标签时会自动附加到 Release。

云端产物同样是**未签名 IPA**，不能直接安装，需要 Sideloadly / AltStore / 签名服务用你自己的证书重签。

### 签名与 NFC 权限（关键）

- 未签名 IPA 在未越狱 iPhone 上无法直接安装。
- NFC Tag Reading 能力需要 **已付费的 Apple Developer Program 账号**；免费 Apple ID 重签后通常没有该 entitlement，App 能打开但 NFC 不可用。
- 最稳路径：Mac + 付费账号 + Xcode 真机运行，或导出 Development IPA。

## 十一、版本

- 1.0.0 · 2026-11-12
- 最低系统：iOS 17.0
- 构建工具：Xcode 16+ / Swift 5
