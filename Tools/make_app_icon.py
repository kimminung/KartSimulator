#!/usr/bin/env python3
"""앱 아이콘 생성(결정 61, Issue #46 테크 자리표시자 — 디자인이 정식 아이콘을 내면 교체).

픽셀 룩 그대로: 디자인 `icons.mjs`의 16×16 탑뷰 카트 마스크(결정 40)를 앞층에, 트랙 링(노면 + 시안·마젠타 연석)을 가운데층에,
`ui-well` 바탕 + 격자를 뒤층에 둔다. visionOS는 3층 `solidimagestack`, iOS는 1024 단일 `appiconset`(세 층을 합성).

사용법: python3 Tools/make_app_icon.py   (PIL 필요)
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CATALOG = os.path.join(ROOT, "KartSimulator", "Assets.xcassets")
SIZE = 1024
PX = 16  # 1 픽셀 = 16 pt (64 격자)

PAL = {"well": "#0D1729", "night": "#000918", "rim": "#223A60", "cyan": "#00F6F9", "magenta": "#FF5CD6",
       "road": "#15151A", "road_alt": "#08090E", "kart": "#EE4949", "cream": "#F1F2EE", "dark": "#252934", "gold": "#FEDA34"}

KART = [  # Design/tools/icons.mjs KART (16×16, 앞이 위)
    "......RRRR......", ".....RRCCRR.....", ".DD.RRRCCRRR.DD.", ".DD.RRRCCRRR.DD.", ".DD.RRRCCRRR.DD.", "....RRRRRRRR....", "....RRDDDDRR....", "....RRDDDDRR....",
    "....RRDDDDRR....", "....RRRRRRRR....", ".DD.RRRRRRRR.DD.", ".DD.RRRRRRRR.DD.", ".DD.RRRRRRRR.DD.", "....RRRRRRRR....", "...CCCCCCCCCC...", "................",
]
KART_COL = {"R": PAL["kart"], "C": PAL["cream"], "D": PAL["dark"]}


def rect(draw, x, y, w, h, color):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def back_layer():
    img = Image.new("RGBA", (SIZE, SIZE), PAL["well"])
    d = ImageDraw.Draw(img)
    # 은은한 격자(ui-rim 20 %)
    grid = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for i in range(0, SIZE, PX * 4):
        gd.line([(i, 0), (i, SIZE)], fill=PAL["rim"] + "55", width=2)
        gd.line([(0, i), (SIZE, i)], fill=PAL["rim"] + "55", width=2)
    img.alpha_composite(grid)
    # 아래쪽 어두운 띠(지평선 느낌)
    rect(d, 0, SIZE - PX * 10, SIZE, PX * 10, PAL["night"])
    return img


def middle_layer():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 트랙 링: 둥근 사각 노면(폭 8px)과 안쪽·바깥 연석(시안/마젠타 교대 2px)
    outer = (PX * 8, PX * 14, SIZE - PX * 8, SIZE - PX * 10)
    road_w = PX * 9
    d.rounded_rectangle(outer, radius=PX * 14, fill=PAL["road"])
    inner = (outer[0] + road_w, outer[1] + road_w, outer[2] - road_w, outer[3] - road_w)
    d.rounded_rectangle(inner, radius=PX * 7, fill=(0, 0, 0, 0))
    # 연석: 바깥 테두리 따라 교대 블록 — 간단히 사각 링 둘레를 돌며 칸을 찍는다
    def curbs(box, step, colors, thickness):
        x0, y0, x1, y1 = box
        k = 0
        for x in range(x0, x1, step):
            rect(d, x, y0, step, thickness, colors[k % 2]); rect(d, x, y1 - thickness, step, thickness, colors[k % 2]); k += 1
        for y in range(y0, y1, step):
            rect(d, x0, y, thickness, step, colors[k % 2]); rect(d, x1 - thickness, y, thickness, step, colors[k % 2]); k += 1
    curbs((outer[0] + PX * 2, outer[1] + PX * 2, outer[2] - PX * 2, outer[3] - PX * 2), PX * 3, (PAL["cyan"], PAL["magenta"]), PX)
    # 출발선 체커(아래 변 중앙)
    sx = SIZE // 2 - PX * 4
    for i in range(8):
        for j in range(2):
            rect(d, sx + i * PX, outer[3] - road_w + PX * 2 + j * PX, PX, PX, PAL["cream"] if (i + j) % 2 == 0 else PAL["road_alt"])
    return img


def front_layer():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    scale = PX * 2  # 16×16 → 512 px
    ox, oy = (SIZE - 16 * scale) // 2, (SIZE - 16 * scale) // 2 - PX * 2
    # 그림자
    for y, row in enumerate(KART):
        for x, ch in enumerate(row):
            if ch in KART_COL:
                rect(d, ox + x * scale + PX, oy + y * scale + PX * 2, scale, scale, PAL["night"] + "AA")
    for y, row in enumerate(KART):
        for x, ch in enumerate(row):
            if ch in KART_COL:
                rect(d, ox + x * scale, oy + y * scale, scale, scale, KART_COL[ch])
    # 핀치 점(ui-cyan) 두 개 — "핀치로 조종" 상징
    rect(d, ox - PX * 5, oy + 7 * scale, PX * 3, PX * 3, PAL["cyan"])
    rect(d, ox + 16 * scale + PX * 2, oy + 7 * scale, PX * 3, PX * 3, PAL["cyan"])
    return img


def write_imageset(folder, name, image):
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, name))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name, "idiom": "vision", "scale": "2x"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)


def main():
    back, middle, front = back_layer(), middle_layer(), front_layer()
    # visionOS 3층
    stack = os.path.join(CATALOG, "AppIcon.solidimagestack")
    os.makedirs(stack, exist_ok=True)
    layers = [("Front", front), ("Middle", middle), ("Back", back)]
    with open(os.path.join(stack, "Contents.json"), "w") as f:
        json.dump({"layers": [{"filename": f"{n}.solidimagestacklayer"} for n, _ in layers], "info": {"author": "xcode", "version": 1}}, f, indent=2)
    for n, img in layers:
        layer_dir = os.path.join(stack, f"{n}.solidimagestacklayer")
        os.makedirs(layer_dir, exist_ok=True)
        with open(os.path.join(layer_dir, "Contents.json"), "w") as f:
            json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        write_imageset(os.path.join(layer_dir, "Content.imageset"), f"{n.lower()}.png", img)
    # iOS 단일 1024(세 층 합성)
    flat = back.copy()
    flat.alpha_composite(middle)
    flat.alpha_composite(front)
    flat = flat.convert("RGB")
    appicon = os.path.join(CATALOG, "AppIcon.appiconset")
    os.makedirs(appicon, exist_ok=True)
    flat.save(os.path.join(appicon, "icon_1024.png"))
    with open(os.path.join(appicon, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": "icon_1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)
    preview = flat.resize((256, 256), Image.NEAREST)
    os.makedirs(os.path.join(ROOT, "Docs", "review"), exist_ok=True)
    preview.save(os.path.join(ROOT, "Docs", "review", "app-icon-preview.png"))
    print("wrote", stack, appicon)


if __name__ == "__main__":
    main()
