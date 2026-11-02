# CrestShared/Features/SplitView

Arma's split view: page cards tiled as the split's layout says, in columns
and stacked rows, the gaps between them and the dividers in those gaps, card
focus, placeholders, and the drop landings that add a page beside a card or
beside the whole split. `BrowserSplitTilesView` owns geometry only; frames
come from `BrowserSplitTileLayout` over a `BrowserSplitTile`, which reads the
core's layout, and membership and the layout come from the session.

## Goal

One split layout for the Mac, the mobile shell and the Getting Started
practice window.

## Contents

| Path | What it is |
| --- | --- |
| `Components/BrowserSplitCardResizeHandle/` | Dragging a divider between cards |
| `Components/` (files) | Tiles view, placeholder card, focus indicator, content drop zone and drop-card frame modifiers |
| `Models/` | Page surface presentation (tiled cards or one page), the tile and where a drop lands in it, column slots, panel columns, layout transaction, card move direction |
| `Support/` | Tile, column and panel layout, layout metrics, resize space, drop-target view extension |

## Depends on

The core's `TabStateModel` and `SpaceModel` through
`CrestShared/Infrastructure/Core/`, `CrestShared/Domain/` (runtime
assignments), `Sidebar/` (reorder state for card drags), `Chrome/` (layout
and appearance), `DesignSystem/`. Hosted by `CrestMac/Features/SplitView/`,
`CrestMobile/Features/SplitView/` (whose cards place native tabs through
`NativeTabs/BrowserNativeTabHost.swift`), the platform `Browser/` roots,
`Sidebar/` and `GettingStarted/`.

## Rules

- Split membership, order and layout are core state; the view never edits them, and only previews where a drop would land (skill, "Architecture").
- A tab dragged between workspaces arrives without its source folder or split membership (`Documentation/ARCHITECTURE.md`, "Windows on macOS").
- Native and website cards share the split; only website members get pages (`Documentation/NativeTabs.md`, opening section).
- Name metrics and thresholds in the type that owns them (`Documentation/ARCHITECTURE.md`, "Platform shape").

## Read next

`Documentation/NativeTabs.md`, then `Sidebar/` for split group rows and the
platform `SplitView/` folder.
