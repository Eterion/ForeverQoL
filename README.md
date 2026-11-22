# ForeverQoL

Small quality-of-life improvements for WoW Forever. A row inside the bank, beneath its title and above search, contains the visible **item-type dropdown**, **Deposit**, and **Withdraw**, in that order. The row has no added border or background. Search and contents move down together; the bank gains header space while its original body and background retain their dimensions. The dropdown and text buttons use Blizzard's native templates.

Choose the item types to move, then click Deposit or Withdraw. No types are selected on a new installation. Selections are saved between sessions and shared by both buttons. Trade goods can be selected together or narrowed to cloth, leather, metal and stone, herbs, elemental materials, enchanting materials, and other trade goods through the submenu. The parent Trade goods checkbox selects or clears all its subtypes; unchecking a subtype excludes it.

Transfers apply to the selected character or account bank and use all its purchased storage, across pages. Deposit moves items from equipped bags; Withdraw moves items back into bags. Equipped gear is excluded. The existing bank search box filters the display only; it does not narrow transfers.

The dropdown always displays the selection: a complete trade-goods selection reads **Trade goods**, individual selections use their names, and all types read **All item types**. Multiple selected groups use the first name and a count of additional groups.

The addon processes one stack at a time and reports the confirmed item count. During a transfer, the active Deposit or Withdraw button reads **Stop transfer**; the other action and filter are disabled. Clicking it, closing the bank, changing bank type, entering combat, or holding an item on the cursor stops the operation. A move that makes no progress stops after two seconds, including full storage and server restrictions. Locked items and items without type information are skipped. Refundable items are skipped when depositing to the account bank to preserve their refund window.

Use `/fql` or `/foreverqol` to see the loaded version. After installing a development build, `/reload` and check `/fql` for its exact identifier.

## Leftover quest items

Bag items receive a textured badge in their upper-left corner, similar in size and placement to Blizzard's equipment-upgrade marker, when they have no remaining known quest use:

- A **red cross** means all known related quests have been turned in.
- An **amber warning triangle** means their unfinished related quests were removed from the log, for example by abandonment. They can be needed again if those quests are accepted again.

Hover the item for an explanation and the related quest names, without IDs. Markers update when quests or bags change and disappear when an item becomes relevant again. Both Blizzard's combined and individual bag views are supported. Custom bag replacements are not currently supported.

The addon bundles 3,616 item associations covering 3,534 quest records from the pinned Forever QuestieDB data, unioned across all nine supported classes and both factions. QuestieDB and QuestsStarts do not need to be installed. The marker is conservative: active quests, repeatable quests, unfinished future/shared uses, missing quest metadata and unknown items prevent an obsolete marker. Ordinary crafting materials and spell-learning items are excluded. Five unresolved source quest links are retained as blockers rather than discarded.

Completed uses can be recognized immediately after installation. Quest removal is recorded only from events observed while this addon is running, and saved separately for each character; absence from the quest log alone is not evidence. The tooltip describes known quest relevance, not a guarantee that an item has no other purpose. The addon never sells or deletes these items.

## Development

- `./tools/test.ps1` runs Lua regression tests, syntax checks, and TOC validation. Supply `-LuaPath` or `FOREVERQOL_LUA` if Lua is not on PATH. Locally the sibling QuestsStarts Lua runtime is also recognized.
- `./tools/deploy.ps1` installs and verifies a numbered development build in `C:\Games\World of Warcraft\_forever_\Interface\AddOns\ForeverQoL`. Use `-AddOnsPath` for another installation or a deploy rehearsal. The source TOC stays at the public version baseline.
- `./tools/package.ps1` validates and creates `dist/vVERSION/ForeverQoL-VERSION.zip` and `release.json` (Camelot flavor), without local build identifiers.
- `./tools/build-quest-items.ps1 -Upstream PATH` rebuilds quest-item data from the clean revision in `tools/upstream-revision.txt`. Locally the QuestsStarts `work/QuestieDB` checkout can be used. Release CI fetches the pin into this project's `work/QuestieDB`, rebuilds all 18 profiles and rejects generated differences. Source licensing and provenance ship in the addon.
- Public releases require an explicit owner request and the manual **Release ForeverQoL** GitHub Actions workflow. The first public version is `0.1.0`; development deployments do not consume version numbers.

## Client reference and validation

Bank API and layout reference: the [Forever client bank UI](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot) and [generated API documentation](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated).

Forever exposes `C_Bank.AutoDepositItemsIntoBank(bankType)` and `C_Bank.DoesBankTypeSupportAutoDeposit(bankType)`. The bulk deposit call has no per-call item filter or cancellation argument, so this module uses native `C_Container.UseContainerItem` calls to preserve its checkbox selection and stoppable queue. It does not change Blizzard's bank-tab deposit settings.

Offline tests cover filtering, deposit/withdraw routing, bag coverage, account-bank restrictions, cancellation, stale slots, failed moves, counts, and native widget/menu construction. In-game appearance, server permissions for timer-driven transfers, partial-stack behavior, account-bank restrictions and taint/combat interactions require live verification. Check both bank types, full inventory/bank, bank closure mid-transfer, reload persistence and `/fql` before the first release.

Quest-item tests cover generated-data integrity, completion and abandonment reasons, shared/future/repeatable uses, native active-use safeguards, missing data, recycled slots, tooltip output, character separation and event races. Live verification remains necessary for marker positioning, tooltip integration, turn-in/abandon/reaccept refreshes and client quest-history behavior.

## Performance checks

Quest-item data uses compact array records without dropping relationships. Status and quest-state results are shared within an event epoch; bag/quest changes, relevant data loads and character initialization invalidate them. Detailed quest names are formatted only for tooltips. Bag-only refreshes do not rescan the quest log, unrelated item loads do not trigger bag refreshes, and unchanged badges avoid repeated texture updates. Closed banks skip control refresh work.

Run `lua tools/benchmark.lua addon/ForeverQoL` for an offline Lua 5.1 comparison. Against v0.1.0, retained quest-data memory fell from approximately 1,938 to 1,229 KiB (37%). In 20,000 repeated unchanged-item evaluations, internal temporary allocations fell from approximately 9,531 to 1 KiB, and quest-state calls from 60,000 to 3. The benchmark stubs native APIs; these are data/lookup measurements, not in-game frame-rate or total addon-memory measurements.
