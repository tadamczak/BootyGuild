# Changelog

## 0.1.0-dev.7 — 2026-10-09

- Use current Booty names for shared window components.

## 0.1.0-dev.6 — 2026-10-08

- Remove unused legacy guild summary and roster callbacks; retain current screen-owned controllers and data.

## 0.1.0-dev.5 — 2026-10-07

- Guard roster export reload confirmation against active raid or recording work in every Booty product.
- Recover failed startup and Resume without duplicating scan or event resources; retain failed cleanup for retry.

## 0.1.0-dev.4 — 2026-10-07

- Let Guild filters expand for their captions and wrap when needed.
- Keep Lvl compact with a clear gap before Class; give Name and Zone available space.

## 0.1.0-dev.3 — 2026-10-05

- Use the shared window order for standalone Guild, Settings and guild dialogs.
- Keep member-action and roster-export confirmations above the Guild window.

## 0.1.0-dev.2 — 2026-10-05

- Fix Guild and guild actions failing to open from Quick Menu.
- Organize standalone Settings under Profile and Guild.

## 0.1.0-dev.1 — 2026-10-05

- Extract Guild and Guild Statistics into a standalone addon with Booty Suite integration.
- Preserve existing roster data and settings through owner-specific legacy migration.
- Share completed guild snapshots through BootyLib without requiring BootyRaider.
- Retain selected scan diagnostics and named settings profiles through shared BootyLib services.
