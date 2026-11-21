local _, F = ...
local Q = { turnedIn = {} }
F.QuestItems = Q
local scheduled, tooltipHooked, bagsHooked

local function Completed(id)
    return Q.turnedIn[id] == true or C_QuestLog.IsQuestFlaggedCompleted(id) == true
end

function Q.Initialize()
    if not ForeverQoLDB then return end
    local guid = UnitGUID('player')
    if not guid then return end
    if type(ForeverQoLDB.questItems) ~= 'table' then ForeverQoLDB.questItems = {} end
    local characters = ForeverQoLDB.questItems
    if type(characters[guid]) ~= 'table' then characters[guid] = {} end
    Q.state = characters[guid]
    if type(Q.state.removed) ~= 'table' then Q.state.removed = {} end
    Q.InstallHooks()
    Q.ScheduleRefresh()
end

function Q.ReadQuestLog()
    if not Q.state then return end
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            Q.state.removed[info.questID] = nil
        end
    end
    -- Only explicit QUEST_REMOVED events record removal. A missing entry
    -- in a collapsed or temporarily incomplete quest log is not evidence.
end

function Q.GetStatus(bag, slot)
    if not Q.state or bag < 0 or bag > (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) then return nil end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local item = info and info.itemID and F.QuestItemData.items[info.itemID]
    if not item or item.teachesSpell or #item.quests == 0 then return nil end
    local native = C_Container.GetContainerItemQuestInfo(bag, slot)
    -- The client may know an active use absent from our offline data.
    if native and native.isActive then return nil end
    local _, _, _, _, _, class = C_Item.GetItemInfoInstant(info.itemID)
    if (class or item.class) ~= 12 and not (native and native.isQuestItem) then return nil end
    local ids, seen = {}, {}
    for _, id in ipairs(item.quests) do ids[#ids + 1] = id; seen[id] = true end
    if native and native.questID and not seen[native.questID] then ids[#ids + 1] = native.questID end
    local details, removed = {}, false
    for _, id in ipairs(ids) do
        local quest = F.QuestItemData.quests[id]
        if not quest or quest.repeatable or C_QuestLog.IsRepeatableQuest(id)
            or C_QuestLog.IsOnQuest(id) then return nil end
        local done = Completed(id)
        if not done and not Q.state.removed[id] then return nil end
        local title = C_QuestLog.GetTitleForQuestID(id) or quest.name or 'Related quest'
        details[#details + 1] = (done and 'Completed: ' or 'Removed from log: ') .. title .. '.'
        if not done then removed = true end
    end
    return { removed = removed, details = details,
        heading = removed and 'Quest item not currently needed' or 'No remaining known quest use',
        explanation = removed and 'Its unfinished related quests were removed from your quest log. This item may be needed again if you accept them.'
            or 'All known quests using this item have been turned in. Other non-quest uses may still exist.' }
end

function Q.AppendTooltip(tooltip, bag, slot)
    local status = Q.GetStatus(bag, slot)
    if not status then return end
    tooltip:AddLine(' ')
    tooltip:AddLine('ForeverQoL: ' .. status.heading, 1, status.removed and 0.75 or 0.35, 0.2, true)
    tooltip:AddLine(status.explanation, 1, 1, 1, true)
    for index, detail in ipairs(status.details) do
        if index > 8 then tooltip:AddLine('Additional related quests: ' .. (#status.details - 8), 0.8, 0.8, 0.8, true); break end
        tooltip:AddLine(detail, 0.85, 0.85, 0.85, true)
    end
    tooltip:Show()
end

function Q.UpdateButton(button)
    local status = Q.GetStatus(button:GetBagID(), button:GetID())
    if status and not button.ForeverQoLQuestMarker then
        -- Match the upgrade badge's corner-overlay treatment, using different
        -- Blizzard artwork instead of font glyphs or the green upgrade arrow.
        local marker = button:CreateTexture(nil, 'OVERLAY', nil, 7)
        marker:SetSize(20, 20)
        marker:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
        button.ForeverQoLQuestMarker = marker
    end
    local marker = button.ForeverQoLQuestMarker
    if marker then
        if status then
            local atlas = status.removed and 'services-icon-warning' or 'common-icon-redx'
            if C_Texture.GetAtlasInfo(atlas) then
                marker:SetAtlas(atlas)
            else
                marker:SetTexture(status.removed and 'Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew'
                    or 'Interface\\Buttons\\UI-GroupLoot-Pass-Up')
            end
            marker:Show()
        else
            marker:Hide()
        end
    end
end

function Q.RefreshButtons()
    if not Q.state or not ContainerFrameUtil_EnumerateContainerFrames then return end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if frame:IsShown() and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do
                if not button.ForeverQoLQuestHooked then
                    button.ForeverQoLQuestHooked = true
                    hooksecurefunc(button, 'UpdateQuestItem', Q.UpdateButton)
                end
                Q.UpdateButton(button)
            end
        end
    end
end

function Q.ScheduleRefresh()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.15, function()
        scheduled = false
        Q.ReadQuestLog()
        Q.RefreshButtons()
    end)
end

function Q.InstallHooks()
    if not tooltipHooked and GameTooltip and GameTooltip.SetBagItem then
        tooltipHooked = true
        hooksecurefunc(GameTooltip, 'SetBagItem', Q.AppendTooltip)
    end
    if not bagsHooked and ContainerFrame_GenerateFrame then
        bagsHooked = true
        hooksecurefunc('ContainerFrame_GenerateFrame', Q.ScheduleRefresh)
    end
end

function Q.OnEvent(_, event, first, second)
    if event == 'ADDON_LOADED' then Q.InstallHooks(); return end
    if event == 'PLAYER_LOGIN' then Q.Initialize() end
    if not Q.state then return end
    if event == 'QUEST_TURNED_IN' then
        Q.turnedIn[first] = true
        Q.state.removed[first] = nil
    elseif event == 'QUEST_ACCEPTED' then
        Q.state.removed[first] = nil
    elseif event == 'QUEST_REMOVED' then
        if not second and not Completed(first) then Q.state.removed[first] = true end
    end
    Q.ScheduleRefresh()
end

local events = CreateFrame('Frame')
for _, event in ipairs({'ADDON_LOADED', 'PLAYER_LOGIN', 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED',
    'QUEST_REMOVED', 'QUEST_TURNED_IN', 'BAG_UPDATE_DELAYED', 'ITEM_DATA_LOAD_RESULT'}) do
    events:RegisterEvent(event)
end
events:SetScript('OnEvent', Q.OnEvent)
