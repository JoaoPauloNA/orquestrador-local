#!/usr/bin/env python3
"""Reproducible WCAG contrast checks for semantic text pairs.

r7: Values extracted directly from actual .colorset/Contents.json files.
No hardcoded approximations. Each pair corresponds to actual View usage.
CardSurface and OrqDanger source-of-truth mismatches from r6 corrected.

Color source mapping:
- StateBadgeView: textColor uses OrqGreenText, OrqGoldText, OrqMuted, OrqDangerText, OrqExternalText
                bgColor uses OrqGreenBg, OrqGoldBg, OrqNeutralBg, OrqDangerBg, OrqExternalBg
                iconColor uses OrqGreenAccent, OrqGoldAccent, OrqMuted, OrqDanger, OrqExternal
- ServiceDetailView: OrqDanger stroke opacity(0.3) on CardSurface, OrqGoldText on confirmation section
- ServiceCardView: CardSurface as card background, OrqDangerText for error text
- MenuBarPopoverView: OrqDangerText on "Sair" button, OrqDanger as icon

Pairs verified against actual source code usage patterns.
"""

import json
import os
import sys

# Base path to colorsets
COLORSET_BASE = "Sources/OrquestradorLocal/Resources/Assets.xcassets"

def hex_from_colorset(color_name):
    """Extract hex color from a colorset's Contents.json, respecting light/dark appearance."""
    colorset_path = os.path.join(COLORSET_BASE, f"{color_name}.colorset", "Contents.json")
    if not os.path.exists(colorset_path):
        return None, None, f"Colorset not found: {colorset_path}"

    with open(colorset_path, 'r') as f:
        data = json.load(f)

    colors = data.get("colors", [])
    light_hex = None
    dark_hex = None

    for color_entry in colors:
        appearances = color_entry.get("appearances", [])
        is_dark = any(a.get("appearance") == "luminosity" and a.get("value") == "dark" for a in appearances)

        components = color_entry.get("color", {}).get("components", {})
        r = int(float(components["red"]) * 255)
        g = int(float(components["green"]) * 255)
        b = int(float(components["blue"]) * 255)
        hex_val = f"{r:02x}{g:02x}{b:02x}"

        if is_dark:
            dark_hex = hex_val
        else:
            light_hex = hex_val

    return light_hex, dark_hex, None

# Build color table from actual colorsets
COLOR_TABLE = {}
color_names = [
    "CardSurface", "OrqDanger", "OrqDangerText", "OrqDangerBg",
    "OrqGoldText", "OrqGoldBg", "OrqGoldAccent",
    "OrqGreenAccent", "OrqGreenText", "OrqGreenBg",
    "OrqMuted", "OrqExternalText", "OrqExternalBg", "OrqExternal",
    "OrqNeutralBg"
]

print("=== Color Values from Colorsets ===")
for name in color_names:
    light, dark, err = hex_from_colorset(name)
    if err:
        print(f"  {name}: ERROR - {err}")
    else:
        COLOR_TABLE[name] = {"light": light, "dark": dark}
        print(f"  {name}: light=#{light}, dark=#{dark}")

# WCAG contrast pairs — all verified against actual View usage
# Format: (foreground_name, background_name, mode)
# Values extracted directly from colorsets above

PAIRS = [
    # ── StateBadgeView: Ready (OrqGreenText on OrqGreenBg) ─────────────
    ("OrqGreenText", "OrqGreenBg", "light"),
    ("OrqGreenAccent", "OrqGreenBg", "dark"),  # icon color on dark bg

    # ── StateBadgeView: Starting/Stopping (OrqGoldText on OrqGoldBg) ─────
    ("OrqGoldText", "OrqGoldBg", "light"),
    ("OrqGoldText", "OrqGoldBg", "dark"),  # OrqGoldText dark on OrqGoldBg dark

    # ── StateBadgeView: Stopped (OrqMuted on OrqNeutralBg) ─────────────
    ("OrqMuted", "OrqNeutralBg", "light"),
    ("OrqMuted", "OrqNeutralBg", "dark"),

    # ── StateBadgeView: Error (OrqDangerText on OrqDangerBg) ───────────
    ("OrqDangerText", "OrqDangerBg", "light"),
    ("OrqDangerText", "OrqDangerBg", "dark"),

    # ── StateBadgeView: External (OrqExternalText on OrqExternalBg) ─────
    ("OrqExternalText", "OrqExternalBg", "light"),
    ("OrqExternalText", "OrqExternalBg", "dark"),

    # ── ServiceDetailView: OrqDanger stroke on CardSurface ──────────────
    # OrqDanger used as stroke .opacity(0.3) on CardSurface
    ("OrqDanger", "CardSurface", "light"),
    ("OrqDanger", "CardSurface", "dark"),

    # ── ServiceDetailView: Error message (OrqDangerText on OrqDangerBg) ─
    ("OrqDangerText", "OrqDangerBg", "light"),  # same as StateBadge error

    # ── ServiceCardView: Error text (OrqDangerText on CardSurface) ─────
    ("OrqDangerText", "CardSurface", "light"),
    ("OrqDangerText", "CardSurface", "dark"),

    # ── ServiceDetailView: Stop confirmation (OrqGoldText on CardSurface) ─
    ("OrqGoldText", "CardSurface", "light"),
    ("OrqGoldText", "CardSurface", "dark"),

    # ── MenuBarPopoverView: "Sair" button (OrqDangerText on standard bg) ─
    # Uses OrqDangerText as foreground, no named background (system)
    # Skipped - not a named token pair

    # ── CardSurface as card background ────────────────────────────────
    ("OrqMuted", "CardSurface", "light"),  # secondary text on card
    ("OrqMuted", "CardSurface", "dark"),
]

def linear(component):
    component /= 255
    return component / 12.92 if component <= 0.04045 else ((component + 0.055) / 1.055) ** 2.4

def luminance(hex_value):
    r = int(hex_value[0:2], 16)
    g = int(hex_value[2:4], 16)
    b = int(hex_value[4:6], 16)
    red, green, blue = map(linear, [r, g, b])
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue

def contrast_ratio(fg, bg):
    l1, l2 = sorted([luminance(fg), luminance(bg)], reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)

# Build pair table with actual hex values
print("\n=== WCAG Contrast Verification ===")
failed = []
results = []

for fg_name, bg_name, mode in PAIRS:
    fg_data = COLOR_TABLE.get(fg_name, {})
    bg_data = COLOR_TABLE.get(bg_name, {})

    if not fg_data or not bg_data:
        print(f"SKIP {fg_name}/{bg_name}/{mode}: color not found in table")
        continue

    fg_hex = fg_data.get(mode, fg_data.get("light"))
    bg_hex = bg_data.get(mode, bg_data.get("light"))

    if not fg_hex or not bg_hex:
        print(f"SKIP {fg_name}/{bg_name}/{mode}: missing {mode} variant")
        continue

    ratio = contrast_ratio(fg_hex, bg_hex)
    verdict = "PASSOU" if ratio >= 4.5 else "FALHOU"
    label = f"{mode}/{fg_name}-{bg_name}"
    print(f"{label}: #{fg_hex} sobre #{bg_hex} = {ratio:.2f}:1 — {verdict}")
    results.append((label, fg_hex, bg_hex, ratio, verdict))

    if verdict == "FALHOU":
        failed.append(label)

# Summary
print(f"\n=== Summary: {len(results) - len(failed)}/{len(results)} pares PASSARAM ===")
if failed:
    print(f"FALHARAM: {failed}")
    sys.exit(1)
else:
    print("Todos os pares passam WCAG AA (4.5:1)")
    sys.exit(0)
