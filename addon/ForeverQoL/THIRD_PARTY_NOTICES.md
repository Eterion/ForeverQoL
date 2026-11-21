# Quest-item relationship data

`QuestItemData.lua` is generated from Questie/QuestieDB revision
`aa1d7e7294596cf50a6fd0946dfae0d969cb9623`, using the Forever composed data for
all nine supported classes and both factions. It includes quest starters,
provided and required items, item and spell objectives, extra item references,
and item-related quest records. Associations are unioned across profiles;
repeatability is preserved if any profile reports it.

Source: https://github.com/Questie/QuestieDB/tree/aa1d7e7294596cf50a6fd0946dfae0d969cb9623

The data retains the upstream Questie/QuestieDB licensing terms, including the
historical licensing qualifications in `Licenses/QuestieDB-LICENSE.md`.
Upstream provenance and GPLv3 text are included in `Licenses/`.
Reproducible exporter and build instructions are in this repository under
`tools/export-quest-items.lua` and `tools/build-quest-items.ps1`.

QuestieDB is a community-maintained reference, not proof of complete Forever
coverage. The marker reports known quest uses, never a guarantee that an item
can be discarded or has no non-quest use. This addon does not sell or delete it.
