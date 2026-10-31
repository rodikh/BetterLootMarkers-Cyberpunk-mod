# Changelog

## 1.4.1

Diagnostics and defensive-coding pass in response to reports of the mod silently
not working on Cyberpunk 2.5. No behavior changes if the game's API is unchanged;
if something has broken, the CET log will now name what broke instead of staying
silent.

- Added `Utils.Try`/`Utils.TryValue` helpers that wrap native game API calls in
  `pcall` and log (once per call site, via `spdlog` when available) if the call
  raises or the method is missing.
- Applied these helpers to every native call in the loot-marker pipeline
  (mappin/entity/item lookups, transaction system, RPGManager quality/iconic/
  broken checks) and to the scanner-state poll in `ImmersiveMode` and the
  `ScannerFix` hooks.
- Logged CET and game version at startup alongside the existing "Loaded vX.X.X"
  line, to make version mismatches visible in the log.
- Settings are now also saved on `onShutdown`, not only when the CET overlay
  closes.
- `init.lua` now returns the mod table so it can be inspected via
  `GetMod("BetterLootMarkers")` in the CET console.
- Packaging script (`pack-for-nexus.bat`) now prefers `7z`, then `tar.exe`,
  falling back to PowerShell `Compress-Archive` only if neither is available.
