local _, F = ...
local job, controls
local headerSpace = 44

function F.LayoutBankControls()
    if not controls then return end
    local panel = BankFrame.BankPanel
    -- Blizzard owns the body's height and recalculates it for each page. Add
    -- our header to that height, never to the already-expanded outer frame.
    panel:ClearAllPoints()
    panel:SetPoint('TOPLEFT', BankFrame, 'TOPLEFT', 0, -headerSpace)
    BankFrame:SetHeight(panel:GetHeight() + headerSpace)
    local search = BankFrame.BankItemSearchBox
    search:ClearAllPoints()
    search:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -56, -33)
    -- Keep the native background at its original body dimensions. Extending
    -- it over the extra header distorts the relationship between art and slots.
    if BankFrame.Background then
        BankFrame.Background:ClearAllPoints()
        BankFrame.Background:SetPoint('TOPLEFT', panel, 'TOPLEFT', 0, -20)
        BankFrame.Background:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', 0, 30)
    end
end

local function LayoutPageTabs()
    if not BankFrame.bankPageTabPool then return end
    for tab in BankFrame.bankPageTabPool:EnumerateActive() do
        local point, relativeTo, relativePoint, x = tab:GetPoint(1)
        if relativeTo == BankFrame and point == 'TOPLEFT' and relativePoint == 'TOPRIGHT' then
            tab:ClearAllPoints()
            tab:SetPoint(point, relativeTo, relativePoint, x, -60 - headerSpace)
        end
    end
end

local function ActiveBank()
    if not BankFrame or not BankFrame:IsShown() then return nil end
    return BankFrame:GetActiveBankType()
end

local function Available(bankType)
    return bankType ~= nil and ActiveBank() == bankType and C_Bank.CanUseBank(bankType)
        and not InCombatLockdown() and not CursorHasItem()
end

function F.RefreshControls()
    if not controls then return end
    local enabled = Available(ActiveBank()) and F.FilterCount() > 0
    for _, key in ipairs({ 'deposit', 'withdraw' }) do
        local button = controls[key]
        local stopping = job and job.deposit == (key == 'deposit')
        local canClick = stopping or (not job and enabled) or false
        button:SetEnabled(canClick)
        button:SetText(stopping and 'Stop transfer' or (key == 'deposit' and 'Deposit' or 'Withdraw'))
    end
    controls.filter:SetEnabled(not job)
    controls.filter:SetDefaultText(F.FilterSummary())
end

function F.StopTransfer(reason)
    if not job then return end
    local old = job
    job = nil
    F.RefreshControls()
    F.Print(string.format("%s: %d item(s) moved. %s", old.deposit and "Deposit" or "Withdraw", old.moved, reason or "Done."))
end

local function BagIDs()
    local ids = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do ids[#ids + 1] = bag end
    return ids
end

local function Eligible(bag, slot, info, deposit, bankType)
    if not info or info.isLocked or not info.itemID or not F.Matches(info.itemID) then return false end
    if deposit then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if not C_Bank.IsItemAllowedInBankType(bankType, location) then return false end
        -- Do not silently discard a vendor refund window through a bulk action.
        if bankType == Enum.BankType.Account and C_Item.CanBeRefunded(location) then return false end
    end
    return true
end

local function Step()
    local current = job
    if not current then return end
    if not Available(current.bankType) then F.StopTransfer("Stopped: bank changed, closed, or unavailable."); return end
    local pending = current.pending
    if pending then
        local info = C_Container.GetContainerItemInfo(pending.bag, pending.slot)
        if not info or info.itemID ~= pending.itemID or info.stackCount < pending.count then
            current.moved = current.moved + (info and info.itemID == pending.itemID and (pending.count - info.stackCount) or pending.count)
            current.pending = nil
            if info and info.itemID == pending.itemID and info.stackCount > 0 then
                F.StopTransfer("Stopped: only part of the stack moved; check free space."); return
            end
        elseif GetTime() - pending.started > 2 then
            F.StopTransfer("Stopped: item did not move; check free space and bank restrictions."); return
        else
            C_Timer.After(0.1, function() if job == current then Step() end end)
            return
        end
    end
    while current.index <= #current.queue do
        local entry = current.queue[current.index]
        current.index = current.index + 1
        local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
        -- Revalidate every slot: another bag action must never transfer a replacement item.
        if info and info.itemID == entry.itemID and Eligible(entry.bag, entry.slot, info, current.deposit, current.bankType) then
            current.pending = { bag = entry.bag, slot = entry.slot, itemID = info.itemID, count = info.stackCount, started = GetTime() }
            C_Container.UseContainerItem(entry.bag, entry.slot, nil, current.deposit and current.bankType or nil, false)
            C_Timer.After(0.15, function() if job == current then Step() end end)
            return
        end
    end
    F.StopTransfer("Done.")
end

function F.StartTransfer(deposit)
    local bankType = ActiveBank()
    if job or not Available(bankType) then return end
    if F.FilterCount() == 0 then F.Print("Choose item types first."); return end
    local ids = deposit and BagIDs() or C_Bank.FetchPurchasedBankTabIDs(bankType)
    local queue = {}
    for _, bag in ipairs(ids or {}) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if Eligible(bag, slot, info, deposit, bankType) then
                queue[#queue + 1] = { bag = bag, slot = slot, itemID = info.itemID }
            end
        end
    end
    if #queue == 0 then F.Print("No matching transferable items. Locked, uncached, restricted or refundable account-bank items are skipped."); return end
    job = { deposit = deposit, bankType = bankType, queue = queue, index = 1, moved = 0 }
    F.RefreshControls()
    Step()
end

local function Tooltip(button, text, deposit)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local stopping = job and job.deposit == deposit
        GameTooltip:SetText(stopping and 'Stop transfer' or (deposit and 'Deposit' or 'Withdraw'))
        GameTooltip:AddLine(stopping and 'Stop the current transfer. Items already moved stay in their destination.' or text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function F.AttachBankControls()
    if controls or not BankFrame or not BankFrame.BankPanel or not BankFrame.BankItemSearchBox or not F.filters then return end
    controls = {}
    local row = CreateFrame('Frame', nil, BankFrame, 'NineSlicePanelTemplate')
    row:SetHeight(38)
    row:SetPoint('TOPLEFT', BankFrame, 'TOPLEFT', 76, -26)
    row:SetPoint('TOPRIGHT', BankFrame, 'TOPRIGHT', -12, -26)
    NineSliceUtil.ApplyLayoutByName(row, 'InsetFrameTemplate')
    local background = row:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints()
    background:SetColorTexture(0.04, 0.035, 0.025, 0.95)
    controls.row = row
    local function Button(key, text, width, action)
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetText(text)
        button:SetScript("OnClick", action)
        controls[key] = button
        return button
    end
    local function Action(deposit)
        if job then
            if job.deposit == deposit then F.StopTransfer('Stopped.') end
        else
            F.StartTransfer(deposit)
        end
    end
    Tooltip(Button("deposit", "Deposit", 100, function() Action(true) end),
        "Deposit matching items from your bags into the selected bank. Uses all purchased storage in that bank.", true)
    Tooltip(Button("withdraw", "Withdraw", 100, function() Action(false) end),
        "Withdraw matching items from all purchased storage in the selected bank into your bags.", false)
    local filter = CreateFrame('DropdownButton', nil, row, 'WowStyle1DropdownTemplate')
    filter:SetHeight(22)
    controls.filter = filter
    controls.withdraw:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
    controls.deposit:SetPoint('RIGHT', controls.withdraw, 'LEFT', -4, 0)
    filter:SetPoint('LEFT', row, 'LEFT', 8, 0)
    filter:SetPoint('RIGHT', controls.deposit, 'LEFT', -8, 0)
    local function BuildMenu(_, root)
        root:CreateTitle("Transfer item types: " .. F.FilterSummary())
        local function SelectAll(value)
            for _, list in ipairs({ F.categories, F.tradeCategories }) do
                for _, category in ipairs(list) do
                    if category.key ~= 'tradegoods' then F.filters[category.key] = value end
                end
            end
            F.filters.tradegoods = nil
            F.RefreshControls()
        end
        root:CreateButton("Select all", function() SelectAll(true) end)
        root:CreateButton("Clear all", function() SelectAll(false) end)
        root:CreateDivider()
        local function Add(parent, category)
            local checkbox = parent:CreateCheckbox(category.label, function() return F.IsSelected(category) end,
                function() F.ToggleFilter(category); F.RefreshControls() end)
            checkbox:SetResponse(MenuResponse.Refresh)
            checkbox:SetSelectionIgnored()
            return checkbox
        end
        for _, category in ipairs(F.categories) do
            local checkbox = Add(root, category)
            if category.key == "tradegoods" then
                for _, trade in ipairs(F.tradeCategories) do Add(checkbox, trade) end
            end
        end
    end
    filter:SetupMenu(BuildMenu)
    BankFrame:HookScript("OnHide", function() F.StopTransfer("Bank closed.") end)
    BankFrame:HookScript("OnShow", function()
        F.LayoutBankControls()
        LayoutPageTabs()
        F.RefreshControls()
    end)
    hooksecurefunc(BankFrame.BankPanel, 'GenerateItemSlotsForSelectedTab', F.LayoutBankControls)
    hooksecurefunc(BankFrame, 'RefreshPageTabs', LayoutPageTabs)
    hooksecurefunc(BankFrame, "SetTab", function()
        if job then F.StopTransfer("Bank changed.") end
        F.LayoutBankControls()
        LayoutPageTabs()
        F.RefreshControls()
    end)
    F.LayoutBankControls()
    LayoutPageTabs()
    F.RefreshControls()
end
