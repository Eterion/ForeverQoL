local root = assert(arg[1], "repository path required")
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local F = {}
local now, timers, messages, uses, bags, active, open, combat, cursor, allowed, refundable, blocked
local function reset()
    now, timers, messages, uses, bags = 0, {}, {}, {}, {}
    active, open, combat, cursor, allowed, refundable, blocked = 0, true, false, false, true, false, false
    ForeverQoLDB = nil
    F.InitializeDB()
end
local types = { [100] = {7, 9}, [101] = {0, 1}, [102] = {4, 1}, [103] = {1, 0}, [104] = {7, 5} }
C_Item = {
    GetItemInfoInstant = function(id)
        local t = types[id]
        if t then return id, nil, nil, nil, nil, t[1], t[2] end
    end,
    CanBeRefunded = function() return refundable end,
}
local function item(id, count, locked) return { itemID = id, stackCount = count or 1, isLocked = locked } end
BankFrame = { IsShown = function() return open end, GetActiveBankType = function() return active end }
C_Bank = {
    CanUseBank = function() return allowed end,
    IsItemAllowedInBankType = function() return allowed end,
    FetchPurchasedBankTabIDs = function(bankType) return bankType == 0 and {6,7} or {12} end,
}
Enum = { BankType = { Character = 0, Account = 2 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return {bagID = bag, slotIndex = slot} end }
InCombatLockdown = function() return combat end
CursorHasItem = function() return cursor end
GetTime = function() return now end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { time = now + delay, fn = fn } end }
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] or nil end,
    UseContainerItem = function(bag, slot, unit, bankType, reagent)
        uses[#uses + 1] = { bag = bag, slot = slot, bankType = bankType, reagent = reagent }
        if not blocked then bags[bag][slot] = nil end
    end,
}
local function drain()
    local budget = 1000
    while #timers > 0 do
        budget = budget - 1
        assert(budget > 0, "timer runaway")
        local timer = table.remove(timers, 1)
        now = timer.time
        timer.fn()
    end
end
assert(loadfile(root .. '/addon/ForeverQoL/Filters.lua'))('ForeverQoL', F)
assert(loadfile(root .. '/addon/ForeverQoL/Bank.lua'))('ForeverQoL', F)
F.Print = function(message) messages[#messages + 1] = message end

reset()
check(F.FilterCount() == 0 and not F.Matches(100), 'new install requires selection')
F.filters.tradegoods = true
check(F.Matches(100) and F.Matches(104) and not F.Matches(101), 'trade goods class filter')
F.filters.tradegoods = false
F.filters['trade:9'] = true
check(F.Matches(100) and not F.Matches(104), 'material subtype filter')
F.filters.other = true
check(F.Matches(103) and not F.Matches(999), 'other known types; unknown metadata is skipped')
F.InitializeDB()
check(F.filters['trade:9'], 'selection survives database initialization')
ForeverQoLDB = { bankFilters = 'invalid' }
F.InitializeDB()
check(F.FilterCount() == 0, 'invalid saved data recovered')

reset()
F.filters.tradegoods = true
bags[0] = {item(100, 20), item(101), item(104, 10, true)}
bags[5] = {item(104, 3)}
F.StartTransfer(true)
check(#uses == 1, 'one stack at a time')
F.StartTransfer(true)
check(#uses == 1, 'double click cannot start concurrent job')
drain()
check(#uses == 2 and uses[2].bag == 5, 'includes all equipped bag slots; excludes locked and unselected')
check(uses[1].bankType == 0 and uses[1].reagent == false, 'explicit selected character bank')
check(messages[#messages]:find('23 item%(s%)'), 'reports confirmed item count')

reset()
F.filters.tradegoods = true
bags[6], bags[7], bags[12] = {item(100, 2)}, {item(104, 3)}, {item(100, 4)}
F.StartTransfer(false)
drain()
check(#uses == 2 and uses[1].bag == 6 and uses[2].bag == 7, 'withdraw all purchased character storage only')
check(uses[1].bankType == nil, 'withdraw uses native bank-item right-click behavior')

reset()
active = 2
F.filters.tradegoods = true
bags[0] = {item(100)}
refundable = true
F.StartTransfer(true)
check(#uses == 0, 'account deposit preserves vendor refund window')
refundable = false
F.StartTransfer(true)
drain()
check(#uses == 1 and uses[1].bankType == 2, 'account deposit bank type')
bags[12] = {item(104)}
F.StartTransfer(false)
drain()
check(#uses == 2 and uses[2].bag == 12, 'account withdrawal scans account storage')

for _, reason in ipairs({'close', 'switch', 'combat', 'cursor', 'access'}) do
    reset()
    F.filters.tradegoods = true
    bags[0] = {item(100), item(104)}
    F.StartTransfer(true)
    if reason == 'close' then open = false
    elseif reason == 'switch' then active = 2
    elseif reason == 'combat' then combat = true
    elseif reason == 'cursor' then cursor = true
    else allowed = false end
    drain()
    check(#uses == 1, 'stop on ' .. reason)
end

reset()
F.filters.tradegoods = true
bags[0] = {item(100), item(104)}
blocked = true
F.StartTransfer(true)
drain()
check(#uses == 1 and messages[#messages]:find('did not move'), 'full or restricted destination stops on timeout')
check(messages[#messages]:find('0 item%(s%)'), 'failed movement never counted')

reset()
F.filters.tradegoods = true
bags[0] = {item(100, 20), item(104)}
local normalUse = C_Container.UseContainerItem
C_Container.UseContainerItem = function(bag, slot)
    uses[#uses + 1] = {bag = bag, slot = slot}
    bags[bag][slot].stackCount = 15
end
F.StartTransfer(true)
drain()
check(#uses == 1 and messages[#messages]:find('5 item%(s%)') and messages[#messages]:find('part of the stack'), 'partial move counts only moved items and stops')
C_Container.UseContainerItem = normalUse

reset()
F.filters.tradegoods = true
bags[0] = {item(100), item(104)}
F.StartTransfer(true)
bags[0][2] = item(101)
drain()
check(#uses == 1, 'changed source slot is revalidated')

reset()
F.filters.tradegoods = true
bags[0] = {item(100), item(104)}
F.StartTransfer(true)
F.StopTransfer('Stopped.')
drain()
check(#uses == 1, 'cancel invalidates pending timer')
bags[0] = {item(104)}
F.StartTransfer(true)
drain()
check(#uses == 2, 'new job after cancellation')

reset()
bags[0] = {item(100)}
F.StartTransfer(true)
check(#uses == 0, 'empty selection cannot transfer')
F.filters.tradegoods = true
open = false
F.StartTransfer(true)
check(#uses == 0, 'never uses inventory items outside bank')

-- Exercise real UI construction and menu callbacks with minimal Blizzard widget mocks.
local buttons, hooks, eventFrame, menuBuilder = {}, {}, nil, nil
local widgets, filterWidget = {}, nil
local function widget(kind, template)
    local w = {kind = kind, template = template, scripts = {}}
    widgets[#widgets + 1] = w
    function w:SetSize(width, height) self.width, self.height = width, height end
    function w:GetHeight() return self.height end
    function w:SetHeight(height) self.height = height end
    function w:ClearAllPoints() self.point = nil end
    function w:SetPoint(...) self.point = {...} end
    function w:SetText(text) self.text = text; buttons[text] = self end
    function w:SetScript(event, fn) self.scripts[event] = fn end
    function w:SetEnabled(value) self.enabled = value end
    function w:SetShown(value) self.shown = value end
    function w:RegisterEvent() end
    if kind == 'Frame' then eventFrame = w end
    return w
end
CreateFrame = function(kind, _, _, template) return widget(kind, template) end
BankFrame.BankPanel = widget('Frame')
BankFrame.BankPanel:SetSize(480, 460)
BankFrame.BankPanel:SetPoint('LEFT', BankFrame, 'LEFT', 0, 0)
BankFrame.BankItemSearchBox = widget('EditBox')
BankFrame.BankItemSearchBox:SetSize(110, 20)
BankFrame.BankItemSearchBox:SetPoint('TOPRIGHT', BankFrame, 'TOPRIGHT', -56, -33)
BankFrame.height = 460
local function forbiddenMutation() error('addon attempted to move or resize native Blizzard UI') end
for _, native in ipairs({BankFrame, BankFrame.BankPanel, BankFrame.BankItemSearchBox}) do
    for _, method in ipairs({'SetHeight', 'SetWidth', 'SetSize', 'SetPoint', 'ClearAllPoints'}) do
        native[method] = forbiddenMutation
    end
end
BankFrame.HookScript = function(_, event, fn) hooks[event] = fn end
hooksecurefunc = function(_, name, fn) hooks[name] = fn end
MenuResponse = {Refresh = 1}
local entries = {}
local menu = {}
function menu:CreateTitle(text) self.title = text end
function menu:CreateDivider() end
function menu:CreateButton(label, fn) entries[label] = {click = fn} end
function menu:CreateCheckbox(label, selected, click)
    local entry = {selected = selected, click = click, CreateCheckbox = menu.CreateCheckbox}
    function entry:SetResponse() end
    function entry:SetSelectionIgnored() end
    entries[label] = entry
    return entry
end
MenuUtil = {CreateContextMenu = function(owner, builder)
    menuBuilder = builder
    builder(owner, menu)
end}
reset()
F.AttachBankControls()
local depositButton, withdrawButton = buttons.Deposit, buttons.Withdraw
filterWidget = buttons.Filter
check(depositButton.template == 'UIPanelButtonTemplate' and withdrawButton.template == 'UIPanelButtonTemplate', 'native button templates')
check(#widgets == 5 and filterWidget.template == 'UIPanelButtonTemplate', 'three native text buttons; no standalone stop widget')
check(BankFrame.height == 460 and BankFrame.BankPanel.point[1] == 'LEFT', 'bank and item panel retain native size and anchors')
check(BankFrame.BankItemSearchBox.point[4] == -56 and BankFrame.BankItemSearchBox.point[5] == -33, 'search retains native anchor')
check(withdrawButton.point[2] == BankFrame.BankItemSearchBox and withdrawButton.point[4] == -8, 'withdraw anchors left of search without moving it')
check(filterWidget.point[2] == depositButton and depositButton.point[2] == withdrawButton, 'left-to-right order is Filter, Deposit, Withdraw')
local totalWidth = depositButton.width + withdrawButton.width + filterWidget.width + 4 + 4 + 8
check(480 - 56 - 110 - totalWidth >= 78, 'compact controls clear portrait at smallest native bank width')
check(33 + filterWidget.height < 63, 'controls fit above native item grid')
BankFrame.BankPanel.height = 695
BankFrame.height = 695
hooks.OnShow()
hooks.SetTab()
check(BankFrame.height == 695 and BankFrame.BankPanel.height == 695, 'page and tab refresh leave native geometry untouched')
check(hooks.GenerateItemSlotsForSelectedTab == nil, 'no native item layout hook')
check(not depositButton.enabled, 'no selection disables transfer buttons')
filterWidget.scripts.OnClick(filterWidget)
check(menuBuilder ~= nil and menu.title == 'Transfer item types: Item types', 'Filter button opens native checkbox menu with selection summary')
entries.Herbs.click()
check(entries.Herbs.selected() and depositButton.enabled, 'checkbox updates saved filter and controls')
check(F.FilterSummary() == 'Herbs', 'single subtype uses its name')
entries['Select all'].click()
check(F.FilterCount() == #F.categories + #F.tradeCategories - 1, 'select all')
check(F.FilterSummary() == 'All item types', 'full selection uses compact summary')
entries.Herbs.click()
check(not F.Matches(100) and F.Matches(104) and not entries['Trade goods'].selected(), 'unchecking subtype after select all excludes it')
entries['Trade goods'].click()
check(F.Matches(100) and entries['Trade goods'].selected(), 'parent checkbox selects all subtypes')
entries['Clear all'].click()
check(F.FilterCount() == 0 and not withdrawButton.enabled, 'clear all')
entries['Trade goods'].click()
check(F.FilterSummary() == 'Trade goods', 'all trade subtypes summarize as trade goods')
filterWidget.scripts.OnClick(filterWidget)
check(menu.title == 'Transfer item types: Trade goods' and filterWidget.text == 'Filter', 'selection appears inside menu while button retains fixed label')
entries.Consumables.click()
check(F.FilterSummary() == 'Consumables +1', 'multiple groups collapse trade subtypes into one group')
entries['Clear all'].click()
check(F.FilterSummary() == 'Item types', 'empty selection restores prompt')
F.filters.tradegoods = true
bags[0] = {item(100), item(104)}
depositButton.scripts.OnClick()
check(depositButton.text == 'Stop transfer' and depositButton.enabled and not withdrawButton.enabled, 'deposit becomes enabled stop; opposite action disabled')
check(not filterWidget.enabled, 'filter disabled during transfer')
depositButton.scripts.OnClick()
drain()
check(#uses == 1 and depositButton.text == 'Deposit' and withdrawButton.enabled, 'deposit button cancels and restores idle controls')
bags[6] = {item(100), item(104)}
withdrawButton.scripts.OnClick()
check(withdrawButton.text == 'Stop transfer' and withdrawButton.enabled and not depositButton.enabled, 'withdraw becomes enabled stop')
withdrawButton.scripts.OnClick()
drain()
check(#uses == 2 and withdrawButton.text == 'Withdraw' and depositButton.enabled, 'withdraw button cancels and restores idle controls')
bags[0] = {item(100), item(104)}
depositButton.scripts.OnClick()
hooks.OnHide()
drain()
check(#uses == 3, 'bank hide hook cancels queue')

C_AddOns = {GetAddOnMetadata = function() return '0.1.0' end}
SlashCmdList = {}
assert(loadfile(root .. '/addon/ForeverQoL/Core.lua'))('ForeverQoL', F)
check(F.version == '0.1.0' and type(SlashCmdList.FOREVERQOL) == 'function', 'public version and slash command')
check(type(eventFrame.scripts.OnEvent) == 'function', 'event dispatcher loads')
print(string.format('Passed %d ForeverQoL regression checks.', checks))
