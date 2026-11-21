# ForeverQoL

Small quality-of-life improvements for WoW Forever. The first module adds compact **Deposit** (down arrow) and **Withdraw** (up arrow) buttons plus an **Item types** dropdown immediately left of Blizzard's bank search box. Hover an arrow for its action tooltip. The addon uses Blizzard's button and dropdown templates and leaves the native bank size, artwork, search, item panel and other controls untouched.

Choose the item types to move, then click Deposit or Withdraw. No types are selected on a new installation. Selections are saved between sessions and shared by both buttons. Trade goods can be selected together or narrowed to cloth, leather, metal and stone, herbs, elemental materials, enchanting materials, and other trade goods through the submenu. The parent Trade goods checkbox selects or clears all its subtypes; unchecking a subtype excludes it.

Transfers apply to the selected character or account bank and use all its purchased storage, across pages. Deposit moves items from equipped bags; Withdraw moves items back into bags. Equipped gear is excluded. The existing bank search box filters the display only; it does not narrow transfers.

The filter summarizes a complete trade-goods selection as **Trade goods**, individual selections by name, and all types as **All item types**. Multiple selected groups use the first name and a count of additional groups.

The addon processes one stack at a time and reports the confirmed item count. During a transfer, the active arrow becomes a red **Stop transfer** square; the other action and filter are disabled. Clicking it, closing the bank, changing bank type, entering combat, or holding an item on the cursor stops the operation. A move that makes no progress stops after two seconds, including full storage and server restrictions. Locked items and items without type information are skipped. Refundable items are skipped when depositing to the account bank to preserve their refund window.

Use `/fql` or `/foreverqol` to see the loaded version. After installing a development build, `/reload` and check `/fql` for its exact identifier.

## Development

- `./tools/test.ps1` runs Lua regression tests, syntax checks, and TOC validation. Supply `-LuaPath` or `FOREVERQOL_LUA` if Lua is not on PATH. Locally the sibling QuestsStarts Lua runtime is also recognized.
- `./tools/deploy.ps1` installs and verifies a numbered development build in `C:\Games\World of Warcraft\_forever_\Interface\AddOns\ForeverQoL`. Use `-AddOnsPath` for another installation or a deploy rehearsal. The source TOC stays at the public version baseline.
- `./tools/package.ps1` validates and creates `dist/vVERSION/ForeverQoL-VERSION.zip` and `release.json` (Camelot flavor), without local build identifiers.
- Public releases require an explicit owner request and the manual **Release ForeverQoL** GitHub Actions workflow. The initial version baseline is `0.1.0`; no public release has been published.

## Client reference and validation

Bank API and layout reference: the [Forever client bank UI](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot) and [generated API documentation](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated).

Forever exposes `C_Bank.AutoDepositItemsIntoBank(bankType)` and `C_Bank.DoesBankTypeSupportAutoDeposit(bankType)`. The bulk deposit call has no per-call item filter or cancellation argument, so this module uses native `C_Container.UseContainerItem` calls to preserve its checkbox selection and stoppable queue. It does not change Blizzard's bank-tab deposit settings.

Offline tests cover filtering, deposit/withdraw routing, bag coverage, account-bank restrictions, cancellation, stale slots, failed moves, counts, and native widget/menu construction. In-game appearance, server permissions for timer-driven transfers, partial-stack behavior, account-bank restrictions and taint/combat interactions require live verification. Check both bank types, full inventory/bank, bank closure mid-transfer, reload persistence and `/fql` before the first release.
