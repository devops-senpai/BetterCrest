---
title: Customize and arrange Spaces
description: Design a Space in Crest Studio, customize its folders, and choose its browsing and cleanup settings.
slug: /customize-spaces
keywords: [Crest Studio, Space Forge, theme, gradient, crest, emoji, monogram, folders, cleanup, reorder, Appearance, add Space, rename Space]
---

# Customize and arrange Spaces

Open a Space’s context menu to edit it, or open its page in Settings. On Mac, select the Space in the Settings sidebar; on iPhone and iPad, choose it in **Settings → Spaces**. A strong visual identity makes a profile boundary obvious before you type a password or open a work account.

## Choose an identity

Arma offers two presentation styles:

- **Banner** uses Crest Studio: begin with a template, then choose a shape, field division, pattern, trim, and heraldic artwork. Use independent colors for the parts of your design, or make an identity with an emoji, monogram, or searchable SF Symbol.
- **Traditional Gradient** blends one to three colors with direction, intensity, and optional texture.

The result appears in the Space picker and browser chrome on Mac, iPad, and iPhone.

Crest Studio is on the Space’s Appearance page. The crest sits on the Space’s own sidebar background, with its colors named by what they paint:

- **Arma:** Field, Second field, Band, Emblem, Border and Edge. A color for a part the crest doesn’t draw is dimmed.
- **Sidebar:** Background, Accent (selected tabs, pins, the address field and the Space picker) and Pattern.

Click or tap a color to choose one of the templates’ tinctures or a custom color. Below the crest, work through **Start from**, **Shape**, **Field**, **Band**, **Emblem**, **Border**, **Finish**, **Sidebar** and **Other**; each step shows your crest with each choice applied. On iPhone, the steps are a list showing what each has chosen; tap one to open it. Choose **Icon** at the top of **Emblem** to use an SF Symbol or emoji instead of a crest. **Shuffle** suggests a new crest in the templates’ colors, and **Undo** steps back through your changes. **Artwork Credits** is in the **…** menu on the Space’s page.

On Mac, a Space picks its colors from a theme: choose one from **Theme** at the top of its Appearance page, and the page keeps only the crest’s own steps, **Shape** through **Finish**. Start from, Sidebar, Other, the dark look and the background picture are edited under **Settings → Themes**, and every Space using that theme follows. A Space that had a look of its own gets it saved as a theme named for the Space. On iPhone and iPad, **Reset Appearance** is in the **…** menu.

## Customize folders

The **Folders** group in the **Sidebar** step (of the theme under **Settings → Themes** on Mac, of the Space’s Appearance page elsewhere) sets the color every folder in the Space wears until you give it one of its own, the color of the folder’s back face, and how strongly folders tint their rows. The Sidebar step also chooses the text tone, or one exact text color for the sidebar. Individual folder menus let you set colors, search the full SF Symbols catalog, or choose emoji. You can show a custom icon on its own instead of the animated folder artwork. In **Settings → Appearance**, enable **Tint Folder Title** to use semibold titles in the folder’s color, adjusted for stronger contrast against light or dark sidebars.

## Tint the command palette

The **Command Palette** group in the **Other** step (of the theme on Mac, of the Space’s Appearance page elsewhere) lays a color over the palette’s glass in this Space, with its own tint, opacity and text color for the light and the dark appearance. Opacity runs from the glass alone to the solid color. Each group has a **Reset** that puts its choices back to the Space’s starting look, and each row keeps its own reset.

## A look for dark windows

Turn on **Dark look** at the top of a theme under **Settings → Themes** on Mac, or of a Space’s Appearance page elsewhere, to give the Space a second look that it wears while Arma’s windows are dark, starting from its light look. Choose **Light** or **Dark** beside the switch to edit either one; the sidebar switches between them with the system appearance or your Appearance mode. Turn the switch off to wear one look in both again.

## Share a theme

On Mac, use the export and import buttons under the theme list in **Settings → Themes** to save a theme as a file or add one someone shared. The `arma` tool inside Arma does the same from the terminal while Arma is open. It needs only Arma running; agents can stay off.

```sh
/Applications/Arma.app/Contents/Helpers/arma theme --space Personal --export ~/Desktop/dusk.json
/Applications/Arma.app/Contents/Helpers/arma theme --space Work --from-file ~/Desktop/dusk.json
/Applications/Arma.app/Contents/Helpers/arma theme --space Work --folder-color "#7a8bb0" --palette-dark "#101218" --palette-dark-opacity 0.7
/Applications/Arma.app/Contents/Helpers/arma theme --space Work --reset command-palette
```

A theme file is JSON with a section for each part of the look, and a theme can name only the parts it changes:

```json
{
  "name": "Dusk",
  "background": { "colors": ["#1b1f2a", "#3a2f5b"], "style": "gradient", "angle": 135, "intensity": 0.8, "sidebarText": "#e6e9ef" },
  "icon": { "color": "#ffd166" },
  "folders": { "color": "#7a8bb0", "backColor": "#5c6b8a", "outlineColor": "default", "intensity": 0.3 },
  "commandPalette": { "light": { "tint": "#ffffff", "opacity": 0.5 }, "dark": { "tint": "#101218", "opacity": 0.7, "text": "#cdd6f4" } }
}
```

Colors are `#RRGGBB` or `#RRGGBBAA`; the word `default` lets a chosen color go. A `"dark"` object with the same sections gives the Space its look for dark windows, and `--dark-from-file` applies a second theme file as that look. Run `arma theme` with no options to see every flag.

## Customize the browser around your Spaces

Open **Settings → Appearance** for device-wide appearance: a left- or right-side sidebar, borderless pages, tab shape and scale, pinned-tab layout, address-field colors, and a default page zoom from **50% to 300%**. Selected tabs, pins, and the address field follow the current Space’s color; turn off **Follow Space accent** to pick a custom color instead. Presets and a live preview help you find a starting point; each changed setting has its own reset.

Choose an app icon palette here too. These controls change the browser on this device; a Space’s identity belongs to that Space and stays on its own Appearance page.

## Add and arrange Spaces

On Mac, click **+** next to the Spaces heading in the Settings sidebar to add a Space. Its Appearance page opens with the name ready to type. Right-click a Space there, or use the **…** menu on its page, to rename it, edit its crest, lock it, or delete it. Arma needs at least one Space. Choose **New Sub-Space** from the same menu for a Space that shares this one's sign-ins; see [Sub-Spaces](./sub-spaces.md).

Drag a Space in the picker to reorder it. In the Mac Settings sidebar, click the pencil next to the Spaces heading, drag Spaces by their handles, then click the checkmark; or right-click a Space and choose **Move Up** or **Move Down**. On iPhone and iPad, use the order controls in **Settings → Spaces**. Position matters for **Control-1** through **Control-9**, so put frequently used Spaces first. A group's Sub-Spaces stay together after their primary, and dragging the primary moves the whole group.

## Automatic cleanup

Each Space can archive unpinned current tabs after **12 hours, 24 hours, 7 days, or 30 days**, or keep them until you close them. On Mac, set this with **Archive current tabs** on the Space’s Browsing page, and choose **Archive Now** to run it right away. Cleanup moves tabs into the recoverable Archive; it does not silently erase them.

Pinned sites, saved tabs, folders, and tabs marked **Keep Loaded** have different roles from ordinary current tabs. Use a saved tab for something you intend to revisit, and Keep Loaded only when the live in-page state matters.
