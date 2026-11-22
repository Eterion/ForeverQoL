local root = assert(arg[1])
local checks, combat, timers, eventHandler, allFrames = 0, false, {}, nil, {}
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.001 end
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function drain() while #timers > 0 do table.remove(timers, 1)() end end
local function frame(name, parent, width, height)
    local f = {name=name, parent=parent, width=width or 400, height=height or 400,
        points={}, attrs={}, scripts={}, level=10, scale=1, shown=false, left=16, top=900, protected=false}
    allFrames[#allFrames + 1] = f
    local function mutate(self) assert(not combat or not self.protected, 'protected mutation during combat') end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(level) self.level=level end
    function f:SetHeight(value) self.height=value end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(index) return unpack(self.points[index or 1]) end
    function f:ClearAllPoints() mutate(self); self.points={} end
    function f:SetPoint(...)
        mutate(self)
        local p={...}; self.points[#self.points + 1]=p
        if p[1]=='TOPLEFT' and p[2]==UIParent and p[3]=='BOTTOMLEFT' then self.left, self.top=p[4],p[5] end
    end
    function f:IsForbidden() return self.forbidden or false end
    function f:IsProtected() return self.protected end
    function f:IsToplevel() return self.parent==UIParent end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:SetMovable(value) mutate(self); self.movable=value end
    function f:SetClampedToScreen(value) mutate(self); self.clamped=value end
    function f:SetUserPlaced(value) mutate(self); self.userPlaced=value end
    function f:SetDontSavePosition(value) mutate(self); self.dontSave=value end
    function f:StartMoving() mutate(self); self.dragging=true end
    function f:StopMovingOrSizing() mutate(self); self.dragging=false; self.stops=(self.stops or 0)+1 end
    function f:Raise() mutate(self); self.raised=(self.raised or 0)+1 end
    function f:GetAttribute(key) return self.attrs[key] end
    function f:SetAttributeNoHandler(key, value) mutate(self); self.attrs[key]=value end
    function f:RegisterForDrag(...) self.dragButtons={...} end
    function f:RegisterForClicks(...) self.clickButtons={...} end
    function f:RegisterEvent() end
    function f:SetScript(event, callback) self.scripts[event]=callback; if event=='OnEvent' then eventHandler=callback end end
    function f:HookScript(event, callback)
        local old=self.scripts[event]
        self.scripts[event]=function(...) if old then old(...) end; callback(...) end
    end
    return f
end
UIParent=frame('UIParent',nil,1920,1080)
UIParent.top=1080
CreateFrame=function(_, name, parent) return frame(name,parent) end
EnumerateFrames=function(previous)
    if not previous then return allFrames[1] end
    for index, f in ipairs(allFrames) do if f==previous then return allFrames[index+1] end end
end
local slots={}
UIPanelWindows={CharacterFrame={area='left',xoffset=5},MerchantFrame={area='left'},BankFrame={area='left'}}
UISpecialFrames={}
GetUIPanel=function(slot) return slots[slot] end
GetUIPanelLayoutAttribute=function(key) return key=='TOP_OFFSET' and -100 or 16 end
ClampUIPanelY=function(_,y) return y end
ShowUIPanel=function(f)
    local area=f.attrs['UIPanelLayout-defined'] and f.attrs['UIPanelLayout-area'] or nil
    if not f.attrs['UIPanelLayout-defined'] then area=UIPanelWindows[f.name] and UIPanelWindows[f.name].area end
    if area then
        if slots[area] then slots[area]:Hide() end
        slots[area]=f
    end
    f:Show()
end
local bagLayouts=0
UpdateContainerFrameAnchors=function()
    bagLayouts=bagLayouts+1
    if ContainerFrame1 then ContainerFrame1:ClearAllPoints(); ContainerFrame1:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-20,80) end
end
local globalHookCounts={}
hooksecurefunc=function(owner, method, callback)
    if type(owner)=='string' then
        local name, post=owner,method
        globalHookCounts[name]=(globalHookCounts[name] or 0)+1
        local original=_G[name]
        _G[name]=function(...) local result=original(...); post(...); return result end
    else
        local original=owner[method]
        owner[method]=function(...) local result=original(...); callback(...); return result end
    end
end
local menu={}
function menu:CreateTitle(text) self.title=text end
function menu:CreateButton(text,callback)
    self.label,self.callback=text,callback
    return {SetEnabled=function(_,value) menu.enabled=value end}
end
MenuUtil={CreateContextMenu=function(owner,builder) menu.owner=owner; builder(owner,menu) end}
CharacterFrame=frame('CharacterFrame',UIParent)
CharacterFrame.TitleContainer=frame(nil,CharacterFrame,320,20)
CharacterFrame.TitleContainer.level=510
MerchantFrame=frame('MerchantFrame',UIParent)
BankFrame=frame('BankFrame',UIParent,480,504)
BankFrame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',16,-100)
ForeverQoLDB={}
local F={Print=function() end}
assert(loadfile(root..'/addon/ForeverQoL/Windows.lua'))('ForeverQoL',F)
local W=F.Windows
W.InstallHooks(); W.Initialize()
local character, merchant, bank=W.records.CharacterFrame,W.records.MerchantFrame,W.records.BankFrame
check(character and merchant and bank, 'registers ordinary Blizzard windows')
check(character.handle.parent==CharacterFrame and character.handle.height==20 and character.handle.level==511, 'transparent title-only handle above native title')
check(character.handle.points[2][4]==-44, 'title handle leaves close and maximize controls unobstructed')
check(character.handle.dragButtons[1]=='LeftButton', 'drag uses ordinary left button without modifiers')
check(CharacterFrame.attrs['UIPanelLayout-area']==nil and CharacterFrame.attrs['UIPanelLayout-defined'], 'detaches native panel arrangement')
check(UIPanelWindows.CharacterFrame.area=='left' and CharacterFrame.attrs['UIPanelLayout-xoffset']==5, 'preserves native metadata without changing registry')
check(#UISpecialFrames==3, 'floating panels retain Escape closing registration')
ShowUIPanel(CharacterFrame); ShowUIPanel(MerchantFrame); ShowUIPanel(BankFrame)
check(CharacterFrame.shown and MerchantFrame.shown and BankFrame.shown, 'opening panels permits overlap instead of hiding previous panels')
check(CharacterFrame.points[1][4]==21 and CharacterFrame.points[1][5]==-100, 'unanchored panel gets native default offsets')
character.handle.scripts.OnDragStart()
check(CharacterFrame.dragging and character.moving and CharacterFrame.raised>0, 'title drag starts movement and raises window')
CharacterFrame.left,CharacterFrame.top=600,800
character.handle.scripts.OnDragStop()
local saved=ForeverQoLDB.windowPositions.CharacterFrame
check(near(saved.x,600/1920) and near(saved.y,800/1080), 'saved position contains normalized screen coordinates')
check(not CharacterFrame.userPlaced and CharacterFrame.dontSave, 'addon owns persistence without polluting native layout cache')
CharacterFrame:Hide(); CharacterFrame:Show()
check(near(CharacterFrame.left,600) and near(CharacterFrame.top,800), 'position restored on reopen')
CharacterFrame:ClearAllPoints(); CharacterFrame:SetPoint('CENTER',UIParent,'CENTER',0,0)
check(CharacterFrame.points[1][1]=='TOPLEFT' and near(CharacterFrame.left,600), 'native reposition cannot snap saved window back')
character.handle.scripts.OnClick(character.handle,'RightButton')
check(menu.label=='Reset to default' and menu.enabled and menu.owner==character.handle, 'right-click title opens reset dropdown')
menu.callback()
check(ForeverQoLDB.windowPositions.CharacterFrame==nil and CharacterFrame.points[1][4]==21, 'reset clears saved position and restores native default')
check(CharacterFrame.attrs['UIPanelLayout-area']==nil, 'reset preserves overlapping capability')
character.handle.scripts.OnDragStart(); CharacterFrame.left,CharacterFrame.top=500,800; character.handle.scripts.OnDragStop()
CharacterFrame.scale=0.5
W.Apply(character)
check(near(CharacterFrame.left,1000) and near(CharacterFrame.top,1600), 'saved placement accounts for effective scale')
CharacterFrame.scale=1
UIParent.width,UIParent.height=1280,720
eventHandler(nil,'DISPLAY_SIZE_CHANGED')
check(near(CharacterFrame.left,500*1280/1920) and near(CharacterFrame.top,800*720/1080), 'screen resize restores proportional position')
ForeverQoLDB.windowPositions.CharacterFrame={x=5,y=-2}
W.Apply(character)
check(near(CharacterFrame.left,880) and near(CharacterFrame.top,400), 'offscreen placement clamps entire window into view')
ForeverQoLDB.windowPositions.CharacterFrame={x=0/0,y=1}
W.Apply(character)
check(ForeverQoLDB.windowPositions.CharacterFrame==nil, 'invalid saved coordinates are discarded')
UIParent.width,UIParent.height=1920,1080
local custom=frame('MyAddonWindow',UIParent)
custom.TitleText={}
custom:SetPoint('CENTER',UIParent,'CENTER',30,40)
W.Scan(true)
local customRecord=W.records.MyAddonWindow
check(customRecord~=nil, 'discovers other named titled top-level windows')
customRecord.handle.scripts.OnDragStart(); custom.left,custom.top=200,700; customRecord.handle.scripts.OnDragStop()
W.Reset(customRecord)
check(custom.points[1][1]=='CENTER' and custom.points[1][4]==30, 'non-panel reset restores captured original anchors')
local forbidden=frame('ForbiddenWindow',UIParent); forbidden.TitleText={}; forbidden.forbidden=true
W.Attach(forbidden,true)
check(W.records.ForbiddenWindow==nil, 'forbidden frames excluded')
local fullscreen=frame('FullscreenWindow',UIParent); UIPanelWindows.FullscreenWindow={area='full'}
W.Attach(fullscreen,true)
check(W.records.FullscreenWindow==nil, 'native fullscreen scenes excluded')
local alreadyOpen=frame('AlreadyOpenPanel',UIParent)
UIPanelWindows.AlreadyOpenPanel={area='left'}
slots.left=alreadyOpen; alreadyOpen.shown=true
W.Attach(alreadyOpen,true)
local alreadyOpenRecord=W.records.AlreadyOpenPanel
check(not alreadyOpenRecord.detached and alreadyOpen.shown, 'already-managed live panel is not hidden or removed from secure slots mid-interaction')
alreadyOpen:Hide(); slots.left=nil; drain()
check(alreadyOpenRecord.detached and alreadyOpen.attrs['UIPanelLayout-area']==nil, 'already-managed panel detaches safely after its native hide completes')
local specialCount=#UISpecialFrames
W.Scan(true)
check(#UISpecialFrames==specialCount, 'repeated discovery does not duplicate Escape registrations')
BankFrame.protected=true
combat=true
W.Start(bank)
check(not bank.moving and not BankFrame.dragging, 'movement blocked during combat')
local late=frame('LateWindow',UIParent); late.TitleText={}; _G.LateWindow=late
W.Attach(late,true)
check(W.records.LateWindow==nil, 'protected registration deferred in combat')
combat=false
eventHandler(nil,'PLAYER_REGEN_ENABLED')
check(W.records.LateWindow~=nil, 'late window discovered when combat ends')
W.Start(bank); BankFrame.left,BankFrame.top=300,900
combat=true
eventHandler(nil,'PLAYER_REGEN_DISABLED')
check(bank.pendingStop, 'protected drag interrupted by combat queues safe stop')
combat=false
eventHandler(nil,'PLAYER_REGEN_ENABLED')
check(not bank.moving and ForeverQoLDB.windowPositions.BankFrame~=nil, 'interrupted drag saved after combat without protected calls')
local max=false
BankFrame.IsMaximized=function() return max end
max=true
W.Start(bank)
check(not bank.moving, 'maximized window is not dragged')
max=false
ContainerFrame1=frame('ContainerFrame1',UIParent,180,300)
W.Scan()
local bag=W.records.ContainerFrame1
W.Start(bag); ContainerFrame1.left,ContainerFrame1.top=700,700; W.Stop(bag)
UpdateContainerFrameAnchors()
check(near(ContainerFrame1.left,700), 'bag position restored after native layout pass')
W.Reset(bag)
check(ForeverQoLDB.windowPositions.ContainerFrame1==nil and ContainerFrame1.points[1][1]=='BOTTOMRIGHT' and bagLayouts>=2, 'bag reset invokes native bag arrangement')
local count=#timers
W.QueueScan(); W.QueueScan(); W.QueueScan()
check(#timers==count+1, 'load bursts coalesce generic discovery into one scan')
drain()
W.Start(character); CharacterFrame.left,CharacterFrame.top=420,750; W.Stop(character)
local persisted=ForeverQoLDB.windowPositions.CharacterFrame
-- Simulate fresh UI objects and module state using the existing saved variables.
CharacterFrame=frame('CharacterFrame',UIParent)
local F2={Print=function() end}
assert(loadfile(root..'/addon/ForeverQoL/Windows.lua'))('ForeverQoL',F2)
F2.Windows.Initialize()
check(F2.Windows.records.CharacterFrame and near(CharacterFrame.left,420) and near(CharacterFrame.top,750), 'fresh session restores saved position on newly created window')
check(ForeverQoLDB.windowPositions.CharacterFrame==persisted, 'restoring does not rewrite saved data')
local originalShow,originalBagLayout=ShowUIPanel,UpdateContainerFrameAnchors
local showHooks,bagHooks=globalHookCounts.ShowUIPanel,globalHookCounts.UpdateContainerFrameAnchors
ShowUIPanel,UpdateContainerFrameAnchors=nil,nil
local F3={Print=function() end}
assert(loadfile(root..'/addon/ForeverQoL/Windows.lua'))('ForeverQoL',F3)
F3.Windows.InstallHooks()
check(globalHookCounts.ShowUIPanel==showHooks and globalHookCounts.UpdateContainerFrameAnchors==bagHooks, 'missing load-on-demand APIs are not hooked prematurely')
ShowUIPanel,UpdateContainerFrameAnchors=originalShow,originalBagLayout
F3.Windows.InstallHooks(); F3.Windows.InstallHooks()
check(globalHookCounts.ShowUIPanel==showHooks+1 and globalHookCounts.UpdateContainerFrameAnchors==bagHooks+1, 'late API registration retries once without duplicate hooks')
print(string.format('Passed %d movable-window checks.',checks))
