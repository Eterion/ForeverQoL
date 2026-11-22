# Movable-window layer audit

After installing the development build, use `/reload`. Open Looking for Group's Who tab, drag its title, search, and check the results and search controls. Open another custom-positioned window, then close/reopen Who to check stacking. Reset Who and check its normal placement. Also check Character Skills/Reputation, bags, professions, map controls and collection lists.

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

The common failure was promoting a window root to HIGH while its explicit HIGH descendants retained low frame levels. Previously separate layers became peers, allowing background art to cover controls. Fixing only profession bars missed other examples of the same pattern.

## Shared handling

For a custom-positioned window, capture its descendant drawing order by native strata and frame level, then represent that order with compact frame levels in the shared HIGH window layer. Preserve equal native levels. Refresh discovery on raises so pooled rows are included; stop managing widgets reparented outside the window. Restore captured strata and levels on reset. Normal, unmoved windows are untouched. Dialog/menu/tooltip layers and forbidden subtrees are excluded.

There are no per-frame update handlers or whole-UI scans for stacking: a raise traverses only that window's descendants, and sorting is repeated only when membership changes. Native drawing metadata is retained only for custom-positioned windows until reset.

## Verification boundary

Automated cases cover Who's high-level title art, search controls and list inset; late pooled rows; reparented widgets; forbidden widgets; untouched dialogs/tooltips; primary/secondary/crafting profession bars; and mixed LOW/MEDIUM/HIGH ordering representative of the other source findings. Tests check repeated raises, restoration and reopening order. They use UI mocks and do not establish pixel rendering, hit testing, protected-frame behavior or third-party-addon compatibility in the game. Those still require the live checks above.
