# Window movement safety audit

After installing the correction, use `/reload` to start a clean UI session. Open and move professions, Character and bags, then enter and leave combat. Check that action bars remain visible and usable. Run `/fql errors` afterwards. A zero count is evidence for that session, not proof that every taint path has been eliminated.

## Current boundaries

The mover applies saved coordinates to an explicit list of ordinary Blizzard windows and bags. It uses secure post-hooks and its own transparent title handles. It does not replace Blizzard lifecycle scripts, write native panel attributes, rewrite child drawing layers, scan arbitrary UI frames, or move action bars, unit frames or system menus. All movement/layout operations are deferred or refused during combat. Bank body/tab layout and initial bank-control creation also have combat guards.

Blizzard owns panel occupancy and visibility. Opening another panel can reserve space, rearrange other panels or close a moved window. Immediate release of a moved window's native slot and independent panel overlap are not provided. Reopening calls native Raise(), which retains Blizzard strata priority. Reset clears the saved position and delegates to native layout without synthesizing hide/show events.

## Investigation findings

The owner reported blocked interface actions attributed to ForeverQoL and intermittently disappearing action bars after dev.16. The first-drag handoff replaced native OnHide/OnShow handlers, including descendant handlers, around a synthetic hide/show. Restoring the same function reference does not prove that its secure execution state is restored. The handoff was removed. Native UIPanelLayout attribute edits and broad generic-frame discovery were also removed to reduce the potential taint surface.

The script replacement is a credible taint source. No exact blocked-function trace was available locally, so the cause of the disappearing action bars is not established. The AddOns list tracks a count of blocked actions; the reported 100 is not a specific error code. `/fql errors` now records the count and exact last blocked/forbidden function attributed to ForeverQoL since reload, without modifying protected UI or retrying actions.

Reviewed [BlizzMove's movement source](https://github.com/Kiatra/BlizzMove/blob/master/BlizzMove.lua): ordinary movement leaves native drawing layers and lifecycle handlers alone. Its own move handles and debug overlay have their own scripts/levels. ForeverQoL's earlier layer remapping and synthetic lifecycle suppression went beyond that model.

The [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns) contains explicit HIGH overlays in Who search, professions rank bars, Character Skills/Reputation, bag counts, map controls, collections and achievements. Moving those controls into their background's strata can obscure them, so the mover leaves all those native drawing layers untouched.

## Verification boundary

Regression fixtures reject addon writes to Blizzard-owned lifecycle scripts and panel attributes, fail on generic UI enumeration, and verify that protected action bars/system menus are not attached even if they resemble titled panels. Cases cover saved position/reset, compact/expanded spellbook, native lifecycle cleanup, progress-bar strata, fresh-session persistence, bag anchoring, clamping and combat-deferred operations. Bank tests cover the combat layout guard. Diagnostics tests cover count/function output and ignoring other addons.

These are offline structural and behavior checks. They do not emulate the client's taint propagation, secure execution, rendering or combat state machine. Live reproduction after a clean reload is still required. Previous passing mock tests were insufficient evidence of in-game safety.
