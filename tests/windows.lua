local root = assert(arg[1])
local checks, combat, timers, eventHandler, allFrames, raiseOrder = 0, false, {}, nil, {}, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.001 end
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function drain() while #timers > 0 do table.remove(timers, 1)() end end
local function frame(name, parent, width, height)
    local f = {name=name, parent=parent, width=width or 400, height=height or 400,
        points={}, attrs={}, scripts={}, hooks={}, level=10, scale=1, strata='MEDIUM', shown=false, left=16, top=900, protected=false}
    allFrames[#allFrames + 1] = f
    local function mutate(self) assert(not combat or not self.protected, 'protected mutation during combat') end
    local function run(self,event)
        if self.scripts[event] then self.scripts[event](self) end
        for _,callback in ipairs(self.hooks[event] or {}) do callback(self) end
    end
    local function visibility(self,event)
        run(self,event)
        for _,child in ipairs({self:GetChildren()}) do if child.shown then visibility(child,event) end end
    end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetChildren()
        local children={}
        for _,child in ipairs(allFrames) do if child.parent==self then children[#children+1]=child end end
        return unpack(children)
    end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(level)
        mutate(self)
        local delta=level-self.level; self.level=level
        -- The engine moves children in the same strata along with a parent.
        for _,child in ipairs({self:GetChildren()}) do
            if child.strata==self.strata then child:SetFrameLevel(child.level+delta) end
        end
    end
    function f:GetFrameStrata() return self.strata end
    function f:SetFrameStrata(value) mutate(self); self.strata=value; self.strataWrites=(self.strataWrites or 0)+1 end
    function f:SetHeight(value) self.height=value end
    function f:SetWidth(value) self.width=value; run(self,'OnSizeChanged') end
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
    function f:Show() if self.shown then return end; self.shown=true; visibility(self,'OnShow') end
    function f:Hide() if not self.shown then return end; self.shown=false; visibility(self,'OnHide') end
    function f:SetMovable(value) mutate(self); self.movable=value end
    function f:SetClampedToScreen(value) mutate(self); self.clamped=value end
    function f:SetUserPlaced(value) mutate(self); self.userPlaced=value end
    function f:SetDontSavePosition(value) mutate(self); self.dontSave=value end
    function f:StartMoving() mutate(self); self.dragging=true end
    function f:StopMovingOrSizing() mutate(self); self.dragging=false; self.stops=(self.stops or 0)+1 end
    function f:Raise()
        mutate(self); self.raised=(self.raised or 0)+1; raiseOrder=raiseOrder+1; self.order=raiseOrder
        local level=self.level
        for _,other in ipairs(allFrames) do if other.strata==self.strata then level=math.max(level,other.level+1) end end
        self:SetFrameLevel(level)
    end
    function f:GetAttribute(key) return self.attrs[key] end
    function f:SetAttributeNoHandler(key, value)
        assert(not self.nativeOwned, 'addon rewrote a Blizzard panel attribute')
        mutate(self); self.attrs[key]=value
    end
    function f:RegisterForDrag(...) self.dragButtons={...} end
    function f:RegisterForClicks(...) self.clickButtons={...} end
    function f:RegisterEvent() end
    function f:SetScript(event, callback)
        assert(not self.nativeOwned, 'addon replaced a Blizzard lifecycle script')
        self.scripts[event]=callback; if event=='OnEvent' then eventHandler=callback end
    end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, callback)
        self.hooks[event]=self.hooks[event] or {}
        self.hooks[event][#self.hooks[event]+1]=callback
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
local function areaOf(f)
    local area=f.attrs['UIPanelLayout-defined'] and f.attrs['UIPanelLayout-area'] or nil
    if not f.attrs['UIPanelLayout-defined'] then area=UIPanelWindows[f.name] and UIPanelWindows[f.name].area end
    return area
end
local function layout()
    local x=16
    for _, key in ipairs({'left','center','right'}) do
        local f=slots[key]
        if f then
            f:ClearAllPoints()
            if areaOf(f)=='center' or (areaOf(f)=='centerOrLeft' and key=='center' and not slots.left) then
                f:SetPoint('TOP',UIParent,'TOP',f.attrs['UIPanelLayout-centerXOffset'] or 0,-100)
            else
                local offset=UIPanelWindows[f.name].xoffset or 0
                f:SetPoint('TOPLEFT',UIParent,'TOPLEFT',x+offset,-100)
            end
            x=x+f.width+20
        end
    end
end
UpdateUIPanelPositions=function() layout() end
HideUIPanel=function(f)
    for key,value in pairs(slots) do if value==f then slots[key]=nil end end
    f:Hide()
    layout()
end
ShowUIPanel=function(f)
    if not f or f.shown then return end
    for key,value in pairs(slots) do if not value.shown then slots[key]=nil end end
    local area=areaOf(f)
    if area then
        if not f.attrs['UIPanelLayout-defined'] then
            for key,value in pairs(UIPanelWindows[f.name]) do f.attrs['UIPanelLayout-'..key]=value end
            f.attrs['UIPanelLayout-defined']=true
        end
        local count,total=0,0
        for _,value in pairs(slots) do count=count+1; total=total+value.width+20 end
        if area=='center' or total+f.width+20>UIParent.width or count>=3 then
            local old={}; for _,value in pairs(slots) do old[#old+1]=value end
            for _,value in ipairs(old) do HideUIPanel(value) end
            slots[area=='center' and 'center' or 'left']=f
        elseif area=='centerOrLeft' and count==0 then slots.center=f
        else
            for _,key in ipairs({'left','center','right'}) do if not slots[key] then slots[key]=f; break end end
        end
        layout()
    end
    f:Show()
end
SetUIPanelAttribute=function(f,key,value)
    if not f.attrs['UIPanelLayout-defined'] then
        for k,v in pairs(UIPanelWindows[f.name]) do f.attrs['UIPanelLayout-'..k]=v end
        f.attrs['UIPanelLayout-defined']=true
    end
    f.attrs['UIPanelLayout-'..key]=value -- Native game-side attribute change.
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
local nativeClosed=0
local nativeOnHide=function() nativeClosed=nativeClosed+1 end
CharacterFrame:SetScript('OnHide',nativeOnHide)
for _,f in ipairs({CharacterFrame,MerchantFrame,BankFrame}) do f.nativeOwned=true end
-- Fail immediately if the mover scans unrelated UI or rewrites native scripts
-- or attributes. Mock layout checks alone cannot model real client taint.
EnumerateFrames=function() error('must not enumerate unrelated UI') end
local F={Print=function() end}
assert(loadfile(root..'/addon/ForeverQoL/Windows.lua'))('ForeverQoL',F)
local W=F.Windows
W.InstallHooks(); W.Initialize()
local character,merchant,bank=W.records.CharacterFrame,W.records.MerchantFrame,W.records.BankFrame
check(character and merchant and bank, 'registers supported windows')
check(character.handle.height==20 and character.handle.level==511, 'addon title handle clears native title and close controls')
check(CharacterFrame:GetScript('OnHide')==nativeOnHide and #UISpecialFrames==0, 'registration preserves native scripts and Escape list')
for _,name in ipairs({'MultiBarBottomLeft','MainMenuBar','GameMenuFrame','AddonList','SettingsPanel','MyAddonWindow'}) do
    local unsupported=frame(name,UIParent); unsupported.TitleText={}; unsupported.protected=true; unsupported.nativeOwned=true
    _G[name]=unsupported; UIPanelWindows[name]={area='left'}
    W.Attach(unsupported,true)
    check(not W.records[name] and not unsupported.movable, 'does not attach action bars, system menus or arbitrary titled windows: '..name)
end
W.Scan(true)
ShowUIPanel(CharacterFrame)
check(slots.left==CharacterFrame and CharacterFrame.points[1][4]==21, 'default panel uses native placement')
W.Start(character); CharacterFrame.left,CharacterFrame.top=600,800; W.Stop(character)
check(near(ForeverQoLDB.windowPositions.CharacterFrame.x,600/1920), 'drag saves normalized position')
check(slots.left==CharacterFrame and CharacterFrame.attrs['UIPanelLayout-area']=='left' and nativeClosed==0,
    'drag preserves secure panel ownership and does not synthesize hide/show')
check(CharacterFrame.strata=='MEDIUM' and not CharacterFrame.strataWrites, 'drag keeps native rendering layers')
HideUIPanel(CharacterFrame); ShowUIPanel(CharacterFrame)
check(nativeClosed==1 and near(CharacterFrame.left,600) and near(CharacterFrame.top,800), 'normal reopen restores position and real close still runs native cleanup')
character.handle.scripts.OnClick(character.handle,'RightButton')
check(menu.label=='Reset to default' and menu.enabled, 'title menu offers reset')
menu.callback()
check(not ForeverQoLDB.windowPositions.CharacterFrame and CharacterFrame.points[1][4]==21 and nativeClosed==1,
    'reset delegates placement to Blizzard without closing window or replacing handlers')
W.Start(character); CharacterFrame.left,CharacterFrame.top=500,800; W.Stop(character)
UIParent.width,UIParent.height=1280,720
eventHandler(nil,'DISPLAY_SIZE_CHANGED')
check(near(CharacterFrame.left,500*1280/1920), 'saved position follows resolution changes')
ForeverQoLDB.windowPositions.CharacterFrame={x=5,y=-2}; W.Apply(character)
check(near(CharacterFrame.left,880) and near(CharacterFrame.top,400), 'position clamps to screen')
ForeverQoLDB.windowPositions.CharacterFrame={x=0/0,y=1}; W.Apply(character)
check(not ForeverQoLDB.windowPositions.CharacterFrame, 'invalid coordinates discarded without native attribute edits')
UIParent.width,UIParent.height=1920,1080
BankFrame.protected=true
combat=true
W.Start(bank); W.Apply(bank); W.Reset(bank); W.Scan()
check(not bank.moving, 'protected window operations blocked in combat')
combat=false
W.Start(bank); BankFrame.left,BankFrame.top=300,900
combat=true; eventHandler(nil,'PLAYER_REGEN_DISABLED')
check(bank.pendingStop, 'protected drag stop is deferred in combat')
combat=false; eventHandler(nil,'PLAYER_REGEN_ENABLED')
check(not bank.moving and ForeverQoLDB.windowPositions.BankFrame, 'deferred stop saves position outside combat')
local maximized=true
BankFrame.IsMaximized=function() return maximized end
W.Start(bank)
check(not bank.moving, 'maximized window cannot be dragged')
maximized=false
ContainerFrame1=frame('ContainerFrame1',UIParent,180,300); ContainerFrame1.nativeOwned=true
W.Scan(); local bag=W.records.ContainerFrame1
W.Start(bag); ContainerFrame1.left,ContainerFrame1.top=700,700; W.Stop(bag)
UpdateContainerFrameAnchors()
check(near(ContainerFrame1.left,700), 'bag saved position survives native anchor pass')
W.Reset(bag)
check(not ForeverQoLDB.windowPositions.ContainerFrame1 and ContainerFrame1.points[1][1]=='BOTTOMRIGHT', 'bag reset uses native arrangement')
local count=#timers
W.QueueScan(); W.QueueScan(); W.QueueScan()
check(#timers==count+1, 'known-window registration is coalesced')
drain()
local function closeWindows()
    for _,record in pairs(W.records) do if record.frame.shown then HideUIPanel(record.frame) end end
end
closeWindows()
PlayerSpellsFrame=frame('PlayerSpellsFrame',UIParent,577,500); PlayerSpellsFrame.nativeOwned=true
UIPanelWindows.PlayerSpellsFrame={area='left'}
SetUIPanelAttribute(PlayerSpellsFrame,'area','left'); SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',-405)
W.Scan(); local spells=W.records.PlayerSpellsFrame
ShowUIPanel(PlayerSpellsFrame)
W.Start(spells); PlayerSpellsFrame.left,PlayerSpellsFrame.top=450,850; W.Stop(spells)
W.Reset(spells)
check(PlayerSpellsFrame.attrs['UIPanelLayout-area']=='left' and PlayerSpellsFrame.points[1][1]=='TOPLEFT', 'compact spellbook reset uses live native left layout')
check(PlayerSpellsFrame.attrs['UIPanelLayout-centerXOffset']==-405, 'compact offset stays native')
HideUIPanel(PlayerSpellsFrame)
SetUIPanelAttribute(PlayerSpellsFrame,'area','centerOrLeft'); SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',0)
PlayerSpellsFrame:SetWidth(1154); ShowUIPanel(PlayerSpellsFrame)
W.Start(spells); W.Stop(spells); W.Reset(spells)
check(slots.center==PlayerSpellsFrame and PlayerSpellsFrame.points[1][1]=='TOP', 'expanded spellbook reset delegates current mode to Blizzard')
closeWindows()
local nativeOpened,professionClosed=0,0
ProfessionsFrame=frame('ProfessionsFrame',UIParent,673,594)
ProfessionsFrame:SetScript('OnShow',function() nativeOpened=nativeOpened+1 end)
ProfessionsFrame:SetScript('OnHide',function() professionClosed=professionClosed+1 end)
ProfessionsFrame.nativeOwned=true; UIPanelWindows.ProfessionsFrame={area='left'}
local page=frame(nil,ProfessionsFrame); page.level=100; page.nativeOwned=true
local bar=frame(nil,page); bar.level=1; bar.strata='HIGH'; bar.nativeOwned=true
W.Scan(); local professions=W.records.ProfessionsFrame
ShowUIPanel(ProfessionsFrame)
W.Start(professions); ProfessionsFrame.left,ProfessionsFrame.top=1100,780; W.Stop(professions)
check(nativeOpened==1 and professionClosed==0 and slots.left==ProfessionsFrame,
    'first drag leaves native lifecycle and panel manager alone')
check(bar.level==1 and bar.strata=='HIGH' and ProfessionsFrame.strata=='MEDIUM', 'progress bar retains native drawing priority after moving')
W.Reset(character); ShowUIPanel(CharacterFrame)
check(CharacterFrame.shown and slots.center==CharacterFrame, 'native panel manager still arranges untouched panels around open professions')
HideUIPanel(CharacterFrame); ShowUIPanel(CharacterFrame)
check(CharacterFrame.raised and professionClosed==0, 'reopening raises supported window without affecting professions interaction')
W.Reset(professions)
check(ProfessionsFrame.shown and professionClosed==0, 'reset does not synthesize native visibility changes')
HideUIPanel(ProfessionsFrame)
check(professionClosed==1, 'real close still cleans up profession interaction')
W.Start(character); CharacterFrame.left,CharacterFrame.top=420,750; W.Stop(character)
local persisted=ForeverQoLDB.windowPositions.CharacterFrame
CharacterFrame=frame('CharacterFrame',UIParent); CharacterFrame.nativeOwned=true
local F2={Print=function() end}
assert(loadfile(root..'/addon/ForeverQoL/Windows.lua'))('ForeverQoL',F2)
F2.Windows.Initialize()
check(F2.Windows.records.CharacterFrame and near(CharacterFrame.left,420) and near(CharacterFrame.top,750), 'fresh session restores saved positions')
check(ForeverQoLDB.windowPositions.CharacterFrame==persisted, 'restore does not rewrite saved variables')
print(string.format('Passed %d movable-window checks.',checks))
