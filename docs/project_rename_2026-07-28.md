# Blood Will Pay project rename

Effective July 28, 2026, the game and project are named **Blood Will Pay**.
The project was formerly developed under the working title **Gamble Battle**.
Historical reports, serialized save-envelope identifiers, legacy user-data
directories, and archived evidence may retain the former name when changing it
would break compatibility or falsify the historical record.

## Canonical identity

- Product name: `Blood Will Pay`
- Repository slug: `Blood-Will-Pay`
- Local project folder: `blood-will-pay`
- Windows export: `BloodWillPay.exe`
- Godot user-data folder: `Blood Will Pay`
- Title tagline: `THEIR LIVES. YOUR ODDS.`

## Compatibility and migration

The runtime performs a copy-only migration from Godot's former
`app_userdata/Gamble Battle` directory into `app_userdata/Blood Will Pay`.
Existing files in the new directory are never overwritten, and the former
directory is never moved or deleted. Legacy serialization identifiers
`gamble_battle_account_profile` and `gamble_battle_active_run` remain unchanged
so existing profiles and active-run saves continue to load.

The former repository checkout and its linked worktrees are retained until
every dependent Codex task has been reconciled. New work should use the
canonical `blood-will-pay` clone; old paths remain valid only as legacy or
historical references.
