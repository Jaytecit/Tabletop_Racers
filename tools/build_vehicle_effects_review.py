"""Assemble unaltered rendered evidence into labelled comparison clips/sheets."""
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "tests/baselines/vehicle_effects"
OUTPUT = ROOT / "docs/verification/vehicle-effects-media"
OUTPUT.mkdir(exist_ok=True)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)

selected = ["drift_drift_car", "boost_buggy", "actual_impact", "nighttime_noodles_80"]
labels = ["Drift smoke and tyre marks", "Boost exhaust", "Impact sparks at the contact", "Night: smoke and boost"]
sheet = Image.new("RGB", (1440, 1024), "#121726")
draw = ImageDraw.Draw(sheet)
for index, (name, label) in enumerate(zip(selected, labels)):
    x, y = index % 2 * 720, index // 2 * 512
    shot = Image.open(EVIDENCE / "verification-final03" / f"{name}.jpg")
    sheet.paste(shot.resize((720, 480)), (x, y))
    draw.text((x + 12, y + 484), label, fill="white", font=font)
sheet.save(OUTPUT / "preview.jpg", quality=90)

# 12 rendered samples, 3 physics ticks between samples. Playback at 8 fps makes
# the short fixtures easier to inspect (2.5x slower); the full source frames stay.
for kind in ["drift", "brake", "boost", "impact", "dirt"]:
    args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    for variant in ["before-final-normal", "after-final-normal"]:
        args += ["-framerate", "8", "-i", str(EVIDENCE / variant / f"{kind}_%02d.jpg")]
    args += ["-filter_complex", "[0:v][1:v]hstack=inputs=2,scale=1620:540[v]",
             "-map", "[v]", "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
             str(OUTPUT / f"{kind}-before-after.mp4")]
    subprocess.run(args, check=True)

results = {}
for variant in ["before-final-normal", "before-final-reduced", "after-final-normal", "after-final-reduced"]:
    raw = json.loads((EVIDENCE / variant / "results.json").read_text())
    results[variant] = raw["reports"]["performance"]
(OUTPUT / "performance.json").write_text(json.dumps(results, indent=2))
