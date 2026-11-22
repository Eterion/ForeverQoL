local _, F = ...
local W = { records = {} }
F.Windows = W
local positions, activeDrag, scanQueued, scanning, panelHooked, bagsHooked
local names = {
    'CharacterFrame', 'PlayerSpellsFrame', 'SpellBookFrame', 'WorldMapFrame',
    'QuestLogFrame', 'QuestFrame', 'GossipFrame', 'MerchantFrame', 'BankFrame',
    'MailFrame', 'OpenMailFrame', 'TradeFrame', 'AuctionHouseFrame', 'AuctionFrame',
    'ClassTrainerFrame', 'TrainerFrame', 'TradeSkillFrame', 'CraftFrame', 'ProfessionsFrame',
    'ProfessionsCustomerOrdersFrame', 'FriendsFrame', 'SocialUIFrame', 'GuildFrame',
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

local function Detach(record)
    local frame = record.frame
    if record.detached or not record.panel then return true end
    if not Allowed(frame) or Managed(frame) then return false end
    -- Preserve native metadata and show/hide functions. An empty area makes
    -- Forever's ShowUIPanel/HideUIPanel use their ordinary floating-frame path.
    if not frame:GetAttribute('UIPanelLayout-defined') then
        for key, value in pairs(record.panel) do frame:SetAttributeNoHandler('UIPanelLayout-' .. key, value) end
        frame:SetAttributeNoHandler('UIPanelLayout-defined', true)
    end
    frame:SetAttributeNoHandler('UIPanelLayout-area', nil)
    record.detached = true
    return true
end

local function Default(record)
    local frame, panel = record.frame, record.panel
    if panel then
        local scale = frame:GetScale()
        local top = GetUIPanelLayoutAttribute and GetUIPanelLayoutAttribute('TOP_OFFSET') or -116
        local left = GetUIPanelLayoutAttribute and GetUIPanelLayoutAttribute('LEFT_OFFSET') or 16
        local y = (panel.yoffset or 0) + top
        if ClampUIPanelY then y = ClampUIPanelY(frame, y, panel.minYOffset, panel.bottomClampOverride) end
        frame:ClearAllPoints()
        if panel.area == 'center' or panel.area == 'centerOrLeft' then
            frame:SetPoint('TOP', UIParent, 'TOP', panel.centerXOffset or 0, y / scale)
        else
            frame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', (left + (panel.xoffset or 0)) / scale, y / scale)
        end
    elseif #record.defaults > 0 then
        frame:ClearAllPoints()
        for _, point in ipairs(record.defaults) do frame:SetPoint(unpack(point)) end
    else
        frame:ClearAllPoints()
        frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
    end
    frame:SetUserPlaced(false)
end

function W.Apply(record)
    if not positions or record.applying or record.moving or not Allowed(record.frame) then return end
    Detach(record)
    local position = positions[record.name]
    if not position then return end
    if type(position) ~= 'table' or not Finite(position.x) or not Finite(position.y) then
        positions[record.name] = nil
        return
    end
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
    if not record or not record.moving then return end
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
    frame:Raise()
    frame:StartMoving()
end

function W.Reset(record)
    if not Allowed(record.frame) then return end
    W.Stop(record)
    positions[record.name] = nil
    record.applying = true
    if record.bag and UpdateContainerFrameAnchors then
        record.frame:SetUserPlaced(false)
        UpdateContainerFrameAnchors()
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
    Detach(record)
    if panel then
        local found
        for _, special in ipairs(UISpecialFrames) do if special == name then found = true; break end end
        if not found then UISpecialFrames[#UISpecialFrames + 1] = name end
    end
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
    handle:SetScript('OnMouseDown', function() if Allowed(frame) then frame:Raise() end end)
    handle:SetScript('OnClick', function(self, button) if button == 'RightButton' then Menu(record, self) end end)
    frame:HookScript('OnShow', function()
        if not Allowed(frame) then return end
        if not positions[name] and frame:GetNumPoints() == 0 then
            record.applying = true; Default(record); record.applying = nil
        end
        W.Apply(record)
    end)
    frame:HookScript('OnHide', function()
        W.Stop(record)
        if not record.detached then C_Timer.After(0, function() Detach(record) end) end
    end)
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
end
