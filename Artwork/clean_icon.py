#!/usr/bin/env python3
"""清理图标母版右下角的生成水印，并保留原始母版备份。

处理后覆盖 Artwork/AppIcon-1024-master.png，原始文件保存在
Artwork/AppIcon-1024-raw.png。随后重新运行 make_app_icons.py 切图。
"""

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BASE = Path(__file__).resolve().parent
MASTER = BASE / "AppIcon-1024-master.png"
RAW = BASE / "AppIcon-1024-raw.png"


def find_watermark(image: Image.Image) -> tuple[int, int, int, int] | None:
    width, height = image.size
    pixels = image.load()
    xs: list[int] = []
    ys: list[int] = []

    # 只在右下角搜索：该区域是纯深色背景，弧线不会进入。
    for y in range(int(height * 0.88), height):
        for x in range(int(width * 0.82), width):
            r, g, b = pixels[x, y]
            if min(r, g, b) > 90 and max(r, g, b) - min(r, g, b) < 45:
                xs.append(x)
                ys.append(y)

    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def main() -> None:
    if not RAW.exists():
        if not MASTER.exists():
            raise SystemExit(f"缺少母版：{MASTER}")
        shutil.copyfile(MASTER, RAW)
    shutil.copyfile(RAW, MASTER)

    image = Image.open(MASTER).convert("RGB")
    box = find_watermark(image)
    if box is None:
        print("未检测到水印，跳过。")
        return

    x0, y0, x1, y1 = box
    pixels = image.load()
    x0 = max(0, x0 - 6)
    y0 = max(0, y0 - 6)
    x1 = min(image.width - 1, x1 + 6)
    y1 = min(image.height - 1, y1 + 6)

    # 逐行取左侧同高度的背景色填充，保留垂直方向的渐变。
    for y in range(y0, y1 + 1):
        samples = [pixels[x, y] for x in range(max(0, x0 - 60), max(1, x0 - 25))]
        average = tuple(sum(color[i] for color in samples) // len(samples) for i in range(3))
        for x in range(x0, x1 + 1):
            pixels[x, y] = average

    # 轻微模糊 + 羽化，消除修补区域边缘。
    region = (max(0, x0 - 14), max(0, y0 - 14), min(image.width, x1 + 15), min(image.height, y1 + 15))
    patch = image.crop(region).filter(ImageFilter.GaussianBlur(4))
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rectangle(
        (14, 14, 14 + (x1 - x0) + 1, 14 + (y1 - y0) + 1),
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(5))
    image.paste(patch, region[:2], mask)
    image.save(MASTER, "PNG", optimize=True)

    print(f"已清理水印区域：{box}，输出 {MASTER}")


if __name__ == "__main__":
    main()
