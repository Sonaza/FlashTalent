------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = Addon;

local _;

local LibQTip = LibStub("LibQTip-1.0");

local TALENT_CLASS = 1;
local TALENT_HONOR = 2;
local CLASS_TALENTS_TAB = 1;
local HONOR_TALENTS_TAB = 2;

local TALENT_COLOR_LOCKED           = { 0.22, 0.22, 0.22 };
local TALENT_COLOR_LOCKED_HOVER     = { 0.35, 0.35, 0.35 };

local TALENT_COLOR_CANLEARN         = { 0.82, 0.82, 0.82 };
local TALENT_COLOR_CANLEARN_HOVER   = { 1.0, 1.0, 1.0 };

local TALENT_COLOR_SELECTED         = { 0.9, 0.9, 0.9 };
local TALENT_COLOR_SELECTED_HOVER   = { 1.0, 1.0, 1.0 };

local function IconSetColor(frame, color)
	if(not frame or not color) then return end
	frame:SetVertexColor(unpack(color));
end

local TALENT_CLEAR_ITEMS = {
	{
		-- Max lvl 100 items
		141640, -- Tome of Clear Mind
		141641, -- Codex of Clear Mind
	},
	{
		-- Over lvl 100 items
		141446, -- Tome of Tranquil Mind
		141333, -- Codex of Tranquil Mind
	},
};
	
local TALENT_CLEAR_BUFFS = {
	{ id = 227565, },            -- Codex of Clear Mind (100) 
	{ id = 226234, },            -- Codex of Tranquil Mind
	{ id = 227563, lvl = 100 },  -- Tome of Clear Mind (100)
	{ id = 227041 },             -- Tome of Tranquil Mind
};

local PVP_TALENT_LEVELS = {
	{  1, 13, 31 },
	{  2, 16, 34 },
	{  4, 19, 37 },
	{  6, 22, 40 },
	{  8, 25, 43 },
	{ 10, 28, 46 },
};

----------------------------------------------------------

function Addon:OnEnable()
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	if(InCombatLockdown()) then
		Addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	end
	
	Addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	Addon:RegisterEvent("PET_SPECIALIZATION_CHANGED");
	
	Addon:RegisterEvent("PLAYER_TALENT_UPDATE");
	Addon:RegisterEvent("PLAYER_PVP_TALENT_UPDATE", "PLAYER_TALENT_UPDATE");
	
	if(UnitLevel("player") < MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]) then
		Addon:RegisterEvent("PLAYER_LEVEL_UP");
	end
	
	if(UnitFactionGroup("player") == "Neutral") then
		Addon:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
	end
	
	if(select(2, UnitClass("player")) == "HUNTER") then
		Addon:RegisterEvent("UNIT_PET");
	end
	
	Addon:RegisterEvent("UNIT_AURA");
	Addon:RegisterEvent("BAG_UPDATE_DELAYED");
	Addon:RegisterEvent("MODIFIER_STATE_CHANGED");
	Addon:RegisterEvent("PLAYER_UPDATE_RESTING");
	Addon:RegisterEvent("SPELL_UPDATE_USABLE");
	
	Addon:RegisterEvent("EQUIPMENT_SWAP_FINISHED");
	Addon:RegisterEvent("EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED");
	
	-- Addon:RegisterEvent("SCENARIO_UPDATE");
	-- Addon:RegisterEvent("CHALLENGE_MODE_START");
	-- Addon:RegisterEvent("CHALLENGE_MODE_RESET");
	-- Addon:RegisterEvent("CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET");
	
	CreateFrame("Frame"):SetScript("OnUpdate", function(self, elapsed) Addon:OnUpdate(elapsed) end);
	
	hooksecurefunc("ModifyEquipmentSet", function(oldName, newName)
		for specIndex, setName in pairs(Addon.db.char.SpecSets) do
			if(setName == oldName) then
				Addon.db.char.SpecSets[specIndex] = newName;
			end
		end
	end);
	
	if(not self.db.global.StickyWindow) then
		tinsert(UISpecialFrames, "FlashTalentFrame");
	end
	
	if(not Addon:IsBindingSet() and not Addon:HasAskedBinding()) then
		StaticPopup_Show("FLASHTALENT_NO_KEYBIND");
	end
	
	hooksecurefunc("SetSpecialization", function(newSpec)
		if(GetSpecialization() and GetSpecialization() ~= newSpec) then
			Addon.OldSpecialization = GetSpecialization();
		end
	end);
	
	-- if(C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
	-- 	Addon:CHALLENGE_MODE_START();
	-- end
	
	Addon:SetupSecureFrameToggler();
	
	Addon:UpdateTalentFrame();
	Addon:UpdateFrame();
	Addon:UpdateTabIcons();
	
	Addon:InitializeDatabroker();
end

function Addon:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	if(self.elapsed > 0.1) then
		Addon:UpdateTalentCooldowns();
		self.elapsed = 0;
		
		if(FlashTalentFrameReagents and FlashTalentFrameReagents.tooltipOpen) then
			FlashTalentReagentFrame_OnEnter(FlashTalentFrameReagents);
		end
		
		local canChange, remainingTime = Addon:CanChangeTalents();
		if(canChange and remainingTime) then
			Addon:UpdateReagentCount();
		end
	end
	
	if(Addon.db.global.HideBlizzAlert) then
		TalentMicroButtonAlert:Hide();
	end
end

function Addon:SetupSecureFrameToggler(short)
	if(InCombatLockdown()) then return end
	
	if(not Addon.SecureFrameToggler) then
		Addon.SecureFrameToggler = CreateFrame("Button", "FlashTalentFrameToggler", nil, "SecureActionButtonTemplate");
	end
	
	local initMacroText = "";
	
	if(not short) then
		initMacroText = 
			"/stopmacro [combat]\n"..
			"/click TalentMicroButton\n"..
			"/click PlayerTalentFrameTab3\n"..
			"/click PlayerTalentFrameTab2\n"..
			"/click TalentMicroButton\n";
	end
	
	Addon.SecureFrameToggler:SetAttribute("type1", "macro");
	Addon.SecureFrameToggler:SetAttribute("macrotext1",
		initMacroText ..
		"/run FlashTalent:ToggleFrame(" .. CLASS_TALENTS_TAB .. ")"
	);
	
	Addon.SecureFrameToggler:SetAttribute("type2", "macro");
	Addon.SecureFrameToggler:SetAttribute("macrotext2",
		initMacroText ..
		"/run FlashTalent:ToggleFrame(" .. HONOR_TALENTS_TAB .. ")"
	);
end

---------------------------------------------------------------
-- Utility functions

function Addon:FormatTime(seconds)
	if(seconds > 60) then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60);
	elseif(seconds > 3) then
		return string.format("%ds", seconds);
	else
		return string.format("%.01fs", seconds);
	end
end

function Addon:GetRealSpellID(spell_id)
	local spell_name = GetSpellInfo(spell_id);
	local name, _, _, _, _, _, realSpellID = GetSpellInfo(spell_name);
	
	return realSpellID or spell_id;
end

function Addon:UnitHasBuff(unit, spell)
	if(not unit or not spell) then return false end
	
	local realSpellID = Addon:GetRealSpellID(spell);
	local spell_name = GetSpellInfo(realSpellID);
	if(not spell_name) then return false end
	
	local name, _, _, _, _, duration, expirationTime, unitCaster = UnitAura(unit, spell_name, nil, "HELPFUL");
	if(not name) then
		return false;
	end
	
	return true, expirationTime - GetTime();
end

function Addon:CanChangeTalents()
	if(InCombatLockdown()) then return false end
	if(IsResting()) then return true end
	
	local level = UnitLevel("player");
	
	for _, data in ipairs(TALENT_CLEAR_BUFFS) do
		if(not data.lvl or (data.lvl and level <= data.lvl)) then
			local hasBuff, remaining = Addon:UnitHasBuff("player", data.id);
			if(hasBuff) then
				return true, remaining;
			end
		end
	end
	
	return false, nil;
end

function Addon:AddScriptedTooltipLine(tooltip, text, onClick, onEnter, onLeave)
	local lineIndex;
	if(type(text) == "table") then
		lineIndex = tooltip:AddLine(unpack(text));
	else
		lineIndex = tooltip:AddLine(text);
	end
	
	if(onEnter) then tooltip:SetLineScript(lineIndex, "OnEnter", onEnter); end
	if(onLeave) then tooltip:SetLineScript(lineIndex, "OnLeave", onLeave); end
	if(onClick) then tooltip:SetLineScript(lineIndex, "OnMouseUp", onClick); end
	
	return lineIndex;
end

function Addon:GetSpecializationInfoByName(specName)
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, background, role, primaryStat = GetSpecializationInfo(specIndex);
		if(name == specName) then
			return id, name, description, icon, background, role, primaryStat;
		end
	end
end

function Addon:SetTalentTooltip(talentButton)
	GameTooltip:SetOwner(talentButton, "ANCHOR_RIGHT");
	
	if(talentButton.talentCategory == TALENT_CLASS) then
		GameTooltip:SetTalent(talentButton.talentID);
		
		if(not talentButton.isUnlocked) then
			local lastLine = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()];
			if(lastLine and lastLine:GetText() == TALENT_TOOLTIP_ADDPREVIEWPOINT) then
				lastLine:SetText("Your level is too low to select this talent.");
				lastLine:SetTextColor(1, 0.1, 0.1);
			end
		elseif(talentButton.isOnCooldown) then
			local lastLine = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()];
			if(lastLine and lastLine:GetText() == TALENT_TOOLTIP_ADDPREVIEWPOINT) then
				lastLine:SetText("Talent on this row is on cooldown.");
				lastLine:SetTextColor(1, 0.1, 0.1);
			end
		end
		
	elseif(talentButton.talentCategory == TALENT_HONOR) then
		GameTooltip:SetPvpTalent(talentButton.talentID);
	end
	
	GameTooltip:Show();
end

----------------------------------------------------------
-- Binding management

function Addon:IsBindingSet()
	return GetBindingKey("CLICK FlashTalentFrameToggler:LeftButton") ~= nil;
end

function Addon:HasAskedBinding()
	if(GetCurrentBindingSet() == 1) then
		return self.db.global.AskedKeybind;
	elseif(GetCurrentBindingSet() == 2) then
		return self.db.char.AskedKeybind;
	end
end

function Addon:SetAskedBinding(value)
	if(GetCurrentBindingSet() == 1) then
		self.db.global.AskedKeybind = value;
	elseif(GetCurrentBindingSet() == 2) then
		self.db.char.AskedKeybind = value;
	end
end

----------------------------------------------------------
-- Window management

function Addon:SavePosition()
	local point, _, relativePoint, x, y     = FlashTalentFrame:GetPoint();
	self.db.global.Position.Point           = point;
	self.db.global.Position.RelativePoint   = relativePoint;
	self.db.global.Position.x               = x;
	self.db.global.Position.y               = y;
end

function Addon:RestorePosition()
	local position = self.db.global.Position;
	if(position and position.Point and position.RelativePoint and position.x and position.y) then
		FlashTalentFrame:ClearAllPoints();
		FlashTalentFrame:GetPoint(position.Point, UIparent, position.RelativePoint, position.x, position.y);
	end
end

function Addon:ToggleFrame(tabIndex)
	if(InCombatLockdown()) then return end
	
	local tabIndex = tabIndex or Addon.CurrentTalentTab;
	
	if(tabIndex == HONOR_TALENTS_TAB and UnitLevel("player") < SHOW_PVP_TALENT_LEVEL) then
		tabIndex = CLASS_TALENTS_TAB;
	end
	
	if(not FlashTalentFrame:IsVisible() or Addon.CurrentTalentTab ~= tabIndex) then
		Addon:RestorePosition();
		FlashTalentFrame:Show();
		Addon:OpenTalentTab(tabIndex);
	else
		FlashTalentFrame:Hide();
	end
	
	if(not Addon.ShortToggler) then
		Addon.ShortToggler = true;
		Addon:SetupSecureFrameToggler(true);
	end
end

function Addon:UpdateFrame()
	if(not InCombatLockdown() and not FlashTalentFrame:IsVisible() and self.db.global.StickyWindow and self.db.global.IsWindowOpen) then
		FlashTalentFrame:Show();
	end
	
	if(self.db.global.AnchorSide == "RIGHT") then
		FlashTalentFrameTalents:ClearAllPoints();
		FlashTalentFrameTalents:SetPoint("TOPLEFT", FlashTalentFrame, "TOPLEFT", 0, -22);
		
		FlashTalentFrameTabs:ClearAllPoints();
		FlashTalentFrameTabs:SetPoint("TOPLEFT", FlashTalentFrameTalents, "TOPRIGHT", 2, 0);
		
		FlashTalentFrameSettingsButton:SetPoint("BOTTOM", FlashTalentFrameTabs, "BOTTOM", -6, -3);
		
	elseif(self.db.global.AnchorSide == "LEFT") then
		FlashTalentFrameTalents:ClearAllPoints();
		FlashTalentFrameTalents:SetPoint("TOPRIGHT", FlashTalentFrame, "TOPRIGHT", 0, -22);
		
		FlashTalentFrameTabs:ClearAllPoints();
		FlashTalentFrameTabs:SetPoint("TOPRIGHT", FlashTalentFrameTalents, "TOPLEFT", -2, 0);
		
		FlashTalentFrameSettingsButton:SetPoint("BOTTOM", FlashTalentFrameTabs, "BOTTOM", 7, -3);
	end
	
	FlashTalentFrame:SetScale(self.db.global.WindowScale);
	Addon:UpdateFonts();
end

function FlashTalentFrame_OnShow(self)
	Addon.db.global.IsWindowOpen = true;
end

function FlashTalentFrame_OnHide(self)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible()) then
		LibQTip:Release(FlashTalentSpecButton.tooltip);
		FlashTalentSpecButton.tooltip = nil;
	end
	
	Addon.db.global.IsWindowOpen = false;
end

function FlashTalentFrame_OnMouseDown(self)
	if(IsAltKeyDown()) then
		FlashTalentFrame:StartMoving();
		FlashTalentFrame.isMoving = true;
		FlashTalentFrame.wasMoved = true;
	end
end

function FlashTalentFrame_OnMouseUp(self)
	if(FlashTalentFrame.isMoving) then
		FlashTalentFrame:StopMovingOrSizing();
		FlashTalentFrame.isMoving = false;
		Addon:SavePosition();
	end
end

function Addon:PLAYER_REGEN_DISABLED()
	if(not self.db.global.StickyWindow) then
		FlashTalentFrame:Hide();
	end
end

function Addon:PLAYER_REGEN_ENABLED()
	if(not Addon.SecureFrameToggler) then
		Addon:SetupSecureFrameToggler();
	end
end

----------------------------------------------------------
-- Tab buttons

function Addon:OpenTalentTab(tabIndex)
	if(tabIndex ~= CLASS_TALENTS_TAB and tabIndex ~= HONOR_TALENTS_TAB) then return end
	
	if(tabIndex == HONOR_TALENTS_TAB and UnitLevel("player") < SHOW_PVP_TALENT_LEVEL) then
		tabIndex = CLASS_TALENTS_TAB;
	end
	
	Addon.CurrentTalentTab = tabIndex;
	Addon.db.char.OpenTalentTab = Addon.CurrentTalentTab;
	
	Addon:UpdateTabIcons();
	Addon:UpdateTalentFrame();
end

function FlashTalentTabButton_OnClick(self, button)
	if(self.disabled) then return end
	if(InCombatLockdown()) then return end
	
	if(not IsAddOnLoaded("Blizzard_TalentUI")) then
		LoadAddOn("Blizzard_TalentUI");
	end
	
	local tabIndex = self:GetID();
	
	if(button == "LeftButton") then
		Addon:OpenTalentTab(tabIndex); 
	elseif(button == "RightButton") then
		if(not PlayerTalentFrame:IsVisible()) then
			ShowUIPanel(PlayerTalentFrame);
		end
		
		if(tabIndex == CLASS_TALENTS_TAB) then
			PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab" .. TALENTS_TAB]);
		elseif(tabIndex == HONOR_TALENTS_TAB) then
			PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab" .. PVP_TALENTS_TAB]);
		end
	end
end
	
function FlashTalentTabButton_OnEnter(self)
	if(not self.disabled) then
		self.iconFrameHover:Show();
	end
	
	Addon:HideSpecButtonTooltip();
	
	local level = UnitLevel("player");
	
	local tabID = self:GetID();
	GameTooltip:SetOwner(self, "ANCHOR_" .. Addon.db.global.AnchorSide);
	
	if(tabID == CLASS_TALENTS_TAB) then -- PVE tab
		GameTooltip:AddLine("Class Talents");
		
		if(level >= SHOW_TALENT_LEVEL) then
			GameTooltip:AddLine("|cffffffffView class talents.");
			GameTooltip:AddLine("|cff00ff00Right click|r  Open talent panel.");
		
			if(GetNumUnspentTalents() > 0) then
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(string.format("%d unspent talent point%s.", GetNumUnspentTalents(), GetNumUnspentTalents() == 1 and "" or "s"));
			end
		else
			GameTooltip:AddLine(string.format("|cffffffffClass talents unlock at level %d.", SHOW_TALENT_LEVEL));
		end
		
	elseif(tabID == HONOR_TALENTS_TAB) then -- PVP Tab
		GameTooltip:AddLine("Honor Talents");
		
		if(level >= SHOW_PVP_TALENT_LEVEL) then
			GameTooltip:AddLine("|cffffffffView honor talents.|r");
			GameTooltip:AddLine("|cff00ff00Right click|r  Open talent panel.");
			
			GameTooltip:AddLine(" ");
			
			local honorlevel = UnitHonorLevel("player");
			local honorlevelmax = GetMaxPlayerHonorLevel();
			
			if(honorlevel < honorlevelmax) then
				GameTooltip:AddLine(string.format("Honor Level  |cffffffff%d / %d|r", honorlevel, honorlevelmax));
			else
				GameTooltip:AddLine("Max Honor Level Reached!");
			end
			
			if(CanPrestige()) then
				GameTooltip:AddLine("|cff22ccffPrestige available!|r");
			end
			
			if(GetNumUnspentPvpTalents() > 0) then
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(string.format("%d unspent talent point%s.", GetNumUnspentPvpTalents(), GetNumUnspentPvpTalents() == 1 and "" or "s"));
			end
		else
			GameTooltip:AddLine(string.format("|cffffffffHonor talents unlock at level %d.", SHOW_PVP_TALENT_LEVEL));
		end
	end
	
	GameTooltip:Show();
end

function FlashTalentTabButton_OnLeave(self)
	self.iconFrameHover:Hide();
	GameTooltip:Hide();
end

function Addon:UpdateTabIcons()
	local level = UnitLevel("player");
	
	-- Class tab
	local pvetab = FlashTalentFrameTabs.pvetalents;
	
	if(level >= SHOW_SPEC_LEVEL) then
		local _, _, _, icon = GetSpecializationInfo(GetSpecialization());
		SetPortraitToTexture(pvetab.icon, icon);
		pvetab.icon:SetTexCoord(0, 1, 0, 1);
	else
		local _, class = UnitClass("player");
		pvetab.icon:SetTexture("Interface\\TargetingFrame\\UI-classes-Circles");
		pvetab.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[strupper(class)]));
	end
	
	if(level < SHOW_SPEC_LEVEL) then
		pvetab.disabled = true;
	else
		pvetab.disabled = false;
	end
	pvetab.icon:SetDesaturated(pvetab.disabled);
	pvetab.iconFrame:SetDesaturated(pvetab.disabled);
	
	if(GetNumUnspentTalents() > 0) then
		pvetab.text:Show();
		pvetab.text:SetText(GetNumUnspentTalents());
	else
		pvetab.text:Hide();
	end
	
	if(Addon.CurrentTalentTab == CLASS_TALENTS_TAB) then
		pvetab.iconFrameGlow:Show();
	else
		pvetab.iconFrameGlow:Hide();
	end
	
	-- Honor tab
	local pvptab = FlashTalentFrameTabs.pvptalents;
	
	local faction = UnitFactionGroup("player");
	if(faction ~= "Neutral") then
		SetPortraitToTexture(pvptab.icon, "Interface\\Icons\\PVPCurrency-Conquest-" .. faction);
	else
		SetPortraitToTexture(pvptab.icon, "Interface\\Icons\\INV_Staff_2H_PandarenMonk_C_01");
	end
	
	if(level < SHOW_PVP_TALENT_LEVEL) then
		pvptab.disabled = true;
	else
		pvptab.disabled = false;
	end
	pvptab.icon:SetDesaturated(pvptab.disabled);
	pvptab.iconFrame:SetDesaturated(pvptab.disabled);
	
	if(GetNumUnspentPvpTalents() > 0) then
		pvptab.text:Show();
		pvptab.text:SetText(GetNumUnspentPvpTalents());
	else
		pvptab.text:Hide();
	end
	
	if(Addon.CurrentTalentTab == HONOR_TALENTS_TAB) then
		pvptab.iconFrameGlow:Show();
	else
		pvptab.iconFrameGlow:Hide();
	end
end

----------------------------------------------------------
-- Challenge mode restriction

-- function Addon:HasChallengeModeRestriction()
-- 	return C_ChallengeMode.IsChallengeModeActive() and self.ChallengeModeActive;
-- end

-- function Addon:SCENARIO_UPDATE()
-- 	if(not self.ChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
-- 		Addon:CHALLENGE_MODE_START();
-- 	end
-- end

-- function Addon:CHALLENGE_MODE_START()
-- 	self.ChallengeModeActive = true;
-- 	Addon:UpdateTalentFrame();
-- end

-- function Addon:CHALLENGE_MODE_RESET()
-- 	self.ChallengeModeActive = false;
-- 	Addon:UpdateTalentFrame();
-- end

----------------------------------------------------------
-- Miscellaneous update events

function Addon:BAG_UPDATE_DELAYED()
	if(InCombatLockdown()) then return end
	Addon:UpdateReagentCount()
end

function Addon:PLAYER_UPDATE_RESTING()
	if(InCombatLockdown()) then return end
	Addon:UpdateReagentCount()
end

function Addon:UNIT_AURA()
	if(InCombatLockdown()) then return end
	Addon:UpdateReagentCount();
end

function Addon:UNIT_PET()
	Addon:UpdateSpecTooltips();
end

function Addon:PLAYER_TALENT_UPDATE()
	if(InCombatLockdown()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateTabIcons();
	Addon:UpdateDatabrokerText();
end

function Addon:PLAYER_LEVEL_UP()
	if(InCombatLockdown()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateTabIcons();
	Addon:UpdateDatabrokerText();
end

function Addon:NEUTRAL_FACTION_SELECT_RESULT()
	Addon:UpdateTabIcons();
	Addon:UnregisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
end

-------------------------------------------------------
-- Talent buttons

function FlashTalentButtonTemplate_OnClick(self)
	if(FlashTalentFrame.isMoving or FlashTalentFrame.wasMoved) then
		FlashTalentFrame.wasMoved = false;
		return;
	end
	
	if(self.isUnlocked and self.talentID) then
		if(self.talentCategory == TALENT_CLASS) then
			LearnTalent(self.talentID);
		elseif(self.talentCategory == TALENT_HONOR) then
			LearnPvpTalent(self.talentID);
		end
	end
end

function FlashTalentButtonTemplate_OnDragStart(self)
	if(InCombatLockdown() or not self.isSelected) then return end
	
	if(not IsAltKeyDown()) then
		if(self.talentCategory == TALENT_CLASS) then
			PickupTalent(self.talentID);
		elseif(self.talentCategory == TALENT_HONOR) then
			PickupPvpTalent(self.talentID);
		end
	end
end

-------------------------------------------------------
-- Talent cooldowns

function Addon:UpdateTalentCooldowns()
	if(Addon.CurrentTalentTab == 1) then
		Addon:UpdatePVETalentCooldowns();
	elseif(Addon.CurrentTalentTab == 2) then
		Addon:UpdatePVPTalentCooldowns();
	end
end

function Addon:UpdatePVETalentCooldowns()
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	local tierLevels = CLASS_TALENT_LEVELS[playerClass] or CLASS_TALENT_LEVELS.DEFAULT;
	
	for tier = 1, 7 do
		local tierIsOnCooldown = false;
		
		local tierFrame = _G[string.format("FlashTalentFrameTalentsTier%d", tier)];
		
		local isUnlocked = (playerLevel >= tierLevels[tier]);
		if(not isUnlocked) then
			break;
		else
			tierFrame.lockFade:Hide();
		end
		
		for column = 1, 3 do
			local talentID, spellName, icon, isSelected = GetTalentInfo(tier, column, group);
			-- local isFree, selection = GetTalentTierInfo(tier, group);
			
			if(isSelected) then
				local start, duration, enable = GetSpellCooldown(spellName);
				
				if(start and duration and start > 0 and duration > 0) then
					local remaining = start + duration - GetTime();
					
					tierFrame.lockFade:Show();
					
					if(enable == 1) then
						tierFrame.lockFade.levelText:SetText(Addon:FormatTime(remaining));
					else
						tierFrame.lockFade.levelText:SetText("--");
					end
					
					tierIsOnCooldown = true;
					
					tierFrame.isOnCooldown = true;
					tierFrame.spellCooldown = spellName;
					tierFrame.remaining = remaining;
				end
				
				break;
			end
		end
		
		if(not tierIsOnCooldown) then
			tierFrame.isOnCooldown = false;
			tierFrame.spellCooldown = nil;
			tierFrame.remaining = 0;
		end
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			if(not tierIsOnCooldown) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
			end
			
			button.isOnCooldown = tierFrame.isOnCooldown;
			button.spellCooldown = tierFrame.spellCooldown;
			button.remaining = tierFrame.remaining;
		end
	end
end

function Addon:UpdatePVPTalentCooldowns()
	local group = GetActiveSpecGroup();
	
	local honorLevel = UnitHonorLevel("player");
	
	for tier = 2, 7 do
		local tierIsOnCooldown = false;
		
		local tierFrame = _G[string.format("FlashTalentFrameTalentsTier%d", tier)];
		
		tierFrame.lockFade:Hide();
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			if(button and not button.isUnlocked) then return end
			
			local talentID, spellName, icon, isSelected = GetPvpTalentInfo(tier-1, column, group);
			
			if(isSelected) then
				local start, duration, enable = GetSpellCooldown(spellName);
				
				if(start and duration and start > 0 and duration > 0) then
					local remaining = start + duration - GetTime();
					
					button.text:Show();
					button.text:SetText(Addon:FormatTime(remaining));
					
					tierIsOnCooldown = true;
					tierFrame.isOnCooldown = true;
					tierFrame.spellCooldown = spellName;
					tierFrame.remaining = remaining;
				end
			end
		end
		
		if(not tierIsOnCooldown) then
			tierFrame.isOnCooldown = false;
			tierFrame.spellCooldown = nil;
			tierFrame.remaining = 0;
		end
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			if(not button.isUnlocked) then return end
			
			if(not tierIsOnCooldown) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
			end
			
			button.isOnCooldown = tierFrame.isOnCooldown;
			button.spellCooldown = tierFrame.spellCooldown;
			button.remaining = tierFrame.remaining;
		end
	end
end

function Addon:SPELL_UPDATE_USABLE()
	Addon:UpdateTalentCooldowns();
end

------------------------------------------------------
-- Update talents

function Addon:UpdateTalentFrame()
	if(InCombatLockdown()) then return end
	
	if(Addon.CurrentTalentTab == 1) then
		Addon:UpdatePVETalentFrame();
	elseif(Addon.CurrentTalentTab == 2) then
		Addon:UpdatePVPTalentFrame();
	end
	
	Addon:UpdateReagentCount();
end

function Addon:UpdatePVETalentFrame()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrameTalentsTier1:Show();
	FlashTalentFrameTalentsHonorLevel:Hide();
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	local tierLevels = CLASS_TALENT_LEVELS[playerClass] or CLASS_TALENT_LEVELS.DEFAULT;
	
	for tier = 1, 7 do
		Addon:HighlightTalent(tier, -1);
		
		local tierFrame = _G[string.format("FlashTalentFrameTalentsTier%d", tier)];
		tierFrame.glowFrame:Hide();
		
		local isUnlocked = (playerLevel >= tierLevels[tier]);
		if(not isUnlocked) then
			tierFrame.lockFade.levelText:SetText(tierLevels[tier]);
			tierFrame.lockFade:Show();
		else
			tierFrame.lockFade:Hide();
		end
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			
			button.text:Hide();
			
			local talentID, spellName, icon, isSelected, available, spellID = GetTalentInfo(tier, column, group);
			local tierAvailable, selection = GetTalentTierInfo(tier, group);
			local isFree = (selection == 0);
			
			if(isSelected) then
				Addon:HighlightTalent(tier, column);
			elseif(isUnlocked and talentID and isFree) then
				IconSetColor(button.icon, TALENT_COLOR_CANLEARN);
			end
			
			if(isFree and isUnlocked) then
				tierFrame.glowFrame:Show();
			end
			
			button.tier             = tier;
			button.column           = column;
			
			button.talentID         = talentID;
			button.talentCategory   = TALENT_CLASS;
			button.isSelected       = isSelected;
			button.spellName        = spellName;
			
			button.tierFree         = isFree;
			button.isUnlocked       = isUnlocked;
			
			button.icon:SetTexture(icon);
			
			if(isUnlocked) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
			end
		end
	end
end

function Addon:IsPVPTalentUnlocked(honorLevel, row, column)
	return honorLevel >= PVP_TALENT_LEVELS[row][column], PVP_TALENT_LEVELS[row][column];
end

function Addon:UpdatePVPTalentFrame()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrameTalentsTier1:Hide();
	Addon:UpdatePVPXPBar();
	
	local honorLevel = UnitHonorLevel("player");
	
	FlashTalentFrameTalentsHonorLevel.label.text:SetText(string.format("|cffffd200Level|r %s", honorLevel));
	FlashTalentFrameTalentsHonorLevel:Show();
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	for tier = 2, 7 do
		Addon:HighlightTalent(tier, -1, true);
		
		local tierFrame = _G[string.format("FlashTalentFrameTalentsTier%d", tier)];
		tierFrame.glowFrame:Hide();
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			
			local isUnlocked, unlockLevel = Addon:IsPVPTalentUnlocked(honorLevel, tier-1, column);
			
			local talentID, spellName, icon, isSelected, available, spellID = GetPvpTalentInfo(tier-1, column, group);
			local isRowFree = GetPvpTalentRowSelectionInfo(tier-1);
			
			if(isSelected) then
				Addon:HighlightTalent(tier, column);
			elseif(isUnlocked and talentID and isRowFree) then
				button.icon:SetVertexColor(0.6, 0.6, 0.6);
			end
			
			button.tier             = tier;
			button.column           = column;
			
			button.talentID         = talentID;
			button.talentCategory   = TALENT_HONOR;
			button.isSelected       = isSelected;
			button.spellName        = spellName;
			
			button.tierFree         = isFree;
			button.isUnlocked       = isUnlocked;
			
			button.icon:SetTexture(icon);
			
			if(isUnlocked) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
				button.text:SetText(string.format("|cffff2222%d|r", unlockLevel));
				button.text:Show();
			end
		end
	end
end

function Addon:UpdatePVPXPBar()
	local _, class = UnitClass("player");
	local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class];
	
	FlashTalentFrameTalentsHonorLevel.XPBarBackground:SetStatusBarColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.6);
	FlashTalentFrameTalentsHonorLevel.XPBar:SetStatusBarColor(color.r, color.g, color.b, 0.8);
	FlashTalentFrameTalentsHonorLevel.XPBarColor:SetStatusBarColor(color.r, color.g, color.b, 0.35);
	
	local honor     = UnitHonor("player");
	local honorMax  = UnitHonorMax("player");
	
	FlashTalentFrameTalentsHonorLevel.XPBar:SetMinMaxValues(0, honorMax);
	FlashTalentFrameTalentsHonorLevel.XPBar:SetValue(honor);
	FlashTalentFrameTalentsHonorLevel.XPBar:Show();
	
	FlashTalentFrameTalentsHonorLevel.XPBarColor:SetMinMaxValues(0, honorMax);
	FlashTalentFrameTalentsHonorLevel.XPBarColor:SetValue(honor);
	FlashTalentFrameTalentsHonorLevel.XPBarColor:Show();
end

local function rgba2hex(r, g, b, a)
	r = r or 1;
	g = g or 1;
	b = b or 1;
	a = a or 1;
	return string.format("%02x%02x%02x%02x", a * 255, r * 255, g * 255, b * 255);
end

function Addon:CopyGameTooltip()
	local tooltip = {};
	
	for index = 1, GameTooltip:NumLines() do
		local left = _G["GameTooltipTextLeft" .. index];
		local right = _G["GameTooltipTextRight" .. index];
		
		local leftText, rightText;
		
		if(left and left:GetText()) then
			leftText = string.format("|c%s%s|r", rgba2hex(left:GetTextColor()), left:GetText());
		end
		
		if(right and right:GetText()) then
			rightText = string.format("|c%s%s|r", rgba2hex(right:GetTextColor()), right:GetText());
		end
		
		tinsert(tooltip, {
			left = leftText,
			right = rightText,
		});
	end
	
	return tooltip;
end

function FlashTalentFrameHonorLevel_OnEnter(self)
	if(TipTac and TipTac.AddModifiedTip and not self.tiptacAdded) then
		self.tiptacAdded = true;
		TipTac:AddModifiedTip(FlashTalentExtraTooltip);
	end
	
	self.tooltip = FlashTalentExtraTooltip;
	
	local reward = PVPHonorSystem_GetNextReward();
	
	local level     = UnitHonorLevel("player");
	local prestige  = UnitPrestige("player")+4;
	local honor     = UnitHonor("player");
	local honorMax  = UnitHonorMax("player");
	
	self.label.text:SetText(string.format("%d / %d", honor, honorMax, honor / honorMax * 100));
	
	self.tooltip:ClearLines();
	self.tooltip:ClearAllPoints();
	self.tooltip:SetOwner(self, "ANCHOR_NONE");
	
	if(Addon.db.global.AnchorSide == "RIGHT") then
		self.tooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, 2);
	elseif(Addon.db.global.AnchorSide == "LEFT") then
		self.tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 2);
	end
	
	local prestigeText = "";
	
	if(prestige > 0) then
		prestigeText = string.format("|cffffd200Prestige|r %d", prestige);
	end
	
	self.tooltip:AddDoubleLine(
		string.format("|cffffd200Honor Level|r %d", level), prestigeText, 1, 1, 1, 1, 1, 1
	);
	
	self.tooltip:AddLine(" ");
	
	self.tooltip:AddLine(string.format("|cffffd200Current progress|r %d / %d |cffdddddd(%0.1f%%)|r", honor, honorMax, honor / honorMax * 100), 1, 1, 1, true);
	
	if(honor < honorMax and not CanPrestige()) then
		self.tooltip:AddLine(string.format("%d honor to next level", honorMax - honor), 1, 1, 1, true);
	elseif(tCanPrestige()) then
		self.tooltip:AddLine("|cffffd200Prestige available!|r", 1, 1, 1, true);
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:ClearAllPoints();
	
	if(Addon.db.global.AnchorSide == "RIGHT") then
		GameTooltip:SetPoint("TOPRIGHT", self.tooltip, "BOTTOMRIGHT", 0, 0);
	elseif(Addon.db.global.AnchorSide == "LEFT") then
		GameTooltip:SetPoint("TOPLEFT", self.tooltip, "BOTTOMLEFT", 0, 0);
	end
	
	reward:SetTooltip();
	
	if(GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()) then
		GameTooltipTextLeft1:SetText("|cffffd200Next Reward|r|n|n" .. GameTooltipTextLeft1:GetText());
	end
	
	GameTooltip:Show();
	
	-- Hide TipTac icon
	if(GameTooltip.ttIcon) then
		GameTooltip.ttIcon:Hide();
	end
	
	-- Super pretty hack to get the tooltip exactly as wide as gametooltip without having wonky text
	self.tooltip:SetMinimumWidth(GameTooltip:GetWidth());
	self.tooltip:Show();
	self.tooltip:SetMinimumWidth(GameTooltip:GetWidth() - (self.tooltip:GetWidth() - GameTooltip:GetWidth()));
	self.tooltip:Show();
end

function FlashTalentFrameHonorLevel_OnLeave(self)
	GameTooltip:Hide();
	self.tooltip:Hide();
	
	if(Addon.db.global.AnchorSide == "LEFT" and GameTooltip.ttIcon) then
		GameTooltip.ttIcon:Show();
	end
	
	local honorLevel = UnitHonorLevel("player");
	self.label.text:SetText(string.format("|cffffd200Level|r %s", honorLevel));
end

function Addon:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTalentsTier%dTalent%d", highlightTier, column);
		local button = _G[buttonName];
		
		if(button) then
			if(column == highlightColumn) then
				IconSetColor(button.icon, TALENT_COLOR_SELECTED);
			else
				IconSetColor(button.icon, TALENT_COLOR_LOCKED);
			end
		end
	end
end

function FlashTalentButtonTemplate_OnEnter(self)
	if(self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN_HOVER);
	elseif(not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED_HOVER);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED_HOVER);
	end
	
	if(IsShiftKeyDown() or Addon.db.global.AlwaysShowTooltip) then
		Addon:SetTalentTooltip(self);
	end
	
	Addon:HideSpecButtonTooltip();
	
	Addon.HoveredTalent = self;
end

function FlashTalentButtonTemplate_OnLeave(self)
	if(self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN);
	elseif(not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED);
	end
	
	GameTooltip:Hide();
	
	Addon.HoveredTalent = nil;
end

function Addon:MODIFIER_STATE_CHANGED(event, key, state)
	if(InCombatLockdown()) then return end
	
	if(not Addon.HoveredTalent) then return end
	
	if(key == "LSHIFT" or key == "RSHIFT") then
		if(state == 1) then
			if(Addon.HoveredTalent) then
				Addon:SetTalentTooltip(Addon.HoveredTalent);
			end
		elseif(not Addon.db.global.AlwaysShowTooltip) then
			GameTooltip:Hide();
		end
	end
end

function Addon:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTalentsTier%dTalent%d", highlightTier, column);
		local button = _G[buttonName];
		
		if(button) then
			if(column == highlightColumn) then
				IconSetColor(button.icon, TALENT_COLOR_SELECTED);
			else
				IconSetColor(button.icon, TALENT_COLOR_LOCKED);
			end
		end
	end
end

function FlashTalentButtonTemplate_OnEnter(self)
	if(self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN_HOVER);
	elseif(not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED_HOVER);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED_HOVER);
	end
	
	if(IsShiftKeyDown() or Addon.db.global.AlwaysShowTooltip) then
		Addon:SetTalentTooltip(self);
	end
	
	Addon:HideSpecButtonTooltip();
	
	Addon.HoveredTalent = self;
end

function FlashTalentButtonTemplate_OnLeave(self)
	if(self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN);
	elseif(not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED);
	end
	
	GameTooltip:Hide();
	
	Addon.HoveredTalent = nil;
end

function Addon:MODIFIER_STATE_CHANGED(event, key, state)
	if(InCombatLockdown()) then return end
	
	if(not Addon.HoveredTalent) then return end
	
	if(key == "LSHIFT" or key == "RSHIFT") then
		if(state == 1) then
			if(Addon.HoveredTalent) then
				Addon:SetTalentTooltip(Addon.HoveredTalent);
			end
		elseif(not Addon.db.global.AlwaysShowTooltip) then
			GameTooltip:Hide();
		end
	end
end

-------------------------------------------------------
-- Reagents

function Addon:GetTalentClearInfo()
	local level = UnitLevel("player");
	local selection = math.floor( (UnitLevel("player")-1) / 100 ) + 1;
	
	local info = {};
	for _, itemID in ipairs(TALENT_CLEAR_ITEMS[selection]) do
		tinsert(info, {
			itemID, GetItemCount(itemID), GetItemIcon(itemID),
		});
	end
	
	return info;
end

function Addon:UpdateReagentCount()
	local canChange, remainingTime = Addon:CanChangeTalents();
	if(canChange and remainingTime) then
		FlashTalentFrameReagents.text:SetText(string.format("|cff77ff00%s|r", Addon:FormatTime(remainingTime)));
		return;
	end
	
	local reagents = Addon:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
	
	if(reagentIcon) then
		local textPattern = "%s %d";
		if(canChange) then
			textPattern = "%s |cff77ff00%d|r";
		elseif(reagentCount == 0) then
			textPattern = "%s |cffff5511%d|r";
		end
		
		FlashTalentFrameReagents.text:SetFormattedText(textPattern, FLASHTALENT_ICON_PATTERN_NOBORDER:format(reagentIcon), reagentCount);
	else
		FlashTalentFrameReagents.text:SetText("");
	end
	
	if(InCombatLockdown()) then return end
	if(not canChange) then
		FlashTalentFrameReagents:SetAttribute("type1", "item");
		FlashTalentFrameReagents:SetAttribute("item1", GetItemInfo(unpack(reagents[1])));
		
		FlashTalentFrameReagents:SetAttribute("type2", "item");
		FlashTalentFrameReagents:SetAttribute("item2", GetItemInfo(unpack(reagents[2])));
	else
		FlashTalentFrameReagents:SetAttribute("item1", "");
		FlashTalentFrameReagents:SetAttribute("item2", "");
	end
end

function FlashTalentReagentFrame_OnEnter(self)
	Addon:HideSpecButtonTooltip();
	
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", -2, 0);
	
	GameTooltip:AddLine("Tomes and Codices");
	
	GameTooltip:AddLine("|cff80bcffTo change talents while not resting you must first use either a tome or a codex.|r", nil, nil, nil, true);
	GameTooltip:AddLine(" ");
	
	local canChange, remainingTime = Addon:CanChangeTalents();
	if(not canChange) then
		GameTooltip:AddLine("|cffff953fCurrently you are unable to change talents without using one of the items.|r", nil, nil, nil, true);
	elseif(canChange and not remainingTime) then
		GameTooltip:AddLine("|cffa2ed12You are able to change talents for free at this moment.|r", nil, nil, nil, true);
	elseif(canChange and remainingTime) then
		GameTooltip:AddLine("|cffa2ed12You are able to change talents at this moment.|r", nil, nil, nil, true);
	end
	
	GameTooltip:AddLine(" ");
	
	local clicks = {
		"Left click", "Right click"
	};
	
	local reagents = Addon:GetTalentClearInfo();
	for index, data in ipairs(reagents) do
		local itemID, count, icon = unpack(data);
		local name, link, quality = GetItemInfo(itemID);
		
		GameTooltip:AddDoubleLine(
			string.format("%s |cffffffff%dx|r %s", FLASHTALENT_ICON_PATTERN:format(icon), count, name),
			string.format("|cff00ff00%s to use|r", clicks[index])
		);
	end
	
	if(remainingTime) then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(string.format("|cffffd200You have |cff77ff00%s|cffffd200 to change talents.|r", Addon:FormatTime(remainingTime)));
	end
	
	GameTooltip:Show();
	self.tooltipOpen = true;
end

function FlashTalentReagentFrame_OnLeave(self)
	GameTooltip:Hide();
	self.tooltipOpen = false;
end

function FlashTalentReagentFrame_PreClick(self, button)
	if(InCombatLockdown()) then return end
	
	local index;
	if(button == "LeftButton") then
		index = 1;
	elseif(button == "RightButton") then
		index = 2;
	else
		return;
	end
	
	local reagents = Addon:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[index]);
	local name = GetItemInfo(reagentID);
	
	if(reagentCount and reagentCount == 0) then
		UIErrorsFrame:AddMessage(ITEM_MISSING:format(name), 1.0, 0.1, 0.1, 1.0);
	end
end
