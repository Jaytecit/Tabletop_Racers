"""Read-only reference inventory and VGA palette preview; never executes game files."""
import csv
import hashlib
import json
from pathlib import Path
import zipfile
from PIL import Image, ImageDraw

source = Path(r"C:\Users\jayte\Downloads\Micro-Machines_DOS_EN.zip")
output = Path(__file__).parent
with zipfile.ZipFile(source) as archive:
    entries = [item for item in archive.infolist() if not item.is_dir()]
    with (output / "archive_inventory.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["path", "bytes", "compressed_bytes", "sha256"])
        for item in entries:
            writer.writerow([item.filename, item.file_size, item.compress_size,
                             hashlib.sha256(archive.read(item)).hexdigest()])
    palettes = []
    for item in entries:
        if item.filename.upper().endswith(".PAL"):
            data = archive.read(item)
            if len(data) != 768 or max(data) > 63:
                raise ValueError(f"Unexpected palette structure: {item.filename}")
            colours = [tuple(round(channel * 255 / 63) for channel in data[i:i+3])
                       for i in range(0, 768, 3)]
            palettes.append((item.filename, colours))
    # Duplicate intro palettes are explicitly labelled, not silently discarded.
    board = Image.new("RGB", (1100, 660), "#24202f")
    draw = ImageDraw.Draw(board)
    draw.text((16, 10), "DOS ARCHIVE PALETTES - 256 colours each, 6-bit channels scaled to RGB", fill="white")
    for index, (name, colours) in enumerate(palettes):
        x, y = 16 + (index % 5) * 218, 40 + (index // 5) * 204
        draw.text((x, y), name, fill="white")
        for colour_index, colour in enumerate(colours):
            left, top = x + colour_index % 16 * 11, y + 20 + colour_index // 16 * 11
            draw.rectangle((left, top, left+10, top+10), fill=colour)
    board.save(output / "dos_palettes.png")
    (output / "dos_palettes.json").write_text(json.dumps({
        name: ["#%02x%02x%02x" % colour for colour in colours]
        for name, colours in palettes}, indent=2), encoding="utf-8")
    print(json.dumps({"files":len(entries), "bytes":sum(item.file_size for item in entries),
                      "palettes":len(palettes), "maps":sum(item.filename.endswith('.MAP') for item in entries),
                      "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest()}))
