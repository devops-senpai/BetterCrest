---
title: Turn BetterCrest Passwords on or off per Space
description: Control BetterCrest-owned password suggestions, generation, and save prompts independently for every Space.
slug: /crest-passwords-per-space
sidebar_label: BetterCrest Passwords
sidebar_position: 6
keywords: [BetterCrest Passwords, password settings, Space, Keychain, turn off]
---

# Turn BetterCrest Passwords on or off per Space

BetterCrest Passwords are private to the Space that owns them. You can stop using BetterCrest-owned suggestions, generation, and save prompts in one Space without deleting its saved passwords or changing another Space. The Spaces of a [Sub-Space](./sub-spaces.md) group share one set of passwords and these settings.

## Change the setting

On Mac:

1. Open **BetterCrest Settings** and select the Space in the sidebar.
2. Select **Passwords**.
3. Turn **Use BetterCrest Passwords** on or off.

On iPhone and iPad:

1. Open **Settings → Passwords**.
2. Choose the Space you want to change from the **Space** menu.
3. Turn **Use BetterCrest Passwords** on or off.

When BetterCrest Passwords is off, saved passwords remain in that Space until you delete them. Turning the setting back on makes them available to matching sites again.

## Related controls

The same page lists the Space’s saved passwords, with **Import Passwords…** and **Export Passwords…**. When BetterCrest Passwords is on, supported Mac builds can also show:

- **Sync with iCloud Keychain**, which updates whether existing and future BetterCrest credentials in that Space synchronize through the system Keychain.
- **Offer a copy to Passwords**, which lets the system Passwords app ask separately for a copy after BetterCrest saves in the Space.

System Passwords and passkeys are provider-managed and may appear in any Space for a matching site. They are separate from BetterCrest Passwords’ Space-local records. On Mac, check BetterCrest’s access to system passkeys in **Settings → Privacy → System permissions → Passkeys**.

:::info What turning it off does not do
It does not delete saved passwords, export them, move them to another Space, or place password values in CloudKit session data.
:::

Private Spaces must be unlocked before BetterCrest reveals account and site metadata or changes their password settings.
