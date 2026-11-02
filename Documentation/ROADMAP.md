# Arma roadmap

Planned work for Arma, in the order it is likely to land. Each item becomes
one commit on `main`; the list is edited by hand until the fork has a GitHub
project of its own.

## Planned

- **Chromium as the default engine.** New pages a person opens start in
  Chromium instead of WebKit. Per-site engine rules keep working, and a
  WebKit-only build keeps WebKit.
- **An engine setting.** Settings gains a control for the default engine and
  a "Remember per website" option: when on, choosing an engine for a site in
  "Opens in" keeps that choice as the site's rule; when off, it applies once.
- **One sign-in across engines.** Cookies and session state a Space has in
  WebKit are shared with Chromium and back, so a site signed in on one engine
  is signed in on the other, within the same profile and never across
  private browsing.
- **Split View arrangements in archives.** A browsing-data archive keeps each
  split's tiled arrangement, so an import restores the quadrants rather than
  one row of columns.

## In dogfood

- **Tiled Split View** (branch `feat/split-tiling`): stacked and tiled pages,
  ready-made arrangements, swapping cards by drop, and Move Card from a tab's
  menu, with logging of the layout path while it is tried out.

Upstream Crest's roadmap lives in its own repository and is not mirrored here.
`Scripts/render-roadmap.py` still targets upstream's GitHub project and is not
used by this fork until it has a project of its own.
