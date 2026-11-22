local root = assert(arg[1])
local checks, combat, timers, eventHandler, allFrames, raiseOrder = 0, false, {}, nil, {}, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.001 end
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function drain() while #timers > 0 do table.remove(timers, 1)() end end
local function frame(name, parent, width, height)
    local f = {name=name, parent=parent, width=width or 400, height=height or 400,
        points={}, attrs={}, scripts={}, level=10, scale=1, strata='MEDIUM', shown=false, left=16, top=900, protected=false}
    allFrames[#allFrames + 1] = f
    local function mutate(self) assert(not combat or not self.protected, 'protected mutation during combat') end
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
    function f:SetWidth(value) self.width=value; if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end end
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
    function f:Raise()
        mutate(self); self.raised=(self.raised or 0)+1; raiseOrder=raiseOrder+1; self.order=raiseOrder
        local level=self.level
        for _,other in ipairs(allFrames) do if other.strata==self.strata then level=math.max(level,other.level+1) end end
        self:SetFrameLevel(level)
    end
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
    f:SetAttributeNoHandler('UIPanelLayout-'..key,value)
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
check(not character.detached and not CharacterFrame.attrs['UIPanelLayout-defined'], 'unmoved windows retain native panel arrangement')
check(UIPanelWindows.CharacterFrame.area=='left', 'preserves native registry')
check(#UISpecialFrames==0, 'default panels do not get addon Escape registrations')
ShowUIPanel(CharacterFrame); ShowUIPanel(MerchantFrame); ShowUIPanel(BankFrame)
check(CharacterFrame.shown and MerchantFrame.shown and BankFrame.shown and slots.left==CharacterFrame, 'default windows are laid out by native panel manager')
check(CharacterFrame.points[1][4]==21 and CharacterFrame.points[1][5]==-100, 'unanchored panel gets native default offsets')
character.handle.scripts.OnDragStart()
check(CharacterFrame.dragging and character.moving and CharacterFrame.raised>0, 'title drag starts movement and raises window')
CharacterFrame.left,CharacterFrame.top=600,800
character.handle.scripts.OnDragStop()
local saved=ForeverQoLDB.windowPositions.CharacterFrame
check(near(saved.x,600/1920) and near(saved.y,800/1080), 'saved position contains normalized screen coordinates')
check(not CharacterFrame.userPlaced and CharacterFrame.dontSave, 'addon owns persistence without polluting native layout cache')
HideUIPanel(CharacterFrame); drain(); ShowUIPanel(CharacterFrame)
check(near(CharacterFrame.left,600) and near(CharacterFrame.top,800), 'position restored on reopen')
check(character.detached and CharacterFrame.strata=='MEDIUM', 'custom window floats while retaining its native strata')
CharacterFrame:ClearAllPoints(); CharacterFrame:SetPoint('CENTER',UIParent,'CENTER',0,0)
check(CharacterFrame.points[1][1]=='TOPLEFT' and near(CharacterFrame.left,600), 'native reposition cannot snap saved window back')
character.handle.scripts.OnClick(character.handle,'RightButton')
check(menu.label=='Reset to default' and menu.enabled and menu.owner==character.handle, 'right-click title opens reset dropdown')
menu.callback()
check(ForeverQoLDB.windowPositions.CharacterFrame==nil and slots.left==CharacterFrame, 'reset clears saved position and re-enters native layout')
check(CharacterFrame.attrs['UIPanelLayout-area']=='left' and CharacterFrame.strata=='MEDIUM', 'reset restores native area and drawing layer')
check(not character.escapeAdded, 'reset removes addon-only Escape registration')
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
ForeverQoLDB.windowPositions.AlreadyOpenPanel={x=.2,y=.8}
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
-- Reset must delegate current mode, free-space decisions and panel eviction to
-- Blizzard; a hardcoded coordinate or old area cannot reproduce this behaviour.
local function closeWindows()
    for _,record in pairs(W.records) do if record.frame.shown then HideUIPanel(record.frame) end end
    drain()
end
closeWindows()
PlayerSpellsFrame=frame('PlayerSpellsFrame',UIParent,577,500)
UIPanelWindows.PlayerSpellsFrame={area='centerOrLeft'}
SetUIPanelAttribute(PlayerSpellsFrame,'area','left')
SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',-405)
W.Scan()
local spells=W.records.PlayerSpellsFrame
ShowUIPanel(PlayerSpellsFrame)
W.Start(spells); PlayerSpellsFrame.left,PlayerSpellsFrame.top=450,850; W.Stop(spells)
HideUIPanel(PlayerSpellsFrame); drain(); ShowUIPanel(PlayerSpellsFrame)
SetUIPanelAttribute(PlayerSpellsFrame,'area','centerOrLeft')
SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',0)
PlayerSpellsFrame:SetWidth(1154)
check(spells.nativeArea=='centerOrLeft' and PlayerSpellsFrame.attrs['UIPanelLayout-area']==nil, 'expanded custom spellbook remembers new native area while remaining floating')
combat=true
SetUIPanelAttribute(PlayerSpellsFrame,'area','left')
combat=false
eventHandler(nil,'PLAYER_REGEN_ENABLED')
check(spells.nativeArea=='left' and PlayerSpellsFrame.attrs['UIPanelLayout-area']==nil, 'combat-deferred area change returns to floating mode after combat')
SetUIPanelAttribute(PlayerSpellsFrame,'area','left')
SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',-405)
PlayerSpellsFrame:SetWidth(577)
W.Reset(spells)
check(PlayerSpellsFrame.attrs['UIPanelLayout-area']=='left' and slots.left==PlayerSpellsFrame
    and PlayerSpellsFrame.points[1][1]=='TOPLEFT', 'minimized spellbook reset uses live left area rather than centering from registry')
check(PlayerSpellsFrame.attrs['UIPanelLayout-centerXOffset']==-405, 'reset preserves current minimize offset')
HideUIPanel(PlayerSpellsFrame)
SetUIPanelAttribute(PlayerSpellsFrame,'area','centerOrLeft')
SetUIPanelAttribute(PlayerSpellsFrame,'centerXOffset',0)
PlayerSpellsFrame:SetWidth(1154)
ShowUIPanel(PlayerSpellsFrame)
check(slots.center==PlayerSpellsFrame and PlayerSpellsFrame.points[1][1]=='TOP', 'expanded default spellbook follows native center-or-left placement')
HideUIPanel(PlayerSpellsFrame)
SetUIPanelAttribute(PlayerSpellsFrame,'area','left')
PlayerSpellsFrame:SetWidth(577)
ShowUIPanel(PlayerSpellsFrame)
W.Start(spells); PlayerSpellsFrame.left,PlayerSpellsFrame.top=450,850; W.Stop(spells)
HideUIPanel(PlayerSpellsFrame); drain()
ShowUIPanel(MerchantFrame); ShowUIPanel(PlayerSpellsFrame)
W.Reset(spells)
check(MerchantFrame.shown and slots.center==PlayerSpellsFrame, 'reset uses available native panel space alongside another default window')
W.Start(spells); W.Stop(spells)
HideUIPanel(PlayerSpellsFrame); drain(); ShowUIPanel(PlayerSpellsFrame)
UIParent.width=700
W.Reset(spells)
check(not MerchantFrame.shown and slots.left==PlayerSpellsFrame, 'reset lets native panel manager evict windows when there is not enough space')
UIParent.width=1920
closeWindows()
WorldMapFrame=frame('WorldMapFrame',UIParent,700,500)
WorldMapFrame.strata='HIGH'
UIPanelWindows.WorldMapFrame={area='left'}
W.Scan()
local map=W.records.WorldMapFrame
ShowUIPanel(CharacterFrame)
W.Start(character); CharacterFrame.left,CharacterFrame.top=420,750; W.Stop(character)
HideUIPanel(CharacterFrame); drain(); ShowUIPanel(CharacterFrame)
ForeverQoLDB.windowPositions.WorldMapFrame={x=.2,y=.8}
W.Apply(map); ShowUIPanel(WorldMapFrame)
check(WorldMapFrame.order>CharacterFrame.order and WorldMapFrame.shown and CharacterFrame.shown, 'opening custom map raises it above overlapping custom character sheet')
HideUIPanel(CharacterFrame); ShowUIPanel(CharacterFrame)
check(CharacterFrame.order>WorldMapFrame.order and CharacterFrame.strata=='MEDIUM' and WorldMapFrame.strata=='HIGH'
    and near(CharacterFrame.left,420), 'reopening raises character sheet at saved position without rewriting native map strata priority')
HideUIPanel(WorldMapFrame); ShowUIPanel(WorldMapFrame)
check(WorldMapFrame.order>CharacterFrame.order, 'latest reopened custom window comes to front in either order')
ShowUIPanel(BankFrame)
W.Apply(bank)
W.Reset(bank)
check(not BankFrame.shown and ForeverQoLDB.windowPositions.BankFrame==nil, 'reset closes detached NPC window without resurrecting ended interaction')
ShowUIPanel(BankFrame)
check(slots.left==BankFrame and BankFrame.attrs['UIPanelLayout-area']=='left', 'next NPC interaction uses native default panel management')
closeWindows()
-- Compare actual native strata first; HIGH widgets need not have larger
-- frame levels than MEDIUM backgrounds to render above them.
local nativeStrata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,TOOLTIP=6}
local function above(a,b)
    if a.strata~=b.strata then return nativeStrata[a.strata]>nativeStrata[b.strata] end
    return a.level>b.level
end
ProfessionsFrame=frame('ProfessionsFrame',UIParent)
UIPanelWindows.ProfessionsFrame={area='left'}
local page=frame(nil,ProfessionsFrame); page.level=100
local content=frame(nil,page); content.level=101
ProfessionsFrame.BookPage=page; page.ProfessionsContentFrame=content
local cards={}
for _,key in ipairs({'PrimaryProfession1','PrimaryProfession2','SecondaryProfession1','SecondaryProfession2','SecondaryProfession3'}) do
    local card=frame(nil,content); card.level=102; content[key]=card
    local bar=frame(nil,card); bar.strata='HIGH'; bar.level=1; card.StatusBar=bar
    bar.Rank=frame(nil,bar); bar.Rank.strata='HIGH'; bar.Rank.level=5
    bar.ExpansionDropdownButton=frame(nil,bar); bar.ExpansionDropdownButton.strata='HIGH'; bar.ExpansionDropdownButton.level=2
    cards[#cards+1]=card
end
local crafting=frame(nil,ProfessionsFrame); crafting.level=100; ProfessionsFrame.CraftingPage=crafting
crafting.RankBar=frame(nil,crafting); crafting.RankBar.strata='HIGH'; crafting.RankBar.level=1
W.Scan(); local professions=W.records.ProfessionsFrame
ShowUIPanel(ProfessionsFrame)
check(above(cards[1].StatusBar,cards[1]), 'default profession bar renders above its card using native strata')
W.Start(professions); W.Stop(professions)
for _,card in ipairs(cards) do
    local bar=card.StatusBar
    check(ProfessionsFrame.strata=='MEDIUM' and above(bar,card) and bar.level==1 and bar.Rank.level==5
        and bar.ExpansionDropdownButton.level==2 and not bar.strataWrites,
        'drag keeps each primary/secondary profession bar, rank and dropdown on untouched native layers')
end
check(above(crafting.RankBar,crafting) and crafting.RankBar.level==1, 'drag preserves the crafting page rank bar')
HideUIPanel(ProfessionsFrame); drain(); ShowUIPanel(ProfessionsFrame)
professions.handle.scripts.OnMouseDown()
check(above(cards[1].StatusBar,cards[1]) and not ProfessionsFrame.strataWrites, 'reopen and title click retain native profession strata')
page:SetFrameLevel(100) -- Blizzard can change page levels while switching tabs.
W.Front(professions)
check(above(cards[1].StatusBar,cards[1]) and cards[1].StatusBar.level==1, 'native tab-level changes do not require mover layer repair')
W.Reset(professions)
check(not ProfessionsFrame.strataWrites and not crafting.RankBar.strataWrites and cards[1].StatusBar.level==1,
    'reset does not rewrite native profession drawing metadata')
ProfessionsBookFrame=frame('ProfessionsBookFrame',UIParent)
local standaloneContent=frame(nil,ProfessionsBookFrame); standaloneContent.level=100
local standaloneBar=frame(nil,standaloneContent); standaloneBar.level=1; standaloneBar.strata='HIGH'
W.Scan(); local standaloneBook=W.records.ProfessionsBookFrame
W.Start(standaloneBook); W.Stop(standaloneBook)
check(above(standaloneBar,standaloneContent) and standaloneBar.level==1, 'standalone profession book retains native bar layering')
closeWindows()
LFGParentFrame=frame('LFGParentFrame',UIParent)
UIPanelWindows.LFGParentFrame={area='left'}
local who=frame('LFGWhoListFrame',LFGParentFrame); who.level=100
who.TitleContainer=frame(nil,who); who.TitleContainer.level=510
local whoInset=frame(nil,who); whoInset.level=500
local whoList=frame(nil,whoInset); whoList.level=501
local whoEdit=frame('WhoFrameEditBox',who); whoEdit.strata='HIGH'; whoEdit.level=1
local whoSearch=frame(nil,who); whoSearch.strata='HIGH'; whoSearch.level=2
local whoTooltip=frame(nil,who); whoTooltip.strata='TOOLTIP'; whoTooltip.level=3
local whoDialog=frame(nil,who); whoDialog.strata='DIALOG'; whoDialog.level=4
local forbidden=frame(nil,who); forbidden.forbidden=true
function forbidden:GetFrameStrata() error('must not inspect forbidden frame') end
W.Scan(true); local lfg=W.records.LFGParentFrame
check(lfg and not W.records.LFGWhoListFrame, 'Who tab remains part of the LFG owner')
ShowUIPanel(LFGParentFrame); W.Start(lfg); W.Stop(lfg)
check(above(whoEdit,whoInset) and above(whoSearch,whoInset) and above(whoList,whoInset),
    'Who search and list stay above their background after dragging')
check(whoTooltip.strata=='TOOLTIP' and whoTooltip.level==3 and whoDialog.strata=='DIALOG' and whoDialog.level==4,
    'tooltips and dialogs retain native overlay layers')
local lateRow=frame(nil,whoList); lateRow.level=whoList.level+1
W.Front(lfg)
check(above(lateRow,whoList) and above(whoEdit,lateRow), 'late Who rows inherit native list layers without a mover cache')
HideUIPanel(LFGParentFrame); drain(); ShowUIPanel(LFGParentFrame)
check(above(whoEdit,who.TitleContainer) and whoEdit.level==1 and not whoEdit.strataWrites,
    'reopened Who search retains its native priority above title art')
W.Reset(lfg)
check(not whoEdit.strataWrites and not whoInset.strataWrites and whoEdit.level==1,
    'Who reset leaves native drawing layers intact')
do
    local owner=frame('LayerAudit',UIParent)
    local art=frame(nil,owner); art.level=510
    local low=frame(nil,owner); low.strata='LOW'; low.level=900
    local overlay=frame(nil,owner); overlay.strata='HIGH'; overlay.level=1
    local detail=frame(nil,overlay); detail.strata='HIGH'; detail.level=5
    local peer=frame(nil,overlay); peer.strata='HIGH'; peer.level=5
    W.Attach(owner,true); local record=W.records[owner.name]
    owner:Show(); W.Start(record); W.Stop(record)
    W.Front(record); W.Front(record)
    check(above(owner,low) and above(overlay,art) and above(detail,overlay) and peer.level==detail.level,
        'mixed-layer controls and equal native levels survive repeated raises')
    W.Reset(record)
    check(low.strata=='LOW' and low.level==900 and overlay.strata=='HIGH' and overlay.level==1
        and detail.level==5 and not overlay.strataWrites, 'other windows retain original low/high drawing metadata')
    owner:Hide()
end
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
