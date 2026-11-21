local root = assert(arg[1])
local F, checks = {}, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function load(name) assert(loadfile(root .. '/addon/ForeverQoL/' .. name))('ForeverQoL', F) end
load('QuestItemData.lua')
local generated = F.QuestItemData
local itemCount, questCount, links, missing = 0, 0, 0, 0
for id, item in pairs(generated.items) do
    check(type(id) == 'number' and #item.quests > 0, 'generated item requires associations')
    local last = 0
    for _, quest in ipairs(item.quests) do
        check(quest > last, 'associations sorted and deduplicated')
        last = quest
        links = links + 1
        if not generated.quests[quest] then missing = missing + 1 end
    end
    itemCount = itemCount + 1
end
for id, quest in pairs(generated.quests) do
    check(type(id) == 'number' and type(quest.name) == 'string' and type(quest.repeatable) == 'boolean', 'generated quest schema')
    questCount = questCount + 1
end
check(itemCount > 3000 and questCount > 3000, 'Forever data coverage must not silently collapse')
check(generated.revision == 'aa1d7e7294596cf50a6fd0946dfae0d969cb9623', 'known source revision')
local completed, active, repeatable, log, timers, guid, info, native, hooks, marker, frameEvent
local function reset()
    completed, active, repeatable, log, timers, hooks = {}, {}, {}, {}, {}, {}
    guid, info, native = 'player-one', {itemID = 100}, {}
    ForeverQoLDB = {}
end
reset()
F.QuestItemData = {items = {
    [100] = {class = 12, quests = {1}},
    [101] = {class = 12, quests = {1,2}},
    [102] = {class = 12, quests = {3}},
    [103] = {class = 7, quests = {1}},
    [104] = {class = 12, quests = {999}},
    [105] = {class = 12, teachesSpell = true, quests = {1}},
    [106] = {class = 12, quests = {1,4}},
}, quests = {
    [1] = {name = 'One quest', repeatable = false},
    [2] = {name = 'Later quest', repeatable = false},
    [3] = {name = 'Repeat quest', repeatable = true},
    [4] = {name = 'Other quest', repeatable = false},
}}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return completed[id] or false end,
    IsOnQuest = function(id) return active[id] or false end,
    IsRepeatableQuest = function(id) return repeatable[id] or false end,
    GetTitleForQuestID = function(id) return id == 1 and 'Localized quest' or nil end,
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(index) return log[index] end,
}
C_Container = {
    GetContainerItemInfo = function() return info end,
    GetContainerItemQuestInfo = function() return native end,
}
C_Item = {GetItemInfoInstant = function() return nil end}
UnitGUID = function() return guid end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(_, _, fn) frameEvent = fn end }
end
local button = {
    GetBagID = function() return 0 end, GetID = function() return 1 end,
    CreateFontString = function()
        marker = {SetPoint = function() end, SetText = function(self, text) self.text = text end,
            SetTextColor = function() end, Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end}
        return marker
    end,
}
local bagFrame = {IsShown = function() return true end, EnumerateValidItems = function() return ipairs({button}) end}
ContainerFrameUtil_EnumerateContainerFrames = function() return ipairs({bagFrame}) end
ContainerFrame_GenerateFrame = function() end
local tooltip = {lines = {}, SetBagItem = function() end, AddLine = function(self, line) self.lines[#self.lines + 1] = line end,
    Show = function() end}
GameTooltip = tooltip
hooksecurefunc = function(owner, method, fn)
    if type(owner) == 'string' then hooks[owner] = method else hooks[method] = fn end
end
local function drain()
    while #timers > 0 do table.remove(timers, 1)() end
end
load('QuestItems.lua')
local Q = F.QuestItems
Q.Initialize()
drain()
check(Q.GetStatus(0, 1) == nil, 'unstarted or future quest is not obsolete')
completed[1] = true
local status = Q.GetStatus(0, 1)
check(status and not status.removed and status.details[1]:find('Localized quest %(#1%)'), 'completed use explains exact quest with localized title')
Q.RefreshButtons()
check(marker and marker.shown and marker.text == 'x', 'obsolete quest item gets bag marker')
check(type(hooks.UpdateQuestItem) == 'function' and type(hooks.SetBagItem) == 'function', 'hooks native item refresh and bag tooltip')
hooks.SetBagItem(tooltip, 0, 1)
check(table.concat(tooltip.lines, '\n'):find('All known quests') and table.concat(tooltip.lines, '\n'):find('Completed:'), 'tooltip explains evidence and limited scope')
active[1] = true
check(Q.GetStatus(0, 1) == nil, 'active use overrides completed history')
hooks.UpdateQuestItem(button)
check(not marker.shown, 'active quest clears marker on native refresh')
active[1] = nil
info.itemID = 101
check(Q.GetStatus(0, 1) == nil, 'shared item kept for unfinished followup')
completed[2] = true
check(Q.GetStatus(0, 1) ~= nil, 'shared item marked only when all known uses complete')
info.itemID = 102; completed[3] = true
check(Q.GetStatus(0, 1) == nil, 'source repeatable flag prevents obsolete marker')
info.itemID = 100; repeatable[1] = true
check(Q.GetStatus(0, 1) == nil, 'client repeatability protects item')
repeatable[1] = nil
info.itemID = 103
check(Q.GetStatus(0, 1) == nil, 'ordinary crafting material not treated as obsolete quest item')
info.itemID = 104
check(Q.GetStatus(0, 1) == nil, 'missing quest metadata stays uncertain')
info.itemID = 105
check(Q.GetStatus(0, 1) == nil, 'spell-learning item protected')
info.itemID = 100; native = {isActive = true}
check(Q.GetStatus(0, 1) == nil, 'client active use protects unknown relationships')
native = {isQuestItem = true}
check(Q.GetStatus(0, 1) ~= nil, 'generic quest-item flag is not mistaken for an active use')
native = {questID = 999}
check(Q.GetStatus(0, 1) == nil, 'extra native quest relation cannot be ignored')
native = {}
check(Q.GetStatus(6, 1) == nil and Q.GetStatus(-1, 1) == nil, 'only equipped bags receive markers')
info = nil
Q.UpdateButton(button)
check(not marker.shown, 'empty recycled slot clears marker')
info = {itemID = 9999}
check(Q.GetStatus(0, 1) == nil, 'unknown item never guessed obsolete')
info.itemID = 100; completed[1] = nil
Q.OnEvent(nil, 'QUEST_REMOVED', 1)
drain()
status = Q.GetStatus(0, 1)
check(status and status.removed and status.details[1]:find('Removed from log:'), 'explicit removal records removed quest with reason')
Q.RefreshButtons()
check(marker.text == '?' and marker.shown, 'removed use gets distinct uncertain marker')
Q.OnEvent(nil, 'QUEST_ACCEPTED', 1)
drain()
check(Q.GetStatus(0, 1) == nil, 'accepting again clears removed state')
log = {{questID = 1}}
Q.ReadQuestLog()
log = {}
Q.ReadQuestLog()
check(Q.GetStatus(0, 1) == nil, 'collapsed or incomplete log never proves abandonment')
Q.OnEvent(nil, 'QUEST_REMOVED', 1, true)
drain()
check(Q.GetStatus(0, 1) == nil, 'ending quest replay is not treated as abandonment')
Q.OnEvent(nil, 'QUEST_REMOVED', 1)
Q.OnEvent(nil, 'QUEST_TURNED_IN', 1)
drain()
check(Q.GetStatus(0, 1) and not Q.GetStatus(0, 1).removed, 'turn-in event resolves removal race before history refresh')
Q.turnedIn[1] = nil
Q.OnEvent(nil, 'QUEST_REMOVED', 1)
guid = 'player-two'; Q.Initialize(); drain()
check(Q.GetStatus(0, 1) == nil, 'abandonment state isolated per character')
guid = 'player-one'; Q.Initialize(); drain()
check(Q.GetStatus(0, 1).removed, 'abandonment survives character state reload')
info.itemID = 106
check(Q.GetStatus(0, 1) == nil, 'removed use cannot hide another future use')
local count = #timers
Q.ScheduleRefresh(); Q.ScheduleRefresh(); Q.ScheduleRefresh()
check(#timers == count + 1, 'event storms coalesce into one refresh')
drain()
check(type(frameEvent) == 'function', 'module registers event dispatcher')
print(string.format('Passed %d quest-item checks (%d generated items, %d quests, %d links, %d unresolved links kept conservative).', checks, itemCount, questCount, links, missing))
