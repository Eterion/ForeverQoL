local _, F = ...
local W = { records = {} }
F.Windows = W
local positions, activeDrag, scanQueued, scanning, panelHooked, bagsHooked, attributeHooked
local interactions = {
    BankFrame=true, MerchantFrame=true, MailFrame=true, OpenMailFrame=true,
    TradeFrame=true, QuestFrame=true, GossipFrame=true, ClassTrainerFrame=true,
    TrainerFrame=true, AuctionFrame=true, AuctionHouseFrame=true, PetStableFrame=true,
    StableFrame=true, VoidStorageFrame=true,
}
local names = {
    'CharacterFrame', 'PlayerSpellsFrame', 'SpellBookFrame', 'WorldMapFrame',
    'QuestLogFrame', 'QuestFrame', 'GossipFrame', 'MerchantFrame', 'BankFrame',
    'MailFrame', 'OpenMailFrame', 'TradeFrame', 'AuctionHouseFrame', 'AuctionFrame',
    'ClassTrainerFrame', 'TrainerFrame', 'TradeSkillFrame', 'CraftFrame', 'ProfessionsFrame', 'ProfessionsBookFrame',
    'ProfessionsCustomerOrdersFrame', 'LFGParentFrame', 'FriendsFrame', 'SocialUIFrame', 'GuildFrame',
    'CommunitiesFrame', 'InspectFrame', 'DressUpFrame', 'CollectionsJournal', 'EncounterJournal',
    'AchievementFrame', 'ItemTextFrame', 'ItemSocketingFrame', 'ItemUpgradeFrame',
    'CalendarFrame', 'SettingsPanel', 'GameMenuFrame', 'AddonList', 'HelpFrame',
    'PetStableFrame', 'StableFrame', 'VoidStorageFrame', 'ContainerFrameCombinedBags',
}

local function Allowed(frame)
    return not InCombatLockdown() and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsMaximized and frame:IsMaximized())
end

local function Finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function Scale(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function CapturePoints(frame)
    local points = {}
    for index = 1, frame:GetNumPoints() do points[index] = {frame:GetPoint(index)} end
    return points
end

local function Managed(frame)
    if not GetUIPanel then return false end
    for _, slot in ipairs({'left', 'center', 'right', 'doublewide', 'fullscreen'}) do
        if GetUIPanel(slot) == frame then return true end
    end
    return false
end

local function ReleasePanel(record)
    local frame, scripts = record.frame, {}
    -- The public panel API removes the secure slot by hiding the frame.
    -- Preserve its live interaction during this synchronous hide/show: native
    -- OnHide handlers otherwise close banks, trade skills, merchants, etc.
    local function Collect(widget)
        if widget.IsForbidden and widget:IsForbidden() then return false end
        for _, event in ipairs({'OnHide', 'OnShow'}) do
            local handler = widget:GetScript(event)
            if handler then scripts[#scripts + 1] = {frame=widget, event=event, handler=handler} end
        end
        for _, child in ipairs({widget:GetChildren()}) do if not Collect(child) then return false end end
        return true
    end
    if not Collect(frame) then return false end
    record.detaching = true
    local ok, message = pcall(function()
        for _, script in ipairs(scripts) do script.frame:SetScript(script.event, nil) end
        HideUIPanel(frame)
        if not Managed(frame) then frame:SetAttributeNoHandler('UIPanelLayout-area', nil) end
    end)
    -- No rendered frame elapses while the window is hidden. Show it while its
    -- lifecycle handlers are still suspended, then restore every handler.
    local shown, showMessage = pcall(function()
        if not frame:IsShown() then ShowUIPanel(frame) end
        if not frame:IsShown() then frame:Show() end
    end)
    for _, script in ipairs(scripts) do script.frame:SetScript(script.event, script.handler) end
    record.detaching = nil
    if not ok or not shown then F.Print('Could not release window layout: ' .. tostring(message or showMessage)) end
    return ok and shown and frame:IsShown() and not Managed(frame)
end

local function Detach(record, releaseLive)
    local frame = record.frame
    if not record.panel then return true end
    if record.detached then
        -- Native mode changes can update the area while combat defers us.
        if Allowed(frame) then frame:SetAttributeNoHandler('UIPanelLayout-area', nil) end
        return true
    end
    if not Allowed(frame) then return false end
    -- Preserve native metadata and show/hide functions. An empty area makes
    -- Forever's ShowUIPanel/HideUIPanel use their ordinary floating-frame path.
    if not frame:GetAttribute('UIPanelLayout-defined') then
        for key, value in pairs(record.panel) do frame:SetAttributeNoHandler('UIPanelLayout-' .. key, value) end
        frame:SetAttributeNoHandler('UIPanelLayout-defined', true)
    end
    record.nativeArea = frame:GetAttribute('UIPanelLayout-area') or record.nativeArea or record.panel.area
    if Managed(frame) and (not releaseLive or not ReleasePanel(record)) then return false end
    frame:SetAttributeNoHandler('UIPanelLayout-area', nil)
    record.detached = true
    local found
    for _, special in ipairs(UISpecialFrames) do if special == record.name then found = true; break end end
    if not found then UISpecialFrames[#UISpecialFrames + 1] = record.name; record.escapeAdded = true end
    return true
end

local function Default(record)
    local frame = record.frame
    if #record.defaults > 0 then
        frame:ClearAllPoints()
        for _, point in ipairs(record.defaults) do frame:SetPoint(unpack(point)) end
    else
        frame:ClearAllPoints()
        frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end
    frame:SetUserPlaced(false)
end

-- Keep Blizzard's drawing hierarchy intact, as BlizzMove does. Rewriting
-- descendant strata/levels breaks native lists, masks and progress bars.
local function RaiseWindow(record)
    record.frame:Raise()
end
local function RestoreNative(record)
    if record.detached then
        record.frame:SetAttributeNoHandler('UIPanelLayout-area', record.nativeArea or record.panel.area)
        record.detached = nil
    end
    if record.escapeAdded then
        for index = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[index] == record.name then table.remove(UISpecialFrames, index) end
        end
        record.escapeAdded = nil
    end
end

function W.Front(record)
    if not positions[record.name] or not Allowed(record.frame) or not record.frame:IsShown() then return end
    RaiseWindow(record)
end

function W.Apply(record)
    if not positions or record.applying or record.moving or record.detaching or not Allowed(record.frame) then return end
    local position = positions[record.name]
    if not position then return end
    if type(position) ~= 'table' or not Finite(position.x) or not Finite(position.y) then
        positions[record.name] = nil
        RestoreNative(record)
        return
    end
    Detach(record)
    local frame, width, height = record.frame, UIParent:GetWidth(), UIParent:GetHeight()
    local scale = Scale(frame)
    if width <= 0 or height <= 0 or scale <= 0 then return end
    local x = math.max(0, math.min(position.x * width, math.max(0, width - frame:GetWidth() * scale)))
    local y = math.min(height, math.max(math.min(height, frame:GetHeight() * scale), position.y * height))
    record.applying = true
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x / scale, y / scale)
    frame:SetUserPlaced(false)
    record.applying = nil
end

function W.Stop(record)
    if not record or not record.moving or record.detaching then return end
    local frame = record.frame
    if InCombatLockdown() and frame:IsProtected() then record.pendingStop = true; return end
    frame:StopMovingOrSizing()
    record.moving, record.pendingStop, activeDrag = nil, nil, nil
    local left, top = frame:GetLeft(), frame:GetTop()
    local width, height, scale = UIParent:GetWidth(), UIParent:GetHeight(), Scale(frame)
    if left and top and width > 0 and height > 0 then
        positions[record.name] = {x = left * scale / width, y = top * scale / height}
    end
    frame:SetUserPlaced(false) -- SavedVariables own persistence, not layout-cache.txt.
    if positions[record.name] then Detach(record, true) end
    W.Apply(record)
end

function W.Start(record)
    if not Allowed(record.frame) then
        F.Print('Windows can be moved outside combat and in windowed mode.')
        return
    end
    if activeDrag then W.Stop(activeDrag) end
    local frame = record.frame
    record.moving, activeDrag = true, record
    RaiseWindow(record)
    frame:StartMoving()
end

function W.Reset(record)
    if not Allowed(record.frame) then return end
    W.Stop(record)
    positions[record.name] = nil
    record.applying = true
    RestoreNative(record)
    if record.bag and UpdateContainerFrameAnchors then
        record.frame:SetUserPlaced(false)
        UpdateContainerFrameAnchors()
    elseif record.panel then
        record.frame:SetUserPlaced(false)
        if Managed(record.frame) then
            UpdateUIPanelPositions(record.frame)
        elseif record.frame:IsShown() then
            -- Re-enter the real panel manager so its current width, area,
            -- minimize offsets, and other open panels determine placement.
            HideUIPanel(record.frame, true)
            -- NPC windows own a server interaction; do not resurrect a closed
            -- bank/merchant/etc. Reopening the interaction uses native layout.
            if not interactions[record.name] then ShowUIPanel(record.frame) end
        end
    else
        Default(record)
    end
    record.applying = nil
end

local function Menu(record, owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle('Window position')
        local reset = root:CreateButton('Reset to default', function() W.Reset(record) end)
        reset:SetEnabled(Allowed(record.frame))
    end)
end

function W.Attach(frame, explicit)
    if not positions or not frame or not frame.GetName or not frame.HookScript then return end
    local name = frame:GetName()
    if not name or W.records[name] or (frame.IsForbidden and frame:IsForbidden()) then return end
    local panel = UIPanelWindows and UIPanelWindows[name]
    if panel and (panel.area == 'full' or panel.area == 'fullscreen') then return end
    local title = frame.TitleContainer
    if not explicit and not panel then
        local root = frame:GetParent() == UIParent or frame:IsToplevel()
        if not root or not (title or frame.TitleText or frame.titleText) or frame:GetWidth() < 150 or frame:GetHeight() < 80 then return end
    end
    if InCombatLockdown() then return end -- Retry registration after combat.
    local record = {name = name, frame = frame, defaults = CapturePoints(frame), panel = panel,
        bag = name:match('^ContainerFrame') ~= nil}
    W.records[name] = record
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    local handle = CreateFrame('Button', nil, frame)
    record.handle = handle
    -- Only cover the title text. Leave portraits and close/maximize buttons free.
    if title then
        handle:SetPoint('TOPLEFT', title, 'TOPLEFT', 0, 0)
        handle:SetPoint('TOPRIGHT', title, 'TOPRIGHT', -44, 0)
        handle:SetHeight(20)
        handle:SetFrameLevel(title:GetFrameLevel() + 1)
    else
        handle:SetPoint('TOPLEFT', frame, 'TOPLEFT', 54, -2)
        handle:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -64, -2)
        handle:SetHeight(24)
        handle:SetFrameLevel(math.max(frame:GetFrameLevel() + 1, frame.NineSlice and frame.NineSlice:GetFrameLevel() + 1 or 1))
    end
    handle:RegisterForDrag('LeftButton')
    handle:RegisterForClicks('RightButtonUp')
    handle:SetScript('OnDragStart', function() W.Start(record) end)
    handle:SetScript('OnDragStop', function() W.Stop(record) end)
    handle:SetScript('OnMouseDown', function()
        if Allowed(frame) then
            if positions[name] then RaiseWindow(record) else frame:Raise() end
        end
    end)
    handle:SetScript('OnClick', function(self, button) if button == 'RightButton' then Menu(record, self) end end)
    frame:HookScript('OnShow', function()
        if record.detaching or not Allowed(frame) then return end
        if not positions[name] and not record.panel and frame:GetNumPoints() == 0 then
            record.applying = true; Default(record); record.applying = nil
        end
        W.Apply(record)
        W.Front(record)
    end)
    frame:HookScript('OnHide', function()
        if record.detaching then return end
        W.Stop(record)
        if positions[name] and not record.detached then C_Timer.After(0, function()
            if positions[name] then Detach(record) end
        end) end
    end)
    frame:HookScript('OnSizeChanged', function() W.Apply(record) end)
    hooksecurefunc(frame, 'SetPoint', function() if not record.bag then W.Apply(record) end end)
    W.Apply(record)
end

function W.Scan(generic)
    if not positions or InCombatLockdown() or scanning then return end
    scanning = true
    for _, name in ipairs(names) do W.Attach(_G[name], true) end
    for index = 1, NUM_CONTAINER_FRAMES or 6 do W.Attach(_G['ContainerFrame' .. index], true) end
    for name in pairs(UIPanelWindows or {}) do W.Attach(_G[name], true) end
    if generic and EnumerateFrames then
        local frame = EnumerateFrames()
        while frame do W.Attach(frame); frame = EnumerateFrames(frame) end
    end
    scanning = nil
end

function W.QueueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0.1, function() scanQueued = nil; W.Scan(true) end)
end

function W.Initialize()
    if type(ForeverQoLDB.windowPositions) ~= 'table' then ForeverQoLDB.windowPositions = {} end
    positions = ForeverQoLDB.windowPositions
    W.InstallHooks()
    W.Scan(true)
end

local events = CreateFrame('Frame')
for _, event in ipairs({'ADDON_LOADED', 'PLAYER_LOGIN', 'PLAYER_REGEN_DISABLED',
    'PLAYER_REGEN_ENABLED', 'DISPLAY_SIZE_CHANGED', 'UI_SCALE_CHANGED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event)
    if not positions then return end
    if event == 'ADDON_LOADED' then W.InstallHooks(); W.Scan(); W.QueueScan()
    elseif event == 'PLAYER_LOGIN' then W.Scan(true)
    elseif event == 'PLAYER_REGEN_DISABLED' then W.Stop(activeDrag)
    elseif event == 'PLAYER_REGEN_ENABLED' then
        W.Stop(activeDrag)
        W.Scan(true)
        for _, record in pairs(W.records) do W.Apply(record) end
    else
        for _, record in pairs(W.records) do W.Apply(record) end
    end
end)

-- Detect additional panels shown outside load-on-demand addons, and restore bag
-- positions after the entire native bag-layout pass rather than mid-anchor chain.
function W.InstallHooks()
    if not panelHooked and ShowUIPanel then
        panelHooked = true
        hooksecurefunc('ShowUIPanel', function(frame)
            W.Attach(frame, true)
            if frame and W.records[frame:GetName()] then W.Apply(W.records[frame:GetName()]) end
        end)
    end
    if not bagsHooked and UpdateContainerFrameAnchors then
        bagsHooked = true
        hooksecurefunc('UpdateContainerFrameAnchors', function()
            for _, record in pairs(W.records) do if record.bag then W.Apply(record) end end
        end)
    end
    if not attributeHooked and SetUIPanelAttribute then
        attributeHooked = true
        hooksecurefunc('SetUIPanelAttribute', function(frame, key, value)
            local record = frame and W.records[frame:GetName()]
            if record and key == 'area' and value ~= nil then
                record.nativeArea = value
                if record.detached and positions[record.name] and Allowed(frame) then
                    frame:SetAttributeNoHandler('UIPanelLayout-area', nil)
                end
            end
        end)
    end
end
