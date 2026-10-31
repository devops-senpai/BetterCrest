---
title: Install and update BetterCrest for Mac
description: Build BetterCrest from source, install it in Applications, and understand automatic updates.
slug: /install-and-update-mac
keywords: [download, install, update, macOS, GitHub Releases, Sparkle]
---

# Install and update BetterCrest for Mac

BetterCrest for Mac requires Apple silicon and macOS 26.1 or later. It runs Chromium and WebKit; see [Chromium and WebKit on Mac](../browsing/engines.md). BetterCrest is a fork of Crest and is not affiliated with Crest or Paul Davis.

## Install the latest Mac release

_Placeholder: BetterCrest has no signed download, Homebrew cask or App Store listing yet._ Build it from source as the [repository README](https://github.com/devops-senpai/BetterCrest#build-bettercrest) describes, then move the built app into **Applications**.

Keeping the app in Applications gives macOS and the updater one stable installed location.

## Automatic updates

Once BetterCrest publishes signed releases, it will use Sparkle to check for signed updates from inside the installed app. When an update is available, review the release, install it, and let BetterCrest relaunch. Your Spaces and browsing data remain in their normal app storage rather than inside the application bundle.

Turn automatic checks and installs on or off in **Settings → About**, which also has **Check for Updates…**. You can also open the app menu and choose **Check for Updates**. A manual check uses the same signed update channel as the automatic check.

## Update channels

Use **Settings → About** to choose the update channel:

- **Stable** is the normal public release cadence.
- **Nightly** receives newer builds sooner and can change more frequently.
- **Development** follows the latest signed public `main` build and can change several times a day.

Changing channels changes which future update is offered; it does not move or duplicate your profile.

## Updating from an older BetterCrest

The same installer updates older WebKit-only versions and versions that already include Chromium. Your Spaces and browser records stay in place. Chromium and WebKit keep separate website sign-ins, and older WebKit extension installations do not carry over. See [Upgrading from a WebKit-only BetterCrest](../browsing/engines.md#after-updating-from-a-webkit-only-crest) before switching engines.

BetterCrest checks pages for unsaved work before an update restart. Choose **Stay on Page** to keep working, then retry the restart when ready. Updates are offered only when your Mac meets the whole app's macOS requirement.

## iPhone and iPad

_Placeholder: BetterCrest has no iPhone or iPad builds yet._ The shared code compiles for both, so builds can be made from source with Xcode.
