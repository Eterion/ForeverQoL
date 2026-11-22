-- Offline Lua 5.1 comparison; native API calls are counted stubs, not game timings.
local folder = assert(arg[1], 'addon source folder required')
local F = {}
collectgarbage('collect')
local startHeap = collectgarbage('count')
assert(loadfile(folder .. '/QuestItemData.lua'))('ForeverQoL', F)
collectgarbage('collect')
local dataHeap = collectgarbage('count') - startHeap
local calls = {quest = 0, title = 0, class = 0}
C_QuestLog = {
    IsQuestFlaggedCompleted = function() calls.quest = calls.quest + 1; return true end,
    IsOnQuest = function() calls.quest = calls.quest + 1; return false end,
    IsRepeatableQuest = function() calls.quest = calls.quest + 1; return false end,
    GetTitleForQuestID = function() calls.title = calls.title + 1; return 'A completed quest' end,
}
local info, native = {itemID = 182}, {}
C_Container = {GetContainerItemInfo = function() return info end, GetContainerItemQuestInfo = function() return native end}
C_Item = {GetItemInfoInstant = function() calls.class = calls.class + 1; return nil end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
assert(loadfile(folder .. '/QuestItems.lua'))('ForeverQoL', F)
local Q = F.QuestItems
Q.state = {removed = {}}
collectgarbage('collect')
collectgarbage('stop')
local before, started = collectgarbage('count'), os.clock()
for _ = 1, 20000 do assert(Q.GetStatus(0, 1)) end
local seconds, allocated = os.clock() - started, collectgarbage('count') - before
collectgarbage('restart')
collectgarbage('collect')
print(string.format('database retained: %.1f KiB; 20000 marker checks: %.4fs, %.1f KiB allocated; quest API calls: %d; title calls: %d; class calls: %d',
    dataHeap, seconds, allocated, calls.quest, calls.title, calls.class))
