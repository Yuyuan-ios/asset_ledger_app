from __future__ import annotations

import argparse
import html
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "build" / "app_store_raw"
BASE_WIDTH = 1170
BASE_HEIGHT = 2532

PRESETS = {
    "iphone61": {
        "width": 1170,
        "height": 2532,
        "html_dir": ROOT / "build" / "app_store_html",
        "out_dir": ROOT / "build" / "app_store_uploads",
    },
    "iphone65": {
        "width": 1242,
        "height": 2688,
        "html_dir": ROOT / "build" / "app_store_html_65",
        "out_dir": ROOT / "build" / "app_store_uploads_65",
    },
}

POSTERS = [
    {
        "slug": "01-timing",
        "eyebrow": "工程设备经营管理",
        "title": "设备工时，专业记录",
        "subtitle": "按设备查看作业时长、年度收入支出与近期工时明细",
        "image": RAW_DIR / "timing-live.png",
    },
    {
        "slug": "02-fuel",
        "eyebrow": "工程设备经营管理",
        "title": "油耗数据，随时可查",
        "subtitle": "设备燃油效率、年度消耗与加油记录统一管理",
        "image": RAW_DIR / "fuel-live.png",
    },
    {
        "slug": "03-account",
        "eyebrow": "工程设备经营管理",
        "title": "项目回款，全局掌握",
        "subtitle": "从设备贡献到项目实收，经营数据更清楚",
        "image": RAW_DIR / "account-live.png",
    },
]


def px(value: float, scale: float) -> str:
    return f"{round(value * scale, 2)}px"


def build_html_template(width: int, height: int) -> str:
    scale = width / BASE_WIDTH

    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width={width}, initial-scale=1.0" />
  <title>{{title}}</title>
  <style>
    :root {{
      --bg-top: #f7f5f0;
      --bg-bottom: #f4f2ee;
      --text-primary: #1f1f1d;
      --text-secondary: #7c7a76;
      --accent: #eb8a18;
    }}

    * {{
      box-sizing: border-box;
    }}

    html,
    body {{
      margin: 0;
      width: {width}px;
      height: {height}px;
      overflow: hidden;
      background: linear-gradient(180deg, var(--bg-top) 0%, #f6f5f1 38%, var(--bg-bottom) 100%);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
      -webkit-font-smoothing: antialiased;
      text-rendering: optimizeLegibility;
    }}

    body::before {{
      content: "";
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 50% 8%, rgba(235, 138, 24, 0.06), transparent 30%),
        radial-gradient(circle at 50% 78%, rgba(0, 0, 0, 0.03), transparent 35%);
      pointer-events: none;
    }}

    .canvas {{
      position: relative;
      width: {width}px;
      height: {height}px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }}

    .hero {{
      width: {px(900, scale)};
      margin-top: {px(148, scale)};
      text-align: center;
    }}

    .eyebrow {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: {px(12, scale)} {px(22, scale)};
      border-radius: 999px;
      background: rgba(235, 138, 24, 0.08);
      color: #8d5a15;
      font-size: {px(24, scale)};
      font-weight: 650;
      letter-spacing: 0.08em;
    }}

    .title {{
      margin: {px(36, scale)} 0 0;
      color: var(--text-primary);
      font-size: {px(90, scale)};
      line-height: 1.08;
      font-weight: 800;
      letter-spacing: -0.05em;
    }}

    .subtitle {{
      margin: {px(30, scale)} auto 0;
      max-width: {px(860, scale)};
      color: var(--text-secondary);
      font-size: {px(36, scale)};
      line-height: 1.55;
      font-weight: 500;
      letter-spacing: -0.02em;
    }}

    .accent {{
      width: {px(92, scale)};
      height: {px(6, scale)};
      margin: {px(34, scale)} auto 0;
      border-radius: 999px;
      background: linear-gradient(90deg, rgba(235, 138, 24, 0.2), var(--accent), rgba(235, 138, 24, 0.2));
    }}

    .device-wrap {{
      position: relative;
      margin-top: {px(126, scale)};
      width: {px(848, scale)};
      height: {px(1780, scale)};
      display: flex;
      align-items: center;
      justify-content: center;
    }}

    .shell {{
      position: relative;
      width: {px(848, scale)};
      height: {px(1780, scale)};
      border-radius: {px(126, scale)};
      background:
        linear-gradient(145deg, #8a8a8d 0%, #565659 12%, #232325 28%, #89898c 46%, #444447 61%, #141416 100%);
      box-shadow:
        0 {px(28, scale)} {px(72, scale)} rgba(0, 0, 0, 0.09),
        0 {px(92, scale)} {px(132, scale)} rgba(0, 0, 0, 0.12);
    }}

    .shell::before {{
      content: "";
      position: absolute;
      inset: {px(3, scale)};
      border-radius: {px(123, scale)};
      border: 1px solid rgba(255, 255, 255, 0.18);
      pointer-events: none;
    }}

    .phone {{
      position: relative;
      width: {px(830, scale)};
      height: {px(1762, scale)};
      margin: {px(9, scale)};
      border-radius: {px(120, scale)};
      background:
        linear-gradient(165deg, #1a1a1c 0%, #090909 30%, #000000 52%, #141416 100%);
      box-shadow:
        inset 0 0 0 1px rgba(255, 255, 255, 0.07),
        inset 0 -1px 0 rgba(255, 255, 255, 0.05);
    }}

    .phone::before {{
      content: "";
      position: absolute;
      inset: {px(5, scale)};
      border-radius: {px(115, scale)};
      border: 1px solid rgba(255, 255, 255, 0.12);
      pointer-events: none;
    }}

    .phone::after {{
      content: "";
      position: absolute;
      inset: 0;
      border-radius: {px(120, scale)};
      box-shadow:
        inset 0 {px(2, scale)} {px(3, scale)} rgba(255, 255, 255, 0.05),
        inset 0 -{px(2, scale)} {px(4, scale)} rgba(255, 255, 255, 0.02);
      pointer-events: none;
    }}

    .side-button {{
      position: absolute;
      left: -{px(7, scale)};
      width: {px(7, scale)};
      border-radius: {px(7, scale)} 0 0 {px(7, scale)};
      background: linear-gradient(180deg, #4d4d50 0%, #1a1a1c 100%);
    }}

    .side-button.one {{
      top: {px(302, scale)};
      height: {px(94, scale)};
    }}

    .side-button.two {{
      top: {px(436, scale)};
      height: {px(182, scale)};
    }}

    .power-button {{
      position: absolute;
      right: -{px(7, scale)};
      top: {px(406, scale)};
      width: {px(7, scale)};
      height: {px(228, scale)};
      border-radius: 0 {px(7, scale)} {px(7, scale)} 0;
      background: linear-gradient(180deg, #4d4d50 0%, #1a1a1c 100%);
    }}

    .screen {{
      position: absolute;
      left: {px(34, scale)};
      top: {px(34, scale)};
      width: {px(762, scale)};
      height: {px(1668, scale)};
      border-radius: {px(94, scale)};
      overflow: hidden;
      background: #ffffff;
      box-shadow:
        inset 0 0 0 1px rgba(255, 255, 255, 0.08),
        inset 0 0 0 1px rgba(0, 0, 0, 0.05);
    }}

    .screen img {{
      display: block;
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}

    .notch {{
      position: absolute;
      top: 0;
      left: 50%;
      width: {px(286, scale)};
      height: {px(62, scale)};
      transform: translateX(-50%);
      background: #000000;
      border-bottom-left-radius: {px(38, scale)};
      border-bottom-right-radius: {px(38, scale)};
      box-shadow:
        0 1px 0 rgba(255, 255, 255, 0.05),
        0 {px(6, scale)} {px(12, scale)} rgba(0, 0, 0, 0.08);
      z-index: 2;
    }}

    .notch::before,
    .notch::after {{
      content: "";
      position: absolute;
      top: 0;
      width: {px(40, scale)};
      height: {px(22, scale)};
      background: transparent;
    }}

    .notch::before {{
      left: -{px(22, scale)};
      border-top-right-radius: {px(20, scale)};
      box-shadow: {px(12, scale)} -1px 0 #000000;
    }}

    .notch::after {{
      right: -{px(22, scale)};
      border-top-left-radius: {px(20, scale)};
      box-shadow: -{px(12, scale)} -1px 0 #000000;
    }}
  </style>
</head>
<body>
  <div class="canvas">
    <section class="hero">
      <div class="eyebrow">{{eyebrow}}</div>
      <h1 class="title">{{title}}</h1>
      <p class="subtitle">{{subtitle}}</p>
      <div class="accent"></div>
    </section>

    <div class="device-wrap">
      <div class="shell">
        <div class="phone">
          <div class="side-button one"></div>
          <div class="side-button two"></div>
          <div class="power-button"></div>
          <div class="screen">
            <div class="notch"></div>
            <img src="{{image_uri}}" alt="{{title}}" />
          </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
"""


def write_html_files(preset: str) -> tuple[Path, Path, int, int]:
    config = PRESETS[preset]
    width = config["width"]
    height = config["height"]
    html_dir = config["html_dir"]
    out_dir = config["out_dir"]

    html_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    template = build_html_template(width, height)
    for poster in POSTERS:
        html_path = html_dir / f"{poster['slug']}.html"
        rendered = (
            template.replace("{eyebrow}", html.escape(poster["eyebrow"]))
            .replace("{title}", html.escape(poster["title"]))
            .replace("{subtitle}", html.escape(poster["subtitle"]))
            .replace("{image_uri}", poster["image"].resolve().as_uri())
        )
        html_path.write_text(
            rendered,
            encoding="utf-8",
        )

    return html_dir, out_dir, width, height


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS.keys()),
        default="iphone61",
        help="Output preset. Use iphone65 for 1242x2688 App Store uploads.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    html_dir, out_dir, width, height = write_html_files(args.preset)
    print(f"preset={args.preset}")
    print(f"width={width}")
    print(f"height={height}")
    print(f"html_dir={html_dir}")
    print(f"out_dir={out_dir}")


if __name__ == "__main__":
    main()
