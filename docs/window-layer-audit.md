# Movable-window layer audit

After installing the development build, use `/reload`. Open professions at its default position, check the progress bars, then drag it and check the bars again. Switch professions and return to the overview; close/reopen and reset the window. Open Looking for Group's Who tab, drag its title, search, and check the results and search controls. Also check Character Skills/Reputation, bags, map controls and collection lists. Native strata retain priority when windows overlap.

## Source findings

Inspected the public [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns) on 2026-11-22. These are source findings, not reports of live in-game failures for every window. Camelot files take precedence where the package selects them; shared/Mainline files are also used by this client.

| Window family | Separate native layers found |
| --- | --- |
| Looking for Group | `WhoList.xml`: HIGH search edit box and search button; parent-frame XML: HIGH eye portrait. The Who tab is a child of `LFGParentFrame`. |
| Character | Camelot Skills/Reputation XML: HIGH lists, scrollbars and paragon icons; PaperDoll/Character XML: HIGH level info and side panes. |
| Bags and map | ContainerFrame XML: HIGH count container. WorldMapFrameTemplates XML: HIGH bounty, activity and action controls. |
| Professions | Camelot profession-book templates and crafting XML: HIGH rank bars over pages with explicit frame levels. |
| Achievements and collections | HIGH lists/scrollbars in AchievementUI and Collections templates. |
| Encounter Journal | HIGH lore scrolling controls and loot containers. |
| Friends and calendar | HIGH broadcast and calendar detail/scrolling controls. |
| Spellbook/talents, auctions and trainer | HIGH help/talent overlays, auction favorites and trainer controls. |

Promoting a window root to HIGH collapses the distinction between its background and explicit HIGH controls. The owner confirmed that profession bars worked at the default position but disappeared on dragging in dev.14. The shared descendant-layer remapping was not reliable in game, despite passing mocks, and has been removed along with forced root-strata changes.

## Native layering and BlizzMove comparison

Reviewed the current [BlizzMove movement code](https://github.com/Kiatra/BlizzMove/blob/master/BlizzMove.lua) and [profession frame registration](https://github.com/Kiatra/BlizzMove/blob/master/Frames.lua) on 2026-11-22. Normal movement does not rewrite window/descendant strata or levels. Its debug capture overlay and its own move handles set their own layers; those are separate from moving the original window. Profession registration contains no rank-bar layering workaround. This is source evidence, not proof that BlizzMove never has rendering bugs in any client.

ForeverQoL now leaves the native drawing hierarchy in place too. Reopening or dragging calls native `Raise()` on the window. There is no descendant scan, cache, sort or rewrite for stacking. The addon's transparent title handle still sets its own level. Position persistence, floating panel layout and native reset are unchanged.

Native `Raise()` operates within a strata, so a higher-strata window can remain above a lower-strata window opened later. Strict last-opened ordering across different native strata is not supported by this implementation. That earlier requirement remains a limitation rather than being simulated by rewriting child layers.

## Verification boundary

Automated cases cover default-to-dragged profession bars, rank text/dropdowns, reopening, native page-level changes, crafting and standalone bars, Who search/list layers, late pooled rows, forbidden widgets, dialogs/tooltips, and mixed LOW/MEDIUM/HIGH ordering. The frame mock propagates parent frame-level changes to children in the same strata. Assertions check native drawing priority and that the mover never writes native strata. Tests do not establish pixel rendering, hit testing, protected-frame behavior or third-party-addon compatibility in the game. Those still require the live checks above.
