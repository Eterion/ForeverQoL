local _, F = ...
local Q = { turnedIn = {} }
F.QuestItems = Q
local scheduled, tooltipHooked, bagsHooked, questLogDirty
local itemCache, questCache = {}, {}

function Q.Invalidate()
    if next(itemCache) then itemCache = {} end
    if next(questCache) then questCache = {} end
end

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
    Q.Invalidate()
    Q.ScheduleRefresh(true)
end

function Q.ReadQuestLog()
    if not Q.state then return end
    local changed
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            if Q.state.removed[info.questID] then
                Q.state.removed[info.questID] = nil
                changed = true
            end
        end
    end
    if changed then Q.Invalidate() end
    -- Only explicit QUEST_REMOVED events record removal. A missing entry
    -- in a collapsed or temporarily incomplete quest log is not evidence.
end

local function QuestDisposition(id)
    if questCache[id] ~= nil then return questCache[id] end
    local quest = F.QuestItemData.quests[id]
    local result = 0 -- Unknown, repeatable, active, or a future use: keep item.
    if quest and not quest[2] and not C_QuestLog.IsRepeatableQuest(id) and not C_QuestLog.IsOnQuest(id) then
        if Completed(id) then result = 1
        elseif Q.state.removed[id] then result = 2 end
    end
    questCache[id] = result
    return result
end

function Q.GetStatus(bag, slot)
    if not Q.state or bag < 0 or bag > (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) then return nil end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local item = info and info.itemID and F.QuestItemData.items[info.itemID]
    if not item or item[2] or #item < 3 then return nil end
    local native = C_Container.GetContainerItemQuestInfo(bag, slot)
    -- The client may know an active use absent from our offline data.
    if native and native.isActive then return nil end
    local nativeID = native and native.questID or false
    local nativeQuestItem = native and native.isQuestItem == true or false
    local cached = itemCache[info.itemID]
    if cached and cached.nativeID == nativeID and cached.nativeQuestItem == nativeQuestItem then return cached.value or nil end
    local function Store(value)
        itemCache[info.itemID] = {nativeID = nativeID, nativeQuestItem = nativeQuestItem, value = value or false}
        return value
    end
    local _, _, _, _, _, class = C_Item.GetItemInfoInstant(info.itemID)
    if (class or item[1]) ~= 12 and not nativeQuestItem then return Store(nil) end
    local extraID, removed = nativeID or nil, false
    for index = 3, #item do
        local id = item[index]
        if id == extraID then extraID = nil end
        local disposition = QuestDisposition(id)
        if disposition == 0 then return Store(nil) end
        if disposition == 2 then removed = true end
    end
    if extraID then
        local disposition = QuestDisposition(extraID)
        if disposition == 0 then return Store(nil) end
        if disposition == 2 then removed = true end
    end
    return Store({ removed = removed, item = item, extraID = extraID,
        heading = removed and 'Quest item not currently needed' or 'No remaining known quest use',
        explanation = removed and 'Its unfinished related quests were removed from your quest log. This item may be needed again if you accept them.'
            or 'All known quests using this item have been turned in. Other non-quest uses may still exist.' })
end

function Q.GetDetails(status)
    if status.details then return status.details end
    local details = {}
    local function Add(id)
        if #details == 8 then return end
        local quest = F.QuestItemData.quests[id]
        local title = C_QuestLog.GetTitleForQuestID(id) or quest[1] or 'Related quest'
        details[#details + 1] = (QuestDisposition(id) == 1 and 'Completed: ' or 'Removed from log: ') .. title .. '.'
    end
    for index = 3, #status.item do Add(status.item[index]) end
    if status.extraID then Add(status.extraID) end
    status.details = details
    return details
end

function Q.AppendTooltip(tooltip, bag, slot)
    local status = Q.GetStatus(bag, slot)
    if not status then return end
    tooltip:AddLine(' ')
    tooltip:AddLine('ForeverQoL: ' .. status.heading, 1, status.removed and 0.75 or 0.35, 0.2, true)
    tooltip:AddLine(status.explanation, 1, 1, 1, true)
    for _, detail in ipairs(Q.GetDetails(status)) do
        tooltip:AddLine(detail, 0.85, 0.85, 0.85, true)
    end
    local count = #status.item - 2 + (status.extraID and 1 or 0)
    if count > 8 then tooltip:AddLine('Additional related quests: ' .. (count - 8), 0.8, 0.8, 0.8, true) end
    tooltip:Show()
end

function Q.UpdateButton(button)
    local status = Q.GetStatus(button:GetBagID(), button:GetID())
    local kind = status and (status.removed and 2 or 1) or 0
    if button.ForeverQoLQuestMarkerKind == kind then return end
    button.ForeverQoLQuestMarkerKind = kind
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

function Q.ScheduleRefresh(readQuestLog)
    if readQuestLog == true then questLogDirty = true end
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.15, function()
        scheduled = false
        if questLogDirty then
            questLogDirty = false
            Q.ReadQuestLog()
        end
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
    if event == 'ITEM_DATA_LOAD_RESULT' and not F.QuestItemData.items[first] then return end
    if event == 'QUEST_DATA_LOAD_RESULT' and not F.QuestItemData.quests[first] then return end
    if event == 'QUEST_TURNED_IN' then
        Q.turnedIn[first] = true
        Q.state.removed[first] = nil
    elseif event == 'QUEST_ACCEPTED' then
        Q.state.removed[first] = nil
    elseif event == 'QUEST_REMOVED' then
        if not second and not Completed(first) then Q.state.removed[first] = true end
    end
    Q.Invalidate()
    Q.ScheduleRefresh(event == 'PLAYER_LOGIN' or event == 'QUEST_LOG_UPDATE' or event == 'QUEST_ACCEPTED'
        or event == 'QUEST_REMOVED' or event == 'QUEST_TURNED_IN')
end

local events = CreateFrame('Frame')
for _, event in ipairs({'ADDON_LOADED', 'PLAYER_LOGIN', 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED',
    'QUEST_REMOVED', 'QUEST_TURNED_IN', 'QUEST_DATA_LOAD_RESULT', 'BAG_UPDATE_DELAYED', 'ITEM_DATA_LOAD_RESULT'}) do
    events:RegisterEvent(event)
end
events:SetScript('OnEvent', Q.OnEvent)
