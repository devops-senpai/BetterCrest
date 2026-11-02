---
title: Install and update Arma for Mac
description: Build Arma from source, install it in Applications, and understand automatic updates.
slug: /install-and-update-mac
keywords: [download, install, update, macOS, GitHub Releases, Sparkle]
---

# Install and update Arma for Mac

Arma for Mac requires Apple silicon and macOS 26.1 or later. It runs Chromium and WebKit; see [Chromium and WebKit on Mac](../browsing/engines.md). Arma is a fork of Crest and is not affiliated with Crest or Paul Davis.

## Install the latest Mac release

Download the latest **Installer** disk image from
[Releases](https://github.com/devops-senpai/Arma/releases), open it, and drag
Arma onto **Applications**. Arma for Mac needs Apple silicon and macOS 26.1 or
later.

These preview builds are signed but not yet notarized by Apple, so the first
time you open Arma, macOS stops it. Open **System Settings › Privacy &
Security**, scroll to the message about Arma, and choose **Open Anyway**; after
that it opens normally.

You can also build it from source as the [repository README](https://github.com/devops-senpai/Arma#build-arma) describes, then move the built app into **Applications**.

Keeping the app in Applications gives macOS and the updater one stable installed location.

## Automatic updates

Once Arma publishes signed releases, it will use Sparkle to check for signed updates from inside the installed app. When an update is available, review the release, install it, and let Arma relaunch. Your Spaces and browsing data remain in their normal app storage rather than inside the application bundle.

Turn automatic checks and installs on or off in **Settings → About**, which also has **Check for Updates…**. You can also open the app menu and choose **Check for Updates**. A manual check uses the same signed update channel as the automatic check.

## Update channels

Use **Settings → About** to choose the update channel:

- **Stable** is the normal public release cadence.
- **Nightly** receives newer builds sooner and can change more frequently.
- **Development** follows the latest signed public `main` build and can change several times a day.

Changing channels changes which future update is offered; it does not move or duplicate your profile.

## Updating from an older Arma

The same installer updates older WebKit-only versions and versions that already include Chromium. Your Spaces and browser records stay in place. Chromium and WebKit keep separate website sign-ins, and older WebKit extension installations do not carry over. See [Upgrading from a WebKit-only Arma](../browsing/engines.md#after-updating-from-a-webkit-only-crest) before switching engines.

Arma checks pages for unsaved work before an update restart. Choose **Stay on Page** to keep working, then retry the restart when ready. Updates are offered only when your Mac meets the whole app's macOS requirement.

## iPhone and iPad

_Placeholder: Arma has no iPhone or iPad builds yet._ The shared code compiles for both, so builds can be made from source with Xcode.
