# Development

- `./tools/test.ps1` runs Lua regression tests, syntax checks, and TOC validation. Supply `-LuaPath` or `FOREVERQOL_LUA` if Lua is not on PATH. Locally the sibling QuestsStarts Lua runtime is also recognized.
- `./tools/deploy.ps1` installs and verifies a numbered development build in `C:\Games\World of Warcraft\_forever_\Interface\AddOns\ForeverQoL`. Use `-AddOnsPath` for another installation or a deploy rehearsal. The source TOC stays at the public version baseline.
- `./tools/package.ps1` validates and creates `dist/vVERSION/ForeverQoL-VERSION.zip` and `release.json` (Camelot flavor), without local build identifiers.
- `./tools/build-quest-items.ps1 -Upstream PATH` rebuilds quest-item data from the clean revision in `tools/upstream-revision.txt`. Locally the QuestsStarts `work/QuestieDB` checkout can be used. Release CI fetches the pin into this project's `work/QuestieDB`, rebuilds all 18 profiles and rejects generated differences. Source licensing and provenance ship in the addon.
- Public releases require an explicit owner request and the manual **Release ForeverQoL** GitHub Actions workflow. Development deployments do not consume public version numbers.

## Client reference and validation

Bank API and layout reference: the [Forever client bank UI](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot) and [generated API documentation](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated).

Forever exposes `C_Bank.AutoDepositItemsIntoBank(bankType)` and `C_Bank.DoesBankTypeSupportAutoDeposit(bankType)`. The bulk deposit call has no per-call item filter or cancellation argument, so this module uses native `C_Container.UseContainerItem` calls to preserve its checkbox selection and stoppable queue. It does not change Blizzard's bank-tab deposit settings.

Offline tests cover filtering, deposit/withdraw routing, bag coverage, account-bank restrictions, cancellation, stale slots, failed moves, counts, and native widget/menu construction. In-game appearance, server permissions for timer-driven transfers, partial-stack behavior, account-bank restrictions and taint/combat interactions require live verification. Check both bank types, full inventory/bank, bank closure mid-transfer, reload persistence and `/fql` before the first release.

Quest-item tests cover generated-data integrity, completion and abandonment reasons, shared/future/repeatable uses, native active-use safeguards, missing data, recycled slots, tooltip output, character separation and event races. Live verification remains necessary for marker positioning, tooltip integration, turn-in/abandon/reaccept refreshes and client quest-history behavior.

Movable-window tests cover saved positions/reset, compact/expanded spellbook layout, unchanged native lifecycle scripts and panel attributes, native profession-bar layers, bag anchors, clamping and combat-deferred operations. Fixtures reject protected UI mutations and generic frame enumeration, and verify that action bars and system menus are excluded. Live testing remains necessary for taint propagation, protected-panel behavior, NPC interactions and windows controlled by other movers. `/fql errors` is a diagnostic, not an automated proof of in-game safety.

## Performance checks

Quest-item data uses compact array records without dropping relationships. Status and quest-state results are shared within an event epoch; bag/quest changes, relevant data loads and character initialization invalidate them. Detailed quest names are formatted only for tooltips. Bag-only refreshes do not rescan the quest log, unrelated item loads do not trigger bag refreshes, and unchanged badges avoid repeated texture updates. Closed banks skip control refresh work.

Run `lua tools/benchmark.lua addon/ForeverQoL` for an offline Lua 5.1 comparison. Against v0.1.0, retained quest-data memory fell from approximately 1,938 to 1,229 KiB (37%). In 20,000 repeated unchanged-item evaluations, internal temporary allocations fell from approximately 9,531 to 1 KiB, and quest-state calls from 60,000 to 3. The benchmark stubs native APIs; these are data/lookup measurements, not in-game frame-rate or total addon-memory measurements.
