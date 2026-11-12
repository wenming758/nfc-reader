#!/usr/bin/env python3
"""从 1024x1024 图标母版生成 iOS AppIcon 全套尺寸。

用法：
    python make_app_icons.py

母版：Artwork/AppIcon-1024-master.png
输出：NFCReader/Assets.xcassets/AppIcon.appiconset/
"""

from pathlib import Path

from PIL import Image

BASE = Path(__file__).resolve().parent
MASTER = BASE / "AppIcon-1024-master.png"
ICONSET = BASE.parent / "NFCReader" / "Assets.xcassets" / "AppIcon.appiconset"

# iOS App Store 图标不允许包含 Alpha 通道，统一转 RGB 保存。
SIZES = {
    "icon-20@2x.png": 40,
    "icon-20@3x.png": 60,
    "icon-29@2x.png": 58,
    "icon-29@3x.png": 87,
    "icon-40@2x.png": 80,
    "icon-40@3x.png": 120,
    "icon-60@2x.png": 120,
    "icon-60@3x.png": 180,
    "icon-1024.png": 1024,
}


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"缺少母版：{MASTER}")

    ICONSET.mkdir(parents=True, exist_ok=True)
    master = Image.open(MASTER).convert("RGB")
    if master.size != (1024, 1024):
        master = master.resize((1024, 1024), Image.LANCZOS)

    for filename, pixels in SIZES.items():
        icon = master.resize((pixels, pixels), Image.LANCZOS)
        icon.save(ICONSET / filename, "PNG", optimize=True)
        print(f"{filename:18s} {pixels}x{pixels}")

    print(f"完成：{ICONSET}")


if __name__ == "__main__":
    main()
