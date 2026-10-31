#!/usr/bin/env python3
"""Generate Arma's app icons: the default icon, one variant per palette, one
icon per emblem banner, and the previews and Dock images the app loads for its
icon picker.

The mark is the Honor banner in Brand/AppIcons/ArmaHonor.svg. The default icon
draws it as designed; each palette variant recolors the banner with the palette's
color. Every palette icon sits on a light tint of its banner color in both
appearances. Each emblem icon draws another banner from Brand/AppIcons as
designed, on a neutral field that is light in light mode and the system's dark
in dark mode. The .icon names are Arma, ArmaWinter, ArmaFlight and so on, as the
asset catalog settings and the icon picker refer to them."""
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
# The other banners in Brand/AppIcons, in the order the icon picker shows them.
# Honor is the default icon and so is not repeated here.
EMBLEMS = [
    "Flight", "Flame", "Scarlet", "Raven", "Porcelain", "Slate", "Signal", "Sash", "Horizon",
    "Crimson", "Blush", "Frost", "Ruby", "Rose", "Silver",
    "Amethyst", "Orchid", "Iris", "Lilac", "Violet", "Plum",
    "Crane", "Drift", "Origami", "Steel", "Garnet", "Wisteria",
    "Imperial", "Aureate", "Laurel", "Marble", "Triumph", "Mosaic",
    "Verdigris", "Copper", "Porphyry", "Lapis", "Patina", "Argent",
    "Senate", "Vexillum", "Bronze", "Tessera", "Victory",
]
EMBLEM_FIELD_LIGHT = "#F5F5F8"
EMBLEM_FIELD_DARK = "#202024"


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
    return svg_inner(BANNER).replace(f'fill="{BANNER_FILL}"', f'fill="{color}"')


def svg_inner(path):
    """The drawing inside an SVG file's root element."""
    return re.search(r"<svg[^>]*>(.*)</svg>", path.read_text(), re.S).group(1)


def emblem_file(emblem):
    return ROOT / f"Brand/AppIcons/Arma{emblem}.svg"


# How tall the banner stands on the 1024-point icon canvas. Icon Composer's
# squircle still clears its corners at this size.
BANNER_HEIGHT = 799


def view_box(path=BANNER):
    """A banner file's viewBox: x, y, width, height."""
    return [float(v) for v in re.search(r'viewBox="([^"]+)"', path.read_text()).group(1).split()]


def placed(inner, path=BANNER):
    """A banner's drawing, scaled to stand `BANNER_HEIGHT` tall and centered."""
    x, y, w, h = view_box(path)
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


def emblem_mark_svg(emblem):
    source = emblem_file(emblem)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
        f"  {placed(svg_inner(source), source)}\n</svg>\n"
    )


def emblem_preview_svg(emblem, dark):
    source = emblem_file(emblem)
    field = EMBLEM_FIELD_DARK if dark else EMBLEM_FIELD_LIGHT
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
        f'  <rect x="0" y="0" width="1024" height="1024" rx="232" fill="{field}"/>\n'
        f"  {placed(svg_inner(source), source)}\n</svg>\n"
    )


def icon_document(color):
    red, green, blue = rgb(tint(color))
    field = {"automatic-gradient": f"extended-srgb:{red:.5f},{green:.5f},{blue:.5f},1.00000"}
    return layered_document([{"value": field}, {"appearance": "dark", "value": field}])


def emblem_document():
    red, green, blue = rgb(EMBLEM_FIELD_LIGHT)
    light = {"solid": f"srgb:{red:.5f},{green:.5f},{blue:.5f},1.00000"}
    return layered_document([{"value": light}, {"appearance": "dark", "value": "system-dark"}])


def layered_document(fills):
    return {
        "fill-specializations": fills,
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


def write_icon(name, mark, document):
    icon = ICON_ROOT / f"{name}.icon"
    assets = icon / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    for stale in assets.glob("*.svg"):
        stale.unlink()
    (assets / "ArmaMark.svg").write_text(mark)
    write_json(icon / "icon.json", document)


def write_preview(name, light, dark=None):
    """The picker preview: one drawing, or a light and a dark one."""
    preview = PREVIEWS / f"{name}Preview.imageset"
    preview.mkdir(exist_ok=True)
    for stale in preview.glob("*.svg"):
        stale.unlink()
    (preview / "icon.svg").write_text(light)
    images = [{"filename": "icon.svg", "idiom": "universal"}]
    if dark is not None:
        (preview / "icon-dark.svg").write_text(dark)
        images.append({"filename": "icon-dark.svg", "idiom": "universal",
                       "appearances": [{"appearance": "luminosity", "value": "dark"}]})
    write_json(preview / "Contents.json", {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    })


def main():
    PREVIEWS.mkdir(exist_ok=True)
    write_json(PREVIEWS / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for name, color in [BASE, *VARIANTS]:
        write_icon(name, mark_svg(color), icon_document(color))
        write_preview(name, preview_svg(color))
    for emblem in EMBLEMS:
        write_icon(f"Arma{emblem}", emblem_mark_svg(emblem), emblem_document())
        write_preview(f"Arma{emblem}", emblem_preview_svg(emblem, False), emblem_preview_svg(emblem, True))
    # Complete Mac icons at 1x and 2x from Apple's renderer, for the Dock and
    # the picker. Clear and tinted still come from Icon Services at runtime.
    developer = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
    exporter = developer.parent / "Applications/Icon Composer.app/Contents/Executables/ictool"
    with tempfile.TemporaryDirectory(prefix="arma-icon-export-") as temporary:
        working = Path(temporary)
        padding_tool = working / "pad-mac-app-icon"
        subprocess.run(["xcrun", "swiftc", str(ROOT / "Scripts/pad-mac-app-icon.swift"), "-o", str(padding_tool)], check=True)
        for name in [BASE[0], *(name for name, _ in VARIANTS), *(f"Arma{emblem}" for emblem in EMBLEMS)]:
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
    print(f"Generated {1 + len(VARIANTS)} icons from {BANNER.relative_to(ROOT)} and {len(EMBLEMS)} emblem icons, "
          "with previews and Dock images.")


if __name__ == "__main__":
    main()
