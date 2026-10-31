---
title: Move your browser data to BetterCrest
description: Review imports from Arc, Zen, Chrome, Safari, Firefox, and other Chromium browsers, and export portable BetterCrest data.
slug: /move-to-crest
keywords: [import, migrate, Arc, Zen, Chrome, Safari, Firefox, Brave, Edge, Vivaldi, Opera, Dia, Comet, extensions, export]
---

# Move your browser data to BetterCrest

Browser-to-browser import runs on Mac. BetterCrest prepares a visual review first so you can decide what arrives and where it belongs before the live session changes.

## Import during setup

Choose a detected browser, then review each source Space, profile, or window. Depending on what that browser exposes, BetterCrest can bring across Spaces or profiles, tabs, bookmarks, saved folders, split views, tab groups, colors, icons, extensions, and supported passwords.

| Source | BetterCrest can review |
| --- | --- |
| Arc | Spaces (each profile's as one Sub-Space group), tabs, folders, split views, colors, icons, extensions, and supported passwords |
| Zen | Spaces from every profile (each profile's as one Sub-Space group), Essentials, pinned tabs, folders, split views, open tabs, icons, and colors |
| Chrome | Profiles, bookmarks, open tabs, tab groups, split views, extensions, and supported passwords |
| Brave, Edge, Vivaldi, Opera, Dia, Comet, Aside, ego lite, Chromium, and Chrome Beta, Dev, and Canary | Profiles, bookmarks, open tabs, tab groups, split views, extensions, and supported passwords |
| Safari | Bookmarks, windows, open tabs, and pinned tabs |
| Firefox | Profiles, windows, open tabs, pinned tabs, and tab groups |

If your browser isn't listed, choose **Browser not listed?** and BetterCrest looks for other Chromium-based browsers on your Mac. Not every browser can be found this way; you can [request support for one](https://github.com/devops-senpai/BetterCrest/issues/new?template=feature_request.yml&title=Import%20from%20).

In the review, each Space shows the Chrome Web Store extensions it brings under its address bar. Turn off any you don't want, and BetterCrest installs the rest once the import finishes, without asking about each one.

For every source group, you can remove individual items, choose a new or existing BetterCrest Space, and customize that destination before importing. Spaces that share one Arc or Zen profile arrive as one [Sub-Space](../spaces/sub-spaces.md) group, so they keep sharing sign-ins; the review outlines each group and can bring a Space in on its own. When an import holds more than BetterCrest keeps, it brings what fits and lists what it left out.

## Import later

Open **Settings → Advanced**. The **Import & Export** section can import a BetterCrest archive, bookmark HTML, browser history, or open tabs from supported sources. External-browser imports always create fresh isolated BetterCrest Spaces unless the review explicitly routes content into an existing destination.

## Export a portable backup

Choose **Export Browser Data…** in **Settings → Advanced**. A BetterCrest archive includes Spaces, folders, saved and current tabs, Archive, history, and browsing preferences.

For safety, the portable archive does not contain passwords, cookies, website storage, site permissions, downloaded files, favicons, or extensions. Password export is a separate, device-authenticated plaintext operation: select a Space in the Settings sidebar, then choose **Passwords → Export Passwords…**. Treat that file as sensitive.

## After import

Browse each new Space once before removing data from your old browser. Check signed-in state, saved locations, folder nesting, and any critical extension workflow. If iCloud sync is enabled, imported Spaces and tabs can then follow you to iPad and iPhone.

