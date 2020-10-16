------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

HONOR_TALENT_UNLOCK_LEVEL = 50;

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = Addon;

local _;

local LibQTip = LibStub("LibQTip-1.0");

local TALENT_PVE = 1;
local TALENT_PVP = 2;

local TALENT_COLOR_LOCKED           = { 0.3, 0.3, 0.3 };
local TALENT_COLOR_LOCKED_HOVER     = { 0.45, 0.45, 0.45 };

local TALENT_COLOR_INUSE            = { 0.4, 0.4, 0.4 };
local TALENT_COLOR_INUSE_HOVER      = { 0.8, 0.8, 0.8 };

local TALENT_COLOR_CANLEARN         = { 0.82, 0.82, 0.82 };
local TALENT_COLOR_CANLEARN_HOVER   = { 1.0, 1.0, 1.0 };

local TALENT_COLOR_SELECTED         = { 0.9, 0.9, 0.9 };
local TALENT_COLOR_SELECTED_HOVER   = { 1.0, 1.0, 1.0 };

local function IconSetColor(frame, color)
	if (not frame or not color) then return end
	frame:SetVertexColor(unpack(color));
end

local TALENT_CLEAR_ITEMS = {
	{
		-- Under or at lvl 49 items
		{
			141640, -- Tome of Clear Mind
			153647, -- Tome of Quiet Mind
			141446, -- Tome of Tranquil Mind
		},
		{
			141333, -- Codex of Tranquil Mind
			141641, -- Codex of Clear Mind
			153646, -- Codex of Quiet Mind
		}
	},
	{
		-- Lvl 50
		{
			141640, -- Tome of Clear Mind
			153647, -- Tome of Quiet Mind
			141446, -- Tome of Tranquil Mind
		},
		{
			141333, -- Codex of Tranquil Mind
			153646, -- Codex of Quiet Mind
		}
	},
};
	
local TALENT_CLEAR_BUFFS = {
	{ id = 227565, },            -- Codex of Clear Mind (100) 
	{ id = 226234, },            -- Codex of Tranquil Mind (110)
	{ id = 256229, },            -- Codex of Quiet Mind
	
	{ id = 227563, lvl = 49 },   -- Tome of Clear Mind (109)
	{ id = 227041 },             -- Tome of Tranquil Mind (110)
	{ id = 256231 },             -- Tome of Quiet Mind
};

SLASH_FLASHTALENT1	= "/flashtalent";
SLASH_FLASHTALENT2	= "/ft";
SlashCmdList["FLASHTALENT"] = function(params)
	local tab = strsplit(" ", strtrim(params));
	Addon:ToggleFrame(T or nil);
end

function Addon:OnEnable()
	Addon:SetupSecureFrameToggler();
	
	Addon:UpdateFrame();
	Addon:UpdateTalentFrame();
	
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	Addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	Addon:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	Addon:RegisterEvent("PET_SPECIALIZATION_CHANGED");
	
	Addon:RegisterEvent("PLAYER_TALENT_UPDATE");
	Addon:RegisterEvent("PLAYER_PVP_TALENT_UPDATE", "PLAYER_TALENT_UPDATE");
	Addon:RegisterEvent("WAR_MODE_STATUS_UPDATE", "PLAYER_TALENT_UPDATE");
	Addon:RegisterEvent("PLAYER_FLAGS_CHANGED"); -- For war mode change
	
	Addon:RegisterEvent("PLAYER_LEVEL_UP");
	
	if (select(2, UnitClass("player")) == "HUNTER") then
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
	
	if (not self.db.global.StickyWindow) then
		tinsert(UISpecialFrames, "FlashTalentFrame");
	end
	
	tinsert(UISpecialFrames, "FlashPvpTalentChangeFrame");
	
	if (not Addon:IsBindingSet() and not Addon:HasAskedBinding()) then
		StaticPopup_Show("FLASHTALENT_NO_KEYBIND");
	end
	
	hooksecurefunc("SetSpecialization", function(newSpec)
		if (GetSpecialization() and GetSpecialization() ~= newSpec) then
			Addon.OldSpecialization = GetSpecialization();
		end
	end);
	
	-- if (C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
	-- 	Addon:CHALLENGE_MODE_START();
	-- end
	
	Addon:InitializeDatabroker();
end

function Addon:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	if (self.elapsed > 0.1) then
		Addon:UpdateTalentCooldowns();
		self.elapsed = 0;
		
		if (FlashTalentFrameReagents and FlashTalentFrameReagents.tooltipOpen) then
			FlashTalentReagentFrame_OnEnter(FlashTalentFrameReagents);
		end
		
		local canChange, remainingTime = Addon:CanChangeTalents();
		if (canChange and remainingTime) then
			Addon:UpdateReagentCount();
		end
	end
	
	if (Addon.db and Addon.db.global.HideBlizzAlert) then
		TalentMicroButtonAlert:Hide();
	end
end

function Addon:SetupSecureFrameToggler()
	if (InCombatLockdown()) then return end
	
	if (not Addon.SecureFrameToggler) then
		Addon.SecureFrameToggler = CreateFrame("Button", "FlashTalentFrameToggler", nil, "SecureActionButtonTemplate");
	end
	
	Addon.SecureFrameToggler:SetAttribute("type1", "macro");
	Addon.SecureFrameToggler:SetAttribute("macrotext1",
		"/flashtalent"
	);
end

---------------------------------------------------------------
-- Utility functions

function Addon:FormatTime(seconds)
	if (seconds > 60) then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60);
	elseif (seconds > 3) then
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

local function UnitAuraByNameOrId(unit, aura_name_or_id, filter)
	for index = 1, 40 do
		local name, _, _, _, _, _, _, _, _, spell_id = UnitAura(unit, index, filter);
		if (name == aura_name_or_id or spell_id == aura_name_or_id) then
			return UnitAura(unit, index, filter);
		end
	end
	return nil;
end

function Addon:UnitHasBuff(unit, spell)
	if (not unit or not spell) then return false end
	
	local realSpellID = Addon:GetRealSpellID(spell);
	if (not realSpellID) then return false end
	
	local name, _, _, _, duration, expirationTime, unitCaster = UnitAuraByNameOrId(unit, realSpellID, "HELPFUL");
	if (not name) then
		return false;
	end
	
	return true, math.max(0, tonumber(expirationTime) - GetTime());
end

function Addon:PlayerHasPreparation()
	local buffs = { 32727, 44521, 228128, };
	for _, spellid in ipairs(buffs) do
		local hasBuff = Addon:UnitHasBuff("player", spellid);
		if (hasBuff) then
			return true;
		end
	end
	
	return false;
end

function Addon:CanChangeTalents()
	if (InCombatLockdown()) then return false end
	if (IsResting()) then return true end
	if (Addon:PlayerHasPreparation()) then return true end
	
	local level = UnitLevel("player");
	
	for _, data in ipairs(TALENT_CLEAR_BUFFS) do
		if (not data.lvl or (data.lvl and level <= data.lvl)) then
			local hasBuff, remaining = Addon:UnitHasBuff("player", data.id);
			if (hasBuff) then
				return true, remaining;
			end
		end
	end
	
	return false;
end

function Addon:AddScriptedTooltipLine(tooltip, text, onClick, onEnter, onLeave)
	local lineIndex;
	if (type(text) == "table") then
		lineIndex = tooltip:AddLine(unpack(text));
	else
		lineIndex = tooltip:AddLine(text);
	end
	
	if (onEnter) then tooltip:SetLineScript(lineIndex, "OnEnter", onEnter); end
	if (onLeave) then tooltip:SetLineScript(lineIndex, "OnLeave", onLeave); end
	if (onClick) then tooltip:SetLineScript(lineIndex, "OnMouseUp", onClick); end
	
	return lineIndex;
end

function Addon:GetSpecializationInfoBySpecName(specName)
	local assignedSpecs = {};
	local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
	if (equipmentSetIDs) then
		for index, setID in ipairs(equipmentSetIDs) do
			local assignedSpecID = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID);
			if (assignedSpecID) then
				assignedSpecs[assignedSpecID] = true;
			end
		end
	end
	
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, role, primaryStat = GetSpecializationInfo(specIndex, nil, nil, nil, UnitSex("player"));
		if (not assignedSpecs[specIndex] and name == specName) then
			return id, name, description, icon, role, primaryStat;
		end
	end
end

function Addon:SetTalentTooltip(talentButton)
	GameTooltip:SetOwner(talentButton, "ANCHOR_RIGHT");
	
	GameTooltip:SetTalent(talentButton.talentID);
	
	if (not talentButton.isUnlocked) then
		local lastLine = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()];
		if (lastLine and lastLine:GetText() == TALENT_TOOLTIP_ADDPREVIEWPOINT) then
			lastLine:SetText("Your level is too low to select this talent.");
			lastLine:SetTextColor(1, 0.1, 0.1);
		end
	elseif (talentButton.isOnCooldown) then
		local lastLine = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()];
		if (lastLine and lastLine:GetText() == TALENT_TOOLTIP_ADDPREVIEWPOINT) then
			lastLine:SetText("Talent on this row is on cooldown.");
			lastLine:SetTextColor(1, 0.1, 0.1);
		end
	end
	
	local canChange = Addon:CanChangeTalents();
	if (not canChange and Addon.db.global.UseReagents and not talentButton.isSelected and talentButton.isUnlocked) then
		local reagents = Addon:GetTalentClearInfo();
		local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
		
		if (not InCombatLockdown()) then
			if (not talentButton.tierFree) then
				GameTooltip:AddLine("|cff00ff00You can click the talent to automatically use a Tome and change to this talent.|r", 1, 1, 1, true);
				if (reagentCount and reagentCount == 0) then
					GameTooltip:AddLine("|cffff0000You have no Tomes currently.|r", 1, 1, 1, true);
				end
			end
		else
			GameTooltip:AddLine("|cffff0000You are in combat.|r", 1, 1, 1, true);
		end
	end
	
	GameTooltip:Show();
end

----------------------------------------------------------
-- Binding management

function Addon:IsBindingSet()
	return GetBindingKey("CLICK FlashTalentFrameToggler:LeftButton") ~= nil;
end

function Addon:HasAskedBinding()
	if (GetCurrentBindingSet() == 1) then
		return self.db.global.AskedKeybind;
	elseif (GetCurrentBindingSet() == 2) then
		return self.db.char.AskedKeybind;
	end
end

function Addon:SetAskedBinding(value)
	if (GetCurrentBindingSet() == 1) then
		self.db.global.AskedKeybind = value;
	elseif (GetCurrentBindingSet() == 2) then
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
	if (position and position.Point and position.RelativePoint and position.x and position.y) then
		FlashTalentFrame:ClearAllPoints();
		FlashTalentFrame:GetPoint(position.Point, UIparent, position.RelativePoint, position.x, position.y);
		
		-- print(position.Point, position.RelativePoint, position.x, position.y)
	end
end

function Addon:ToggleFrame(tabIndex)
	if (InCombatLockdown()) then return end
	
	
	if (not FlashTalentFrame:IsVisible()) then
		FlashTalentFrame:Show();
		Addon:RestorePosition();
		Addon:UpdateFrame();
		Addon:UpdateTalentFrame();
	else
		FlashTalentFrame:Hide();
	end
end

function Addon:UpdateFrame()
	if (not InCombatLockdown() and not FlashTalentFrame:IsVisible() and self.db.global.StickyWindow and self.db.global.IsWindowOpen) then
		FlashTalentFrame:Show();
	end
	
	FlashPvpTalentChangeFrame:Hide();
	
	if (self.db.global.AnchorSide == "RIGHT") then
		FlashTalentFrameTalents:ClearAllPoints();
		FlashTalentFrameTalents:SetPoint("TOPLEFT", FlashTalentFrame, "TOPLEFT", 0, -22);
		
		FlashTalentFramePvpTalents:ClearAllPoints();
		FlashTalentFramePvpTalents:SetPoint("TOPLEFT", FlashTalentFrameTalents, "TOPRIGHT", 4, -4);
		
		FlashTalentFrameSettingsButton:ClearAllPoints();
		FlashTalentFrameSettingsButton:SetPoint("BOTTOMLEFT", FlashTalentFrameTalents, "BOTTOMRIGHT", 4, -2);
		
	elseif (self.db.global.AnchorSide == "LEFT") then
		FlashTalentFrameTalents:ClearAllPoints();
		FlashTalentFrameTalents:SetPoint("TOPRIGHT", FlashTalentFrame, "TOPRIGHT", 0, -22);
		
		FlashTalentFramePvpTalents:ClearAllPoints();
		FlashTalentFramePvpTalents:SetPoint("TOPRIGHT", FlashTalentFrameTalents, "TOPLEFT", -4, -4);
		
		FlashTalentFrameSettingsButton:ClearAllPoints();
		FlashTalentFrameSettingsButton:SetPoint("BOTTOMRIGHT", FlashTalentFrameTalents, "BOTTOMLEFT", -5, -2);
	end
	
	FlashTalentFrame:SetScale(self.db.global.WindowScale);
	Addon:UpdateFonts();
end

function FlashTalentFrame_OnShow(self)
	Addon.db.global.IsWindowOpen = true;
end

function FlashTalentFrame_OnHide(self)
	if (FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible()) then
		LibQTip:Release(FlashTalentSpecButton.tooltip);
		FlashTalentSpecButton.tooltip = nil;
	end
	
	Addon.db.global.IsWindowOpen = false;
end

function FlashTalentFrame_OnMouseDown(self)
	if (IsAltKeyDown()) then
		FlashTalentFrame:StartMoving();
		FlashTalentFrame.isMoving = true;
		FlashTalentFrame.wasMoved = true;
	end
end

function FlashTalentFrame_OnMouseUp(self)
	if (FlashTalentFrame.isMoving) then
		FlashTalentFrame:StopMovingOrSizing();
		FlashTalentFrame.isMoving = false;
		Addon:SavePosition();
	end
end

function Addon:PLAYER_REGEN_DISABLED()
	self.EnteringCombat = true;
	
	if (not self.db.global.StickyWindow) then
		FlashTalentFrame:Hide();
	end
	
	Addon:UpdateReagentCount();
	
	self.EnteringCombat = false;
end

function Addon:PLAYER_REGEN_ENABLED()
	Addon:UpdateReagentCount();
end

----------------------------------------------------------
-- Challenge mode restriction

-- function Addon:HasChallengeModeRestriction()
-- 	return C_ChallengeMode.IsChallengeModeActive() and self.ChallengeModeActive;
-- end

-- function Addon:SCENARIO_UPDATE()
-- 	if (not self.ChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
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
	if (InCombatLockdown()) then return end
	Addon:UpdateReagentCount();
end

function Addon:PLAYER_UPDATE_RESTING()
	if (InCombatLockdown()) then return end
	if (not FlashTalentFrame:IsVisible()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateReagentCount();
end

function Addon:UNIT_AURA(event, unit)
	if (unit ~= "player") then return end
	if (InCombatLockdown()) then return end
	if (not FlashTalentFrame:IsVisible()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateReagentCount();
	
	if (self.scheduledTalentChange and Addon:CanChangeTalents()) then
		Addon:LearnTalent(self.scheduledTalentCategory, self.scheduledTalentID, self.scheduledTalentSlotIndex);
		self.scheduledTalentChange = false;
	end
end

function Addon:UNIT_PET()
	Addon:UpdateSpecTooltips();
end

function Addon:PLAYER_TALENT_UPDATE()
	if (InCombatLockdown()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateDatabrokerText();
end

function Addon:PLAYER_LEVEL_UP()
	if (InCombatLockdown()) then return end
	Addon:UpdateTalentFrame();
	Addon:UpdateDatabrokerText();
end

-------------------------------------------------------
-- Talent buttons

-- Blizz function from Blizzard_TalentUI.lua
local function HandleGeneralTalentFrameChatLink(self, talentName, talentLink)
	if ( MacroFrameText and MacroFrameText:HasFocus() ) then
		local spellName, subSpellName = GetSpellInfo(talentName);
		if ( spellName and not IsPassiveSpell(spellName) ) then
			if ( subSpellName and (strlen(subSpellName) > 0) ) then
				ChatEdit_InsertLink(spellName.."("..subSpellName..")");
			else
				ChatEdit_InsertLink(spellName);
			end
		end
	elseif ( talentLink ) then
		ChatEdit_InsertLink(talentLink);
	end
end

function Addon:HandleTalentChatLink(talentID, talentCategory)
	local talentName, talentLink;
	if (talentCategory == TALENT_PVE) then
		talentName = select(2, GetTalentInfoByID(talentID, 1, false));
		talentLink = GetTalentLink(talentID);
	elseif (talentCategory == TALENT_PVP) then
		talentName = select(2, GetPvpTalentInfoByID(talentID, 1));
		talentLink = GetPvpTalentLink(talentID);
	end
	
	if (talentName and talentLink) then
		HandleGeneralTalentFrameChatLink(nil, talentName, talentLink);
	end
end

function FlashTalentButtonTemplate_PostClick(self)
	if (FlashTalentFrame.isMoving or FlashTalentFrame.wasMoved) then
		FlashTalentFrame.wasMoved = false;
		return;
	end
	
	if (self.talentID and IsModifiedClick("CHATLINK")) then
		Addon:HandleTalentChatLink(self.talentID);
	end
	
	if (UnitIsDeadOrGhost("player")) then return end
	
	if (self.isUnlocked) then
		local canChange, remainingTime = Addon:CanChangeTalents();
		if (not canChange and Addon.db.global.UseReagents and not self.tierFree) then
			-- Schedule talent change when UNIT_AURA event is triggered
			Addon:ScheduleTalentChange(TALENT_PVE, self.talentID);
		else
			Addon:LearnTalent(TALENT_PVE, self.talentID);
		end
	end
end

--------------------------------
-- New pvp talents

function FlashPvpTalentSlotButtonTemplate_OnEnter(self)
	Addon.HoveredPvpTalent = self;
	if (not IsShiftKeyDown() and not Addon.db.global.AlwaysShowTooltip) then
		return
	end
	
	local slotIndex = self:GetID();
	local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
	if (not slotInfo) then
		return;
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	
	if (slotInfo.selectedTalentID) then
		GameTooltip:SetPvpTalent(slotInfo.selectedTalentID, false, GetActiveSpecGroup(true), slotIndex);
		GameTooltip:AddLine("Click to change the talent.", 0, 1, 0);
	else
		GameTooltip:SetText(PVP_TALENT_SLOT);
		if (not slotInfo.enabled) then
			GameTooltip:AddLine(PVP_TALENT_SLOT_LOCKED:format(C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(slotIndex)), RED_FONT_COLOR:GetRGB());
		else
			GameTooltip:AddLine(PVP_TALENT_SLOT_EMPTY, GREEN_FONT_COLOR:GetRGB());
		end
	end
	
	GameTooltip:Show();
	
	if (self.specTooltipFrame) then
		self.specTooltipFrame:Release();
	end
	
	if (slotInfo.enabled) then
		self.highlight:Show();
	end
end

function FlashPvpTalentSlotButtonTemplate_OnLeave(self)
	GameTooltip:Hide();
	Addon.HoveredPvpTalent = nil;
	
	if (not self.isSelected) then
		self.highlight:Hide();
	end
end

function FlashPvpTalentSlotButtonTemplate_OnClick(self, button)
	if (button == "LeftButton") then
		local slotIndex = self:GetID();
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
		if (not slotInfo) then
			return;
		end
		
		if (slotInfo.enabled) then
			if (not self.isSelected) then
				Addon:ClearSelections(slotIndex);
				Addon:OpenPvpTalentChangeMenu(self, slotIndex);
				self.isSelected = true;
			else
				FlashPvpTalentChangeFrame:Hide();
				self.highlight:Show();
				self.isSelected = false;
			end
		end
	end
end

function FlashPvpTalentSlotButtonTemplate_OnDragStart(self)
	if (InCombatLockdown()) then return end
	
	if (IsAltKeyDown()) then
		local slotIndex = self:GetID();
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
		if (not slotInfo or not slotInfo.selectedTalentID) then
			return
		end
		
		PickupPvpTalent(slotInfo.selectedTalentID);
	end
end

function Addon:OpenPvpTalentChangeMenu(talentFrame, slotIndex)
	if (InCombatLockdown()) then return end
	if (not talentFrame or not slotIndex) then return end
	
	local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
	local selectedPvpTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
	
	local selectedTalentID = slotInfo.selectedTalentID;
	local availableTalentIDs = slotInfo.availableTalentIDs;
	
	for index, talentID in ipairs(availableTalentIDs) do
		if (talentID == selectedTalentID) then
			table.remove(availableTalentIDs, index);
			break;
		end
	end
	
	local numTalents = #slotInfo.availableTalentIDs;
	
	table.sort(availableTalentIDs, function(a, b)
		local unlockedA = select(7,GetPvpTalentInfoByID(a));
		local unlockedB = select(7,GetPvpTalentInfoByID(b));

		if (unlockedA ~= unlockedB) then
			return unlockedA;
		end

		if (not unlockedA) then
			local reqLevelA = C_SpecializationInfo.GetPvpTalentUnlockLevel(a);
			local reqLevelB = C_SpecializationInfo.GetPvpTalentUnlockLevel(b);

			if (reqLevelA ~= reqLevelB) then
				return reqLevelA < reqLevelB;
			end
		end

		local selectedOtherA = tContains(selectedPvpTalents, a) and slotInfo.selectedTalentID ~= a;
		local selectedOtherB = tContains(selectedPvpTalents, b) and slotInfo.selectedTalentID ~= b;

		if (selectedOtherA ~= selectedOtherB) then
			return selectedOtherB;
		end

		return a < b;
	end);
	
	local columns = math.min(6, numTalents);
	local rows = math.ceil(numTalents / 6);
	
	FlashPvpTalentChangeFrame:SetWidth(columns * 28);
	FlashPvpTalentChangeFrame:SetHeight(rows * 28);
	
	local rowFirstButton = FlashPvpTalentChangeFrameButton1;
	local previousButton = FlashPvpTalentChangeFrameButton1;
	
	if (not FlashPvpTalentChangeFrame.buttons) then
		FlashPvpTalentChangeFrame.buttons = {}
		tinsert(FlashPvpTalentChangeFrame.buttons, FlashPvpTalentChangeFrameButton1);
	end
	
	for index, button in pairs(FlashPvpTalentChangeFrame.buttons) do
		if (button) then
			button.talentID = nil;
			button:Hide()
		end
	end
	
	local index = 1;
	for _, talentID in ipairs(availableTalentIDs) do
		local _, name, icon, selected, available, spellID, unlocked = GetPvpTalentInfoByID(talentID);
		
		local button = _G['FlashPvpTalentChangeFrameButton' .. index];
		if (not button) then
			button = CreateFrame("Button", 'FlashPvpTalentChangeFrameButton' .. index, FlashPvpTalentChangeFrame, "FlashPvpTalentChangeButtonTemplate");
			
			if (index ~= 1 and (index - 1) % 6 == 0) then
				button:SetPoint("TOPLEFT", rowFirstButton, "BOTTOMLEFT", 0, 0);
			elseif (index ~= 1) then
				button:SetPoint("TOPLEFT", previousButton, "TOPRIGHT", 0, 0);
			end
			
			tinsert(FlashPvpTalentChangeFrame.buttons, button);
		end
		
		if (index ~= 1 and (index - 1) % 6 == 0) then
			rowFirstButton = button;
		end
		previousButton = button;
		
		button.canChange = (selectedTalentID == nil);
		
		button.talentID = talentID;
		button.slotIndex = slotIndex;
		button.slotFree = (selectedTalentID == nil);
		button.isUnlocked = unlocked;
		button.talentInUse = tContains(selectedPvpTalents, talentID);
		
		button.icon:SetTexture(icon);
		IconSetColor(button.icon, TALENT_COLOR_SELECTED);
		button.icon:SetDesaturated(false);
		button.check:Hide();
		button.text:Hide();
		
		if (not button.isUnlocked) then
			IconSetColor(button.icon, TALENT_COLOR_LOCKED);
			button.icon:SetDesaturated(true);
			button.text:SetText(C_SpecializationInfo.GetPvpTalentUnlockLevel(talentID));
			button.text:Show();
		elseif (button.talentInUse) then
			IconSetColor(button.icon, TALENT_COLOR_INUSE);
			button.icon:SetDesaturated(true);
			button.check:Show();
		end
		
		Addon:SetTalentButtonReagentAttribute(button, button.slotFree or button.talentInUse or not button.isUnlocked);
		
		button:Show();
		index = index + 1
	end
	
	FlashPvpTalentChangeFrame:SetParent(talentFrame);
	FlashPvpTalentChangeFrame:ClearAllPoints();
	
	if (self.db.global.AnchorSide == "RIGHT") then
		FlashPvpTalentChangeFrame:SetPoint("TOPLEFT", talentFrame, "TOPRIGHT", 8, -1);
	elseif (self.db.global.AnchorSide == "LEFT") then
		FlashPvpTalentChangeFrame:SetPoint("TOPRIGHT", talentFrame, "TOPLEFT", -8, -1);
	end
	FlashPvpTalentChangeFrame:Show();
end

-------------------

function FlashPvpTalentChangeButtonTemplate_OnEnter(self)
	local _, _, _, selected, available, spellID, unlocked = GetPvpTalentInfoByID(self.talentID);
	
	if (not self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED_HOVER);
	elseif (self.talentInUse) then
		IconSetColor(self.icon, TALENT_COLOR_INUSE_HOVER);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED_HOVER);
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetPvpTalent(self.talentID, false, GetActiveSpecGroup(true), self.slotIndex);
	
	local canChange = Addon:CanChangeTalents();
	if (not canChange and Addon.db.global.UseReagents and not self.talentInUse and self.isUnlocked) then
		local reagents = Addon:GetTalentClearInfo();
		local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
		
		if (not InCombatLockdown()) then
			if (not self.slotFree) then
				GameTooltip:AddLine("|cff00ff00You can click the talent to automatically use a Tome and change to this talent.|r", 1, 1, 1, true);
				if (reagentCount and reagentCount == 0) then
					GameTooltip:AddLine("|cffff0000Currently you have no Tomes.|r", 1, 1, 1, true);
				end
			end
		else
			GameTooltip:AddLine("|cffff0000You are in combat.|r", 1, 1, 1, true);
		end
	elseif (self.talentInUse) then
		GameTooltip:AddLine("|cffff0000Talent used in another slot.|r", 1, 1, 1, true);
	end
	
	GameTooltip:Show();
end

function FlashPvpTalentChangeButtonTemplate_OnLeave(self)
	GameTooltip:Hide();
	if (not self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED);
	elseif (self.talentInUse) then
		IconSetColor(self.icon, TALENT_COLOR_INUSE);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED);
	end
end

function FlashPvpTalentChangeButtonTemplate_PostClick(self)
	if (FlashTalentFrame.isMoving or FlashTalentFrame.wasMoved) then
		FlashTalentFrame.wasMoved = false;
		return;
	end
	
	if (self.talentID and IsModifiedClick("CHATLINK")) then
		Addon:HandleTalentChatLink(self.talentID, TALENT_PVP);
		return;
	end
	
	if (UnitIsDeadOrGhost("player")) then
		FlashPvpTalentChangeFrame:Hide();
		return;
	end
	
	if (self.isUnlocked) then
		local canChange, remainingTime = Addon:CanChangeTalents();
		if (not canChange and Addon.db.global.UseReagents and not self.slotFree) then
			-- Schedule talent change when UNIT_AURA event is triggered
			Addon:ScheduleTalentChange(TALENT_PVP, self.talentID, self.slotIndex);
		else
			Addon:LearnTalent(TALENT_PVP, self.talentID, self.slotIndex);
		end
	end
	
	FlashPvpTalentChangeFrame:Hide();
end

function FlashPvpTalentChangeButtonTemplate_OnDragStart(self)
	if (InCombatLockdown() or not self.isSelected) then return end
	
	if (not IsAltKeyDown()) then
		PickupPvpTalent(self.talentID);
	end
end

-------------------------------------

function FlashPvpTalentChangeFrame_OnHide()
	Addon:ClearSelections();
end

function Addon:ClearSelections(skip)
	for slotIndex, talentFrame in pairs(FlashTalentFramePvpTalents.slots) do
		if(not skip or slotIndex ~= skip) then
			talentFrame.isSelected = false;
			talentFrame.highlight:Hide();
		end
	end
end
-------------------------------------

function Addon:ScheduleTalentChange(category, talentID, slotIndex)
	if (not category or not talentID) then return end
	
	self.scheduledTalentCategory  = category;
	self.scheduledTalentID        = talentID;
	self.scheduledTalentChange    = true;
	
	assert(category == TALENT_PVE or slotIndex ~= nil);
	self.scheduledTalentSlotIndex = slotIndex;
end

function Addon:LearnTalent(category, talentID, slotIndex)
	if (not category or not talentID) then return end
	
	if (category == TALENT_PVE) then
		LearnTalent(talentID);
	elseif (category == TALENT_PVP) then
		assert(slotIndex ~= nil);
		LearnPvpTalent(talentID, slotIndex);
	end
end

function FlashTalentButtonTemplate_OnDragStart(self)
	if (InCombatLockdown() or not self.isSelected) then return end
	
	if (not IsAltKeyDown()) then
		PickupTalent(self.talentID);
	end
end

------------------------------------------------------
-- Update talents

function Addon:UpdateTalentFrame()
	if (InCombatLockdown()) then return end
	
	Addon:UpdatePVETalentFrame();
	Addon:UpdatePVPTalentFrame();
	
	Addon:UpdateReagentCount();
end

function Addon:UpdatePVETalentFrame()
	if (InCombatLockdown()) then return end
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");

	local tierLevels = NEW_CLASS_TALENT_LEVELS
	
	for tier, tierFrame in pairs(FlashTalentFrameTalents.slots) do
		Addon:HighlightTalent(tier, -1);
		
		--local tierFrame = _G[string.format("FlashTalentFrameTalentsTier%d", tier)];
		tierFrame.glowFrame:Hide();
		
		local isUnlocked = (playerLevel >= tierLevels[tier]);
		if (not isUnlocked) then
			tierFrame.lockFade.levelText:SetText(tierLevels[tier]);
			tierFrame.lockFade:Show();
		else
			tierFrame.lockFade:Hide();
		end
		
		for column, button in pairs(tierFrame.columns) do
			button.text:Hide();
			
			local talentID, spellName, icon, isSelected, available, spellID = GetTalentInfo(tier, column, group);
			local tierAvailable, selection = GetTalentTierInfo(tier, group);
			local isFree = (selection == 0);
			
			if (isSelected) then
				Addon:HighlightTalent(tier, column);
			elseif (isUnlocked and talentID and isFree) then
				IconSetColor(button.icon, TALENT_COLOR_CANLEARN);
			end
			
			if (isFree and isUnlocked) then
				tierFrame.glowFrame:Show();
			end
			
			button.tier             = tier;
			button.column           = column;
			
			button.talentID         = talentID;
			button.isSelected       = isSelected;
			button.spellName        = spellName;
			
			button.tierFree         = isFree;
			button.isUnlocked       = isUnlocked;
			
			Addon:SetTalentButtonReagentAttribute(button, not isUnlocked or isSelected);
			
			button.icon:SetTexture(icon);
			
			if (isUnlocked) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
			end
		end
	end
end

--function Addon:IsPVPTalentUnlocked(prestigeLevel, honorLevel, row, column)
--	local realHonorLevel = prestigeLevel * 50 + honorLevel;
--	return realHonorLevel >= PVP_TALENT_LEVELS[row][column], PVP_TALENT_LEVELS[row][column];
--end

local function UpdateModelScene(scene, sceneID, fileID, forceUpdate)
	if (not scene) then
		return;
	end

	scene:Show();
	scene:SetFromModelSceneID(sceneID, forceUpdate);
	local effect = scene:GetActorByTag("effect");
	if (effect) then
		effect:SetModelByFileID(fileID);
	end
end

function Addon:UpdatePVPTalentFrame()
	if (InCombatLockdown()) then return end
	
	for slotIndex, talentFrame in pairs(FlashTalentFramePvpTalents.slots) do
		local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex);
		local numTalents = #slotInfo.availableTalentIDs;
		local selectedPvpTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
		local availableTalentIDs = slotInfo.availableTalentIDs;
		local selectedTalentID = slotInfo.selectedTalentID;
		local unlockLevel = C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(slotIndex);
		
		if (selectedTalentID) then
			local _, name, texture = GetPvpTalentInfoByID(selectedTalentID);
			SetPortraitToTexture(talentFrame.icon, texture);
		else
			talentFrame.icon:SetAtlas("pvptalents-talentborder-empty");
		end
		
		if (slotInfo and slotInfo.enabled) then
			talentFrame.ring:SetDesaturated(false);
			talentFrame.levelText:Hide();
		else
			talentFrame.ring:SetDesaturated(true);
			talentFrame.highlight:Hide();
			talentFrame.levelText:SetText(unlockLevel);
			talentFrame.levelText:Show();
		end
	end
	
	Addon:UpdateWarModeButton();
end

function Addon:PLAYER_FLAGS_CHANGED(event, unit)
	if (unit ~= "player") then return end
	Addon:UpdateWarModeButton();
end

function Addon:UpdateWarModeButton()
	local warModeEnabled = C_PvP.IsWarModeDesired();
	if (self.lastKnownWarModeEnabled == warModeEnabled) then
		return;
	end
	self.lastKnownWarModeEnabled = warModeEnabled;
	
	local warmodeFrame = FlashTalentFramePvpTalents.warmode;
	
	local disabledAdd = warModeEnabled and "" or "-disabled";
	local swordsAtlas = "pvptalents-warmode-swords"..disabledAdd;
	local ringAtlas = "pvptalents-warmode-ring"..disabledAdd;
	warmodeFrame.swords:SetAtlas(swordsAtlas);
	warmodeFrame.ring:SetAtlas(ringAtlas);
	
	local faction = UnitFactionGroup("player");
	if(faction ~= "Neutral") then
		SetPortraitToTexture(warmodeFrame.background, "Interface\\Icons\\PVPCurrency-Conquest-" .. faction);
	else
		SetPortraitToTexture(warmodeFrame.background, "Interface\\Icons\\INV_Staff_2H_PandarenMonk_C_01");
	end
	warmodeFrame.background:SetVertexColor(0.5, 0.5, 0.5);
	warmodeFrame.background:SetDesaturated(not warModeEnabled);
	
	local forceUpdate = false;
	
	if (warModeEnabled) then
		UpdateModelScene(warmodeFrame.orbModelScene, 108, 1102774, forceUpdate); -- 6AK_Arakkoa_Lamp_Orb_Fel.m2
		UpdateModelScene(warmodeFrame.fireModelScene, 109, 517202, forceUpdate); -- Firelands_Fire_2d.m2
	else
		warmodeFrame.orbModelScene:Hide();
		warmodeFrame.fireModelScene:Hide();
	end
end

function FlashPvpTalentWarModeButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip_SetTitle(GameTooltip, PVP_LABEL_WAR_MODE);
	if C_PvP.IsWarModeActive() then
		GameTooltip_AddInstructionLine(GameTooltip, PVP_WAR_MODE_ENABLED);
	end
	local wrap = true;
	local warModeRewardBonus = C_PvP.GetWarModeRewardBonus();
	GameTooltip_AddNormalLine(GameTooltip, PVP_WAR_MODE_DESCRIPTION_FORMAT:format(warModeRewardBonus), wrap);

	-- Determine if the player can toggle warmode on/off.
	local canToggleWarmode = C_PvP.CanToggleWarMode(true);
	local canToggleWarmodeOFF = C_PvP.CanToggleWarMode(false);

	-- Confirm there is a reason to show an error message
	if(not canToggleWarmode or not canToggleWarmodeOFF) then

		local warmodeErrorText;

		-- Outdoor world environment
		if(not C_PvP.CanToggleWarModeInArea()) then
			if(not canToggleWarmodeOFF and not IsResting()) then
				warmodeErrorText = UnitFactionGroup("player") == PLAYER_FACTION_GROUP[0] and PVP_WAR_MODE_NOT_NOW_HORDE_RESTAREA or PVP_WAR_MODE_NOT_NOW_ALLIANCE_RESTAREA;
			end
		end

		-- player is not allowed to toggle warmode in combat.
		if(warmodeErrorText) then
			GameTooltip_AddColoredLine(GameTooltip, warmodeErrorText, RED_FONT_COLOR, wrap);
		elseif (UnitAffectingCombat("player")) then
			GameTooltip_AddColoredLine(GameTooltip, SPELL_FAILED_AFFECTING_COMBAT, RED_FONT_COLOR, wrap);
		end
	end
		
	GameTooltip:Show();
end

function FlashPvpTalentWarModeButton_OnLeave(self)
	GameTooltip:Hide();
end

function FlashPvpTalentWarModeButton_OnClick(self, button)
	if (button == "LeftButton") then
		C_PvP.ToggleWarMode();
	end
end

-------------------------------------------------------
-- Talent cooldowns

function Addon:UpdateTalentCooldowns()
	Addon:UpdatePVETalentCooldowns();
	--Addon:UpdatePVPTalentCooldowns();
end

function Addon:UpdatePVETalentCooldowns()
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");

	local tierLevels = NEW_CLASS_TALENT_LEVELS

	for tier, tierFrame in pairs(FlashTalentFrameTalents.slots) do
		local tierIsOnCooldown = false;
		
		local isUnlocked = (playerLevel >= tierLevels[tier]);
		if (not isUnlocked) then
			break;
		else
			tierFrame.lockFade:Hide();
		end
		
		for column = 1, 3 do
			local talentID, spellName, icon, isSelected = GetTalentInfo(tier, column, group);
			-- local isFree, selection = GetTalentTierInfo(tier, group);
			
			if (isSelected) then
				local start, duration, enable = GetSpellCooldown(spellName);
				
				if (start and duration and start > 0 and duration > 0) then
					local remaining = start + duration - GetTime();
					
					tierFrame.lockFade:Show();
					
					if (enable == 1) then
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
		
		if (not tierIsOnCooldown) then
			tierFrame.isOnCooldown = false;
			tierFrame.spellCooldown = nil;
			tierFrame.remaining = 0;
		end
		
		for column, button in pairs(tierFrame.columns) do
			if (not tierIsOnCooldown) then
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
	
end

function Addon:SPELL_UPDATE_USABLE()
	Addon:UpdateTalentCooldowns();
end

local HONOR_LEVEL_UNLOCK = 50;
function FlashTalentFrameHonorLevel_OnEnter(self)
	if (TipTac and TipTac.AddModifiedTip and not self.tiptacAdded) then
		self.tiptacAdded = true;
		TipTac:AddModifiedTip(FlashTalentExtraTooltip);
	end
	
	self.tooltip = FlashTalentExtraTooltip;
	
	local reward = PVPHonorSystem_GetNextReward();
	
	local level         = UnitLevel("player");
	local honorLevel    = UnitHonorLevel("player");
	local prestige      = UnitPrestige("player");
	local honor         = UnitHonor("player");
	local honorMax      = UnitHonorMax("player");
	
	self.tooltip:ClearLines();
	self.tooltip:ClearAllPoints();
	self.tooltip:SetOwner(self, "ANCHOR_NONE");
	
	if (Addon.db.global.AnchorSide == "RIGHT") then
		self.tooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, 2);
	elseif (Addon.db.global.AnchorSide == "LEFT") then
		self.tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 2);
	end
	
	local prestigeText = "";
	
	if (level == HONOR_LEVEL_UNLOCK) then
		self.label.text:SetText(string.format("%d / %d", honor, honorMax, honor / honorMax * 100));
		
		if (prestige > 0) then
			prestigeText = string.format("|cffffd200Prestige|r %d", prestige);
		end
	end
	
	self.tooltip:AddDoubleLine(
		string.format("|cffffd200Honor Level|r %d", honorLevel), prestigeText, 1, 1, 1, 1, 1, 1
	);
	
	
	if (level == HONOR_LEVEL_UNLOCK) then
		self.tooltip:AddLine(" ");
		self.tooltip:AddLine(string.format("|cffffd200Current progress|r %d / %d |cffdddddd(%0.1f%%)|r", honor, honorMax, honor / honorMax * 100), 1, 1, 1, true);
		
		if (honor < honorMax and not CanPrestige()) then
			self.tooltip:AddLine(string.format("%d honor to next level", honorMax - honor), 1, 1, 1, true);
		end
		
		GameTooltip:SetOwner(self, "ANCHOR_NONE");
		GameTooltip:ClearAllPoints();
		
		if (Addon.db.global.AnchorSide == "RIGHT") then
			GameTooltip:SetPoint("TOPRIGHT", self.tooltip, "BOTTOMRIGHT", 0, 0);
		elseif (Addon.db.global.AnchorSide == "LEFT") then
			GameTooltip:SetPoint("TOPLEFT", self.tooltip, "BOTTOMLEFT", 0, 0);
		end
		
		if (reward) then
			reward:SetTooltip();
			
			if (GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()) then
				GameTooltipTextLeft1:SetText("|cffffd200Next Reward|r|n|n" .. GameTooltipTextLeft1:GetText());
			end
			
			GameTooltip:Show();
			
			-- Hide TipTac icon
			if (GameTooltip.ttIcon and Addon.db.global.AnchorSide == "LEFT") then
				GameTooltip.ttIcon:Hide();
			end
		
			-- Super pretty hack to get the tooltip exactly as wide as gametooltip without having wonky text
			self.tooltip:SetMinimumWidth(GameTooltip:GetWidth());
			self.tooltip:Show();
			self.tooltip:SetMinimumWidth(GameTooltip:GetWidth() - (self.tooltip:GetWidth() - GameTooltip:GetWidth()));
		end
	else
		self.tooltip:AddLine(string.format("|cffffffffHonor unlocks at level %d.", HONOR_LEVEL_UNLOCK));
	end
	
	self.tooltip:Show();
end

function FlashTalentFrameHonorLevel_OnLeave(self)
	GameTooltip:Hide();
	self.tooltip:Hide();
	
	if (Addon.db.global.AnchorSide == "LEFT" and GameTooltip.ttIcon) then
		GameTooltip.ttIcon:Show();
	end
	
	local honorLevel = UnitHonorLevel("player");
	self.label.text:SetText(string.format("|cffffd200Level|r %s", honorLevel));
end

function Addon:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTalentsTier%dTalent%d", highlightTier, column);
		local button = _G[buttonName];
		
		if (button) then
			if (column == highlightColumn) then
				IconSetColor(button.icon, TALENT_COLOR_SELECTED);
			else
				IconSetColor(button.icon, TALENT_COLOR_LOCKED);
			end
		end
	end
end

function FlashTalentButtonTemplate_OnEnter(self)
	if (self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN_HOVER);
	elseif (not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED_HOVER);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED_HOVER);
	end
	
	if (IsShiftKeyDown() or Addon.db.global.AlwaysShowTooltip) then
		Addon:SetTalentTooltip(self);
	end
	
	Addon:HideSpecButtonTooltip();
	
	Addon.HoveredTalent = self;
end

function FlashTalentButtonTemplate_OnLeave(self)
	if (self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN);
	elseif (not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED);
	end
	
	GameTooltip:Hide();
	
	Addon.HoveredTalent = nil;
end

function Addon:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTalentsTier%dTalent%d", highlightTier, column);
		local button = _G[buttonName];
		
		if (button) then
			if (column == highlightColumn) then
				IconSetColor(button.icon, TALENT_COLOR_SELECTED);
			else
				IconSetColor(button.icon, TALENT_COLOR_LOCKED);
			end
		end
	end
end

function FlashTalentButtonTemplate_OnEnter(self)
	if (self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN_HOVER);
	elseif (not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED_HOVER);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED_HOVER);
	end
	
	if (IsShiftKeyDown() or Addon.db.global.AlwaysShowTooltip) then
		Addon:SetTalentTooltip(self);
	end
	
	Addon:HideSpecButtonTooltip();
	
	Addon.HoveredTalent = self;
end

function FlashTalentButtonTemplate_OnLeave(self)
	if (self.tierFree and self.isUnlocked) then
		IconSetColor(self.icon, TALENT_COLOR_CANLEARN);
	elseif (not self.isSelected) then
		IconSetColor(self.icon, TALENT_COLOR_LOCKED);
	else
		IconSetColor(self.icon, TALENT_COLOR_SELECTED);
	end
	
	GameTooltip:Hide();
	
	Addon.HoveredTalent = nil;
end

function Addon:MODIFIER_STATE_CHANGED(event, key, state)
	if (InCombatLockdown()) then return end
	if (not Addon.HoveredTalent) then return end
	
	if (key == "LSHIFT" or key == "RSHIFT") then
		if (state == 1) then
			if (Addon.HoveredTalent) then
				Addon:SetTalentTooltip(Addon.HoveredTalent);
			end
		elseif (not Addon.db.global.AlwaysShowTooltip) then
			GameTooltip:Hide();
		end
		
		--Addon:ClearAllReagentAttributes();
	end
end

-------------------------------------------------------
-- Reagents

function Addon:SetTalentButtonReagentAttribute(button, forceDisable)
	if (not button) then return end
	if (InCombatLockdown()) then return end
	
	forceDisable = forceDisable or false;
	
	local canChange, remainingTime = Addon:CanChangeTalents();
	
	if (self.db.global.UseReagents and not canChange and not forceDisable and not button.tierFree and button.isUnlocked) then
		local reagents = Addon:GetTalentClearInfo();
		local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
		
		button:SetAttribute("type1", "item");
		button:SetAttribute("item1", GetItemInfo(reagentID));
	else
		button:SetAttribute("item1", "");
	end
end

function Addon:ClearAllReagentAttributes()
	if (InCombatLockdown()) then return end
	
	
end

function Addon:GetTalentClearInfo()
	local items;
	
	local level = UnitLevel("player");
	
	if (level >= 50) then
		items = TALENT_CLEAR_ITEMS[2];
	else
		items = TALENT_CLEAR_ITEMS[1];
	end
	
	local single, multiple;
	
	
	for _, itemID in ipairs(items[1]) do
		if(GetItemCount(itemID) > 0 ) then
			single = {itemID, GetItemCount(itemID), GetItemIcon(itemID)}
			break
		end
	end
	if (not single) then
	  multiple = {items[1][1], GetItemCount(items[1][1]), GetItemIcon(items[1][1])} 
	end
	
	for _, itemID in ipairs(items[2]) do
		if(GetItemCount(itemID) > 0 ) then
			multiple = {itemID, GetItemCount(itemID), GetItemIcon(itemID)}
			break
		end
	end
	if (not multiple) then
	  multiple = {items[2][1], GetItemCount(items[2][1]), GetItemIcon(items[2][1])} 
	end

	return {single , multiple};
end

function Addon:UpdateReagentCount()
	if (self.EnteringCombat or InCombatLockdown()) then
		FlashTalentFrameReagents.text:SetText(string.format("|cffff3000Combat|r"));
		return;
	end
	
	local canChange, remainingTime = Addon:CanChangeTalents();
	if (canChange and remainingTime) then
		FlashTalentFrameReagents.text:SetText(string.format("|cff77ff00%s|r", Addon:FormatTime(remainingTime)));
		return;
	end
	
	local reagents = Addon:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
	
	if (reagentIcon) then
		local textPattern = "%s %d";
		if (canChange) then
			textPattern = "%s |cff77ff00%d|r";
		elseif (reagentCount == 0) then
			textPattern = "%s |cffff5511%d|r";
		end
		
		FlashTalentFrameReagents.text:SetFormattedText(textPattern, FLASHTALENT_ICON_PATTERN_NOBORDER:format(reagentIcon), reagentCount);
	else
		FlashTalentFrameReagents.text:SetText("");
	end
	
	if (InCombatLockdown()) then return end
	if (not canChange) then
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
	if (not canChange) then
		GameTooltip:AddLine("|cffff953fCurrently you are unable to change talents without using one of the items.|r", nil, nil, nil, true);
	elseif (canChange and not remainingTime) then
		GameTooltip:AddLine("|cffa2ed12You are able to change talents for free at this moment.|r", nil, nil, nil, true);
	elseif (canChange and remainingTime) then
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
			string.format("%s |cffffffff%dx|r %s", FLASHTALENT_ICON_PATTERN:format(icon), count or 0, name or ""),
			string.format("|cff00ff00%s to use|r", clicks[index])
		);
	end
	
	if (remainingTime) then
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
	if (InCombatLockdown()) then return end
	
	local index;
	if (button == "LeftButton") then
		index = 1;
	elseif (button == "RightButton") then
		index = 2;
	else
		return;
	end
	
	local reagents = Addon:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[index]);
	local name = GetItemInfo(reagentID);
	
	if (reagentCount and reagentCount == 0) then
		UIErrorsFrame:AddMessage(ITEM_MISSING:format(name), 1.0, 0.1, 0.1, 1.0);
	end
end
