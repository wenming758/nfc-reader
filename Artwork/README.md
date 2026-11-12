# 图标制作说明

## 文件

| 文件 | 说明 |
| --- | --- |
| `AppIcon-1024-raw.png` | ImageGen 原始输出，1024×1024，右下角带「AI生成」水印 |
| `AppIcon-1024-master.png` | 去水印后的母版，App Icon 的唯一切图来源 |
| `clean_icon.py` | 自动检测并清理水印，始终从 raw 还原后处理，可重复执行 |
| `make_app_icons.py` | 生成 9 个 iOS 尺寸到 Assets.xcassets |

## 生成提示词

```
iOS app icon artwork, exactly square full-bleed 1:1, flat modern vector style with subtle depth.
Background: deep midnight navy to dark teal diagonal gradient with a soft cyan radial glow in the center.
Foreground: a single centered abstract white NFC symbol made of three smooth concentric arcs radiating
to the right, emerging from a minimal rounded rectangular card silhouette with a small chip; crisp clean
geometry, soft outer glow, high contrast, premium Apple App Store aesthetic.
No text, no letters, no numbers, no border, no rounded corners, no drop shadow outside the canvas,
edge-to-edge artwork.
```

## 处理流程

1. 生成 1024×1024 母图 → `AppIcon-1024-raw.png`
2. 运行 `clean_icon.py`：在右下角搜索高亮低饱和像素，定位水印包围盒；逐行取左侧背景色填补，再做 4px 高斯模糊与羽化，输出 `AppIcon-1024-master.png`
3. 运行 `make_app_icons.py`：Pillow LANCZOS 缩放，统一转 RGB（App Store 图标不允许 Alpha）
4. 尺寸清单：
   - 20pt @2x/@3x → 40 / 60
   - 29pt @2x/@3x → 58 / 87
   - 40pt @2x/@3x → 80 / 120
   - 60pt @2x/@3x → 120 / 180
   - App Store → 1024

## 重新生成

```bash
cd Artwork
python clean_icon.py
python make_app_icons.py
```

依赖：Python 3.10+、Pillow。
