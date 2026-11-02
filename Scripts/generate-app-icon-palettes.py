#!/usr/bin/env python3
"""Generate Arma's app icons: the default icon, one variant per palette, and
the previews and Dock images the app loads for its icon picker.

The mark is the Honor banner in Brand/AppIcons/ArmaHonor.svg. The default icon
draws it as designed; each palette variant recolors the banner with the palette's
color. Every icon sits on a light tint of its banner color in both appearances.
The .icon names are Arma, ArmaWinter and so on, as the asset
catalog settings and the icon picker refer to them."""
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON_ROOT = ROOT / "CrestShared/Resources/ArmaIcon"
PREVIEWS = ROOT / "CrestShared/Resources/AppIconPreviews.xcassets"
BANNER = ROOT / "Brand/AppIcons/ArmaHonor.svg"
BANNER_FILL = "#313244"

BASE = ("Arma", BANNER_FILL)
VARIANTS = [
    ("ArmaWinter", "#3B82F6"), ("ArmaLion", "#D97706"), ("ArmaStorm", "#475569"),
    ("ArmaDragon", "#DC2626"), ("ArmaMeadow", "#16A34A"), ("ArmaIron", "#71717A"),
    ("ArmaRiver", "#0E7490"), ("ArmaSun", "#F59E0B"), ("ArmaVigil", "#7C3AED"),
]


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def rgb(color):
    return tuple(int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))


def hex_color(channels):
    return "#" + "".join(f"{round(c * 255):02X}" for c in channels)


def tint(color, amount=0.82):
    """`color` mixed toward white: the field the banner flies on."""
    return hex_color(c + (1 - c) * amount for c in rgb(color))


def banner_inner(color):
    text = BANNER.read_text()
    inner = re.search(r"<svg[^>]*>(.*)</svg>", text, re.S).group(1)
    return inner.replace(f'fill="{BANNER_FILL}"', f'fill="{color}"')


# How tall the banner stands on the 1024-point icon canvas. Icon Composer's
# squircle still clears its corners at this size.
BANNER_HEIGHT = 799


def view_box():
    """The banner file's viewBox: x, y, width, height."""
    text = BANNER.read_text()
    return [float(v) for v in re.search(r'viewBox="([^"]+)"', text).group(1).split()]


def placed(inner):
    """The banner's drawing, scaled to stand `BANNER_HEIGHT` tall and centered."""
    x, y, w, h = view_box()
    scale = BANNER_HEIGHT / h
    tx, ty = (1024 - w * scale) / 2 - x * scale, (1024 - h * scale) / 2 - y * scale
    return f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale:.4f})">{inner}</g>'


def mark_svg(color):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
        f"  {placed(banner_inner(color))}\n</svg>\n"
    )


def preview_svg(color):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
        f'  <rect x="0" y="0" width="1024" height="1024" rx="232" fill="{tint(color)}"/>\n'
        f"  {placed(banner_inner(color))}\n</svg>\n"
    )


def icon_document(color):
    red, green, blue = rgb(tint(color))
    field = {"automatic-gradient": f"extended-srgb:{red:.5f},{green:.5f},{blue:.5f},1.00000"}
    return {
        "fill-specializations": [{"value": field}, {"appearance": "dark", "value": field}],
        "groups": [{
            "layers": [{
                "fill-specializations": [
                    {"value": "none"}, {"appearance": "dark", "value": "none"}, {"appearance": "tinted", "value": "none"},
                ],
                "image-name": "ArmaMark.svg",
                "name": "ArmaMark",
            }],
            "name": "Arma Layers",
            "shadow": {"kind": "neutral", "opacity": 0.6},
            "translucency": {"enabled": True, "value": 0.2},
        }],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }


def main():
    PREVIEWS.mkdir(exist_ok=True)
    write_json(PREVIEWS / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for name, color in [BASE, *VARIANTS]:
        icon = ICON_ROOT / f"{name}.icon"
        assets = icon / "Assets"
        assets.mkdir(parents=True, exist_ok=True)
        for stale in assets.glob("*.svg"):
            stale.unlink()
        (assets / "ArmaMark.svg").write_text(mark_svg(color))
        write_json(icon / "icon.json", icon_document(color))
        preview = PREVIEWS / f"{name}Preview.imageset"
        preview.mkdir(exist_ok=True)
        for stale in preview.glob("*.png"):
            stale.unlink()
        (preview / "icon.svg").write_text(preview_svg(color))
        write_json(preview / "Contents.json", {
            "images": [{"filename": "icon.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        })
    # Complete Mac icons at 1x and 2x from Apple's renderer, for the Dock and
    # the picker. Clear and tinted still come from Icon Services at runtime.
    developer = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
    exporter = developer.parent / "Applications/Icon Composer.app/Contents/Executables/ictool"
    with tempfile.TemporaryDirectory(prefix="arma-icon-export-") as temporary:
        working = Path(temporary)
        padding_tool = working / "pad-mac-app-icon"
        subprocess.run(["xcrun", "swiftc", str(ROOT / "Scripts/pad-mac-app-icon.swift"), "-o", str(padding_tool)], check=True)
        for name, _ in [BASE, *VARIANTS]:
            for appearance, rendition in [("Light", "Default"), ("Dark", "Dark")]:
                target = PREVIEWS / f"{name}Dock{appearance}.imageset"
                target.mkdir(exist_ok=True)
                images = []
                for scale in (1, 2):
                    filename = "icon.png" if scale == 1 else "icon@2x.png"
                    face = working / "face.png"
                    subprocess.run([str(exporter), str(ICON_ROOT / f"{name}.icon"), "--export-image", "--output-file", str(face),
                                    "--platform", "macOS", "--rendition", rendition,
                                    "--width", "412", "--height", "412", "--scale", str(scale)],
                                   check=True, stdout=subprocess.DEVNULL)
                    subprocess.run([str(padding_tool), str(face), str(target / filename), str(512 * scale)], check=True)
                    images.append({"filename": filename, "idiom": "mac", "scale": f"{scale}x"})
                write_json(target / "Contents.json", {"images": images, "info": {"author": "xcode", "version": 1}})
    print(f"Generated {1 + len(VARIANTS)} icons with previews and Dock images from {BANNER.relative_to(ROOT)}.")


if __name__ == "__main__":
    main()
