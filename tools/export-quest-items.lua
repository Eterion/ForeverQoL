-- Run in the pinned QuestieDB checkout; see build-quest-items.ps1.
local mode, output, revision = assert(arg[1]), assert(arg[2]), assert(arg[3])
local function sorted(t)
    local keys = {}; for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys); return keys
end
local function serialize(value)
    if type(value) == 'string' then return string.format('%q', value):gsub('\r', '\\r'):gsub('\n', '\\n') end
    if type(value) ~= 'table' then return tostring(value) end
    local parts = {}
    for _, key in ipairs(sorted(value)) do parts[#parts + 1] = '[' .. serialize(key) .. ']=' .. serialize(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
local items, quests = {}, {}
local function link(itemID, questID)
    if type(itemID) ~= 'number' or itemID <= 0 or type(questID) ~= 'number' or questID <= 0 then return end
    items[itemID] = items[itemID] or { quests = {} }
    items[itemID].quests[questID] = true
end
if mode == 'profile' then
    local class, classID, faction = assert(arg[4]), tonumber(arg[5]), assert(arg[6])
    dofile('emulator/client.lua').install({ expansion = 'Forever', faction = faction,
        raceName = faction == 'Horde' and 'Undead' or 'Human', raceFile = faction == 'Horde' and 'Scourge' or 'Human',
        raceId = faction == 'Horde' and 5 or 1, classFile = class, classId = classID })
    local db = dofile('emulator/metadata.lua').loadAddon('QuestieDB.toc', 'QuestieDB')
    for _, id in ipairs(db.Quest.GetAllIds()) do
        local flags, special = db.Quest.questFlags(id) or 0, db.Quest.specialFlags(id) or 0
        quests[id] = {name = db.Quest.name(id) or ('Quest ' .. id), repeatable = special % 2 == 1
            or math.floor(flags / 4096) % 2 == 1 or math.floor(flags / 32768) % 2 == 1 or math.floor(flags / 65536) % 2 == 1}
        link(db.Quest.sourceItemId(id), id)
        for _, item in ipairs(db.Quest.requiredSourceItems(id) or {}) do link(item, id) end
        local starts, objectives = db.Quest.startedBy(id) or {}, db.Quest.objectives(id) or {}
        for _, item in ipairs(starts[3] or {}) do link(item, id) end
        for _, objective in ipairs(objectives[3] or {}) do link(objective[1], id) end
        for _, objective in ipairs(objectives[6] or {}) do link(objective[3], id) end
        for _, objective in ipairs(db.Quest.extraObjectives(id) or {}) do
            for _, reference in ipairs(objective[5] or {}) do
                if reference[1] == 'item' then link(reference[2], id) end
            end
        end
    end
    for _, id in ipairs(db.Item.GetAllIds()) do
        link(id, db.Item.startQuest(id))
        for _, quest in ipairs(db.Item.relatedQuests(id) or {}) do link(id, quest) end
        if items[id] then
            items[id].class = db.Item.class(id)
            items[id].teachesSpell = db.Item.teachesSpell(id) ~= nil and db.Item.teachesSpell(id) ~= 0 or nil
        end
    end
    local file = assert(io.open(output, 'wb'))
    file:write('return ', serialize({items = items, quests = quests}), '\n'); file:close()
else
    assert(mode == 'merge')
    for index = 4, #arg do
        local profile = dofile(arg[index])
        for id, item in pairs(profile.items) do
            items[id] = items[id] or {quests = {}}
            for quest in pairs(item.quests) do items[id].quests[quest] = true end
            items[id].class = items[id].class or item.class
            items[id].teachesSpell = items[id].teachesSpell or item.teachesSpell
        end
        for id, quest in pairs(profile.quests) do
            quests[id] = quests[id] or quest
            quests[id].repeatable = quests[id].repeatable or quest.repeatable
        end
    end
    local used, itemCount, questCount = {}, 0, 0
    for _, item in pairs(items) do
        item.quests = sorted(item.quests)
        for _, id in ipairs(item.quests) do used[id] = true end
        itemCount = itemCount + 1
    end
    local file = assert(io.open(output, 'wb'))
    file:write('-- Generated from QuestieDB ', revision, '; see THIRD_PARTY_NOTICES.md.\n-- Items: {class or false, teachesSpell, questID...}; quests: {name, repeatable}.\nlocal _, F = ...\nF.QuestItemData = {revision=', serialize(revision), ',items={\n')
    for _, id in ipairs(sorted(items)) do
        local item = items[id]
        local row = {item.class or false, item.teachesSpell or false}
        for _, quest in ipairs(item.quests) do row[#row + 1] = quest end
        local values = {}; for index, value in ipairs(row) do values[index] = serialize(value) end
        file:write('[', id, ']={', table.concat(values, ','), '},\n')
    end
    file:write('},quests={\n')
    for _, id in ipairs(sorted(used)) do
        if quests[id] then
            file:write('[', id, ']={', serialize(quests[id].name), ',', tostring(quests[id].repeatable), '},\n')
            questCount = questCount + 1
        end
    end
    file:write('}}\n'); file:close()
    print(string.format('Generated %d item associations and %d quest records.', itemCount, questCount))
end
