------------------------------------------------------------
-- FlashTalent by Sonaza
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, SHARED = ...;
local _;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = A;
SHARED[1] = A;

local AceDB = LibStub("AceDB-3.0");
local LibQTip = LibStub("LibQTip-1.0");

BINDING_HEADER_FLASHTALENT = "FlashTalent";
_G["BINDING_NAME_CLICK FlashTalentFrameToggler:LeftButton"] = "Toggle FlashTalent Class Talents";
_G["BINDING_NAME_CLICK FlashTalentFrameToggler:RightButton"] = "Toggle FlashTalent Honor Talents";
_G["BINDING_NAME_FLASHTALENT_CHANGE_DUALSPEC"] = "Quick Switch to Previous Spec";
_G["BINDING_NAME_FLASHTALENT_OPEN_ITEM_SETS_MENU"] = "Open Equipment Menu at Cursor";

local ICON_PATTERN = "|T%s:14:14:0:0|t";
local ICON_PATTERN_NOBORDER = "|T%s:14:14:0:0:64:64:5:59:5:59|t";
local CHECKBUTTON_ICON_PATTERN = "|T%s:16:16:0:0:32:32:4:28:4:28|t";

StaticPopupDialogs["FLASHTALENT_NO_KEYBIND"] = {
	text = "FlashTalent does not currently have a keybinding. Do you want to open the key binding menu to set it?|n|nOption you are looking for is found under AddOns category.",
	button1 = YES,
	button2 = NO,
	button3 = "Don't Ask Again",
	OnAccept = function(self)
		PlaySound("igMainMenuOption");
		KeyBindingFrame_LoadUI();
		KeyBindingFrame.mode = 1;
		ShowUIPanel(KeyBindingFrame);
	end,
	OnCancel = function(self)
	end,
	OnAlt = function()
		A:SetAskedBinding(true);
	end,
	hideOnEscape = 1,
	timeout = 0,
};

StaticPopupDialogs["FLASHTALENT_NOT_ENOUGH_REAGENTS"] = {
	text = "Oops! In order to change the %s you require %s but you have none.",
	button1 = "Okay",
	OnAccept = function(self)
	end,
	hideOnEscape = 1,
	timeout = 0,
};

StaticPopupDialogs["FLASHTALENT_RENAME_EQUIPMENT_SET"] = {
	text = "Enter new name for %s:",
	button1 = SAVE,
	button2 = CANCEL,
	OnAccept = function(self, data)
		local oldName = data.oldName;
		local newName = strtrim(self.editBox:GetText());
		
		if(oldName and newName and oldName ~= newName and strlen(newName) > 0) then
			ModifyEquipmentSet(oldName, newName);
		end
	end,
	EditBoxOnEnterPressed = function(self, data)
		local oldName = data.oldName;
		local newName = strtrim(self:GetParent().editBox:GetText());
		
		if(oldName and newName and oldName ~= newName and strlen(newName) > 0) then
			ModifyEquipmentSet(oldName, newName);
		end
		
		self:GetParent():Hide();
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	OnCancel = function(self, data)
		
	end,
	OnShow = function(self, data)
		self.editBox:SetText(data.oldName);
	end,
	OnHide = function(self, data)
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
	end,
	hideOnEscape = 1,
	hasEditBox = 1,
	whileDead = 1,
	timeout = 0,
};

local TALENT_PVE = 1;
local TALENT_PVP = 2;

function A:OnInitialize()
	local defaults = {
		char = {
			AskedKeybind        = false,
			AutoSwitchGearSet   = false,
			OpenTalentTab       = 1,
			PreviousSpec        = 0,
			SpecSets            = {},
		},
		global = {
			AskedKeybind        = false,
			
			Position = {
				Point           = "CENTER",
				RelativePoint   = "CENTER",
				x               = 180,
				y               = 0,
			},
			StickyWindow        = false,
			WindowScale         = 1.0,
			IsWindowOpen        = false,
			
			AlwaysShowTooltip   = false,
			AnchorSide          = "RIGHT",
			
			HideBlizzAlert      = false,
		},
	};
	
	self.db = AceDB:New("FlashTalentDB", defaults);
	
	A.CurrentTalentTab = self.db.char.OpenTalentTab;
end

function A:IsBindingSet()
	return GetBindingKey("CLICK FlashTalentFrameToggler:LeftButton") ~= nil;
end

function A:HasAskedBinding()
	if(GetCurrentBindingSet() == 1) then
		return self.db.global.AskedKeybind;
	elseif(GetCurrentBindingSet() == 2) then
		return self.db.char.AskedKeybind;
	end
end

function A:SetAskedBinding(value)
	if(GetCurrentBindingSet() == 1) then
		self.db.global.AskedKeybind = value;
	elseif(GetCurrentBindingSet() == 2) then
		self.db.char.AskedKeybind = value;
	end
end

function A:OnEnable()
	A:RegisterEvent("PLAYER_REGEN_DISABLED");
	A:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	A:RegisterEvent("PET_SPECIALIZATION_CHANGED");
	
	A:RegisterEvent("PLAYER_TALENT_UPDATE");
	A:RegisterEvent("PLAYER_PVP_TALENT_UPDATE", "PLAYER_TALENT_UPDATE");
	
	if(UnitLevel("player") < MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]) then
		A:RegisterEvent("PLAYER_LEVEL_UP");
	end
	
	A:RegisterEvent("UNIT_AURA");
	A:RegisterEvent("BAG_UPDATE_DELAYED");
	A:RegisterEvent("MODIFIER_STATE_CHANGED");
	A:RegisterEvent("PLAYER_UPDATE_RESTING");
	
	A:RegisterEvent("EQUIPMENT_SWAP_FINISHED");
	A:RegisterEvent("EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED");
	
	if(UnitFactionGroup("player") == "Neutral") then
		A:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
	end
	
	local _, class = UnitClass("player");
	if(class == "HUNTER") then
		A:RegisterEvent("UNIT_PET");
	end
	
	A:RegisterEvent("SPELL_UPDATE_USABLE");
	
	-- A:RegisterEvent("SCENARIO_UPDATE");
	-- A:RegisterEvent("CHALLENGE_MODE_START");
	-- A:RegisterEvent("CHALLENGE_MODE_RESET");
	-- A:RegisterEvent("CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET");
	
	self.updaterFrame = CreateFrame("Frame");
	self.updaterFrame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed;
		if(self.elapsed > 0.1) then
			A:UpdateTalentCooldowns();
			self.elapsed = 0;
			
			if(FlashTalentFrameReagents and FlashTalentFrameReagents.tooltipOpen) then
				FlashTalentReagentFrame_OnEnter(FlashTalentFrameReagents);
			end
			
			local canChange, remainingTime = A:CanChangeTalents();
			if(canChange and remainingTime) then
				A:UpdateReagentCount();
			end
		end
		
		if(A.db.global.HideBlizzAlert) then
			TalentMicroButtonAlert:Hide();
		end
	end);
	
	A.SecureFrameToggler = CreateFrame("Button", "FlashTalentFrameToggler", nil, "SecureActionButtonTemplate");
	
	local initMacroText = 
		"/stopmacro [combat]\n"..
		"/click TalentMicroButton\n"..
		"/click PlayerTalentFrameTab3\n"..
		"/click PlayerTalentFrameTab2\n"..
		"/click TalentMicroButton\n";
	
	A.SecureFrameToggler:SetAttribute("type1", "macro");
	A.SecureFrameToggler:SetAttribute("macrotext1",
		initMacroText ..
		"/run FlashTalent:ToggleFrame(1)"
	);
	
	A.SecureFrameToggler:SetAttribute("type2", "macro");
	A.SecureFrameToggler:SetAttribute("macrotext2",
		initMacroText ..
		"/run FlashTalent:ToggleFrame(2)"
	);
	
	A:UpdateTalentFrame();
	A:UpdateFrame();
	
	hooksecurefunc("ModifyEquipmentSet", function(oldName, newName)
		for specIndex, setName in pairs(A.db.char.SpecSets) do
			if(setName == oldName) then
				A.db.char.SpecSets[specIndex] = newName;
			end
		end
	end);
	
	if(not self.db.global.StickyWindow) then
		tinsert(UISpecialFrames, "FlashTalentFrame");
	end
	
	if(not A:IsBindingSet() and not A:HasAskedBinding()) then
		StaticPopup_Show("FLASHTALENT_NO_KEYBIND");
	end
	
	hooksecurefunc("SetSpecialization", function(newSpec)
		if(GetSpecialization() ~= newSpec) then
			A.OldSpecialization = GetSpecialization();
		end
	end);
	
	-- if(C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
	-- 	A:CHALLENGE_MODE_START();
	-- end
	
	A:InitializeDatabroker();
	A:UpdateTabIcons();
end

function A:OpenTalentTab(tabIndex)
	if(tabIndex ~= 1 and tabIndex ~= 2) then return end
	
	if(tabIndex == 2 and UnitLevel("player") < SHOW_PVP_TALENT_LEVEL) then
		tabIndex = 1;
	end
	
	A.CurrentTalentTab = tabIndex;
	A.db.char.OpenTalentTab = A.CurrentTalentTab;
	
	A:UpdateTabIcons();
	A:UpdateTalentFrame();
end

function FlashTalentTabButton_OnClick(self, button)
	if(self.disabled) then return end
	if(InCombatLockdown()) then return end
	
	if(not IsAddOnLoaded("Blizzard_TalentUI")) then
		LoadAddOn("Blizzard_TalentUI");
	end
	
	local tabIndex = self:GetID();
	
	if(button == "LeftButton") then
		A:OpenTalentTab(tabIndex); 
	elseif(button == "RightButton") then
		if(not PlayerTalentFrame:IsVisible()) then
			ShowUIPanel(PlayerTalentFrame);
		end
		
		if(tabIndex == 1) then
			PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab" .. TALENTS_TAB]);
		elseif(tabIndex == 2) then
			PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab" .. PVP_TALENTS_TAB]);
		end
	end
end
	
function FlashTalentTabButton_OnEnter(self)
	if(not self.disabled) then
		self.iconFrameHover:Show();
	end
	
	A:HideSpecButtonTooltip();
	
	local level = UnitLevel("player");
	
	local tabID = self:GetID();
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	
	if(tabID == 1) then -- PVE tab
		GameTooltip:AddLine("Class Talents");
		
		if(level >= SHOW_TALENT_LEVEL) then
			GameTooltip:AddLine("|cffffffffView to class talents.");
			GameTooltip:AddLine("|cff00ff00Right click|r  Open talent panel.");
		
			if(GetNumUnspentTalents() > 0) then
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(string.format("%d unspent talent point%s.", GetNumUnspentTalents(), GetNumUnspentTalents() == 1 and "" or "s"));
			end
		else
			GameTooltip:AddLine(string.format("|cffffffffClass talents unlock at level %d.", SHOW_TALENT_LEVEL));
		end
		
	elseif(tabID == 2) then -- PVP Tab
		GameTooltip:AddLine("Honor Talents");
		
		if(level >= SHOW_PVP_TALENT_LEVEL) then
			GameTooltip:AddLine("|cffffffffView to honor talents.|r");
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

function A:UpdateTabIcons()
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
	
	if(A.CurrentTalentTab == TALENT_PVE) then
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
	
	if(A.CurrentTalentTab == TALENT_PVP) then
		pvptab.iconFrameGlow:Show();
	else
		pvptab.iconFrameGlow:Hide();
	end
end

function A:NEUTRAL_FACTION_SELECT_RESULT()
	A:UpdateTabIcons();
	A:UnregisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
end

function A:SPELL_UPDATE_USABLE()
	A:UpdateTalentCooldowns();
end

function A:HasChallengeModeRestriction()
	-- return C_ChallengeMode.IsChallengeModeActive() and self.ChallengeModeActive;
	return false;
end

function A:SCENARIO_UPDATE()
	-- if(not self.ChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() and ScenarioChallengeModeBlock.timerID ~= nil) then
	-- 	A:CHALLENGE_MODE_START();
	-- end
end

function A:CHALLENGE_MODE_START()
	self.ChallengeModeActive = true;
	A:UpdateTalentFrame();
end

function A:CHALLENGE_MODE_RESET()
	self.ChallengeModeActive = false;
	A:UpdateTalentFrame();
end

function A:SavePosition()
	local point, _, relativePoint, x, y     = FlashTalentFrame:GetPoint();
	self.db.global.Position.Point           = point;
	self.db.global.Position.RelativePoint   = relativePoint;
	self.db.global.Position.x               = x;
	self.db.global.Position.y               = y;
end

function A:RestorePosition()
	local position = self.db.global.Position;
	if(position and position.Point and position.RelativePoint and position.x and position.y) then
		FlashTalentFrame:ClearAllPoints();
		FlashTalentFrame:GetPoint(position.Point, UIparent, position.RelativePoint, position.x, position.y);
	end
end

function A:ToggleFrame(tabIndex)
	if(InCombatLockdown()) then return end
	
	local tabIndex = tabIndex or A.CurrentTalentTab;
	
	if(tabIndex == 2 and UnitLevel("player") < SHOW_PVP_TALENT_LEVEL) then
		tabIndex = 1;
	end
	
	if(not FlashTalentFrame:IsVisible() or A.CurrentTalentTab ~= tabIndex) then
		A:RestorePosition();
		FlashTalentFrame:Show();
		A:OpenTalentTab(tabIndex);
	else
		FlashTalentFrame:Hide();
	end
	
	if(not A.ShortToggler) then
		A.ShortToggler = true;
		A.SecureFrameToggler:SetAttribute("macrotext1", "/run FlashTalent:ToggleFrame(1)");
		A.SecureFrameToggler:SetAttribute("macrotext2", "/run FlashTalent:ToggleFrame(2)");
	end
end

function FlashTalentFrame_OnShow(self)
	A.db.global.IsWindowOpen = true;
end

function FlashTalentFrame_OnHide(self)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible()) then
		LibQTip:Release(FlashTalentSpecButton.tooltip);
		FlashTalentSpecButton.tooltip = nil;
	end
	
	A.db.global.IsWindowOpen = false;
end

function A:PLAYER_REGEN_DISABLED()
	if(not self.db.global.StickyWindow) then
		FlashTalentFrame:Hide();
	end
end

function A:BAG_UPDATE_DELAYED()
	if(InCombatLockdown()) then return end
	A:UpdateReagentCount()
end

function A:PLAYER_UPDATE_RESTING()
	if(InCombatLockdown()) then return end
	A:UpdateReagentCount()
end

function A:UNIT_AURA()
	if(InCombatLockdown()) then return end
	A:UpdateReagentCount();
end

function A:UpdateSpecTooltips()
	if(InCombatLockdown()) then return end
	
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and FlashTalentSpecButton.tooltip.category == 1) then
		FlashTalentSpecButton_OnEnter(FlashTalentSpecButton);
	end
	
	if(A.DataBrokerTooltip and A.DataBrokerTooltip:IsVisible()) then
		local _, parent = A.DataBrokerTooltip:GetPoint()
		A:DataBroker_OnEnter(parent);
	end
end

function A:PET_SPECIALIZATION_CHANGED()
	A:UpdateSpecTooltips();
end

function A:UNIT_PET()
	A:UpdateSpecTooltips();
end
	
function A:PLAYER_SPECIALIZATION_CHANGED(event, unit)
	if(InCombatLockdown()) then return end
	if(unit ~= "player") then return end
	
	if(A.OldSpecialization ~= nil and A.OldSpecialization ~= 0) then
		A.db.char.PreviousSpec = A.OldSpecialization;
	end
	
	A:UpdateTalentFrame();
	A:UpdateSpecTooltips();
	
	if(self.db.char.AutoSwitchGearSet) then
		local activeSpec = GetSpecialization();
		
		local setName;
		if(self.db.char.SpecSets[activeSpec]) then
			setName = self.db.char.SpecSets[activeSpec];
		end
		
		if(not setName or not GetEquipmentSetInfoByName(setName)) then
			local _, specName = GetSpecializationInfo(activeSpec);
			setName = specName;
		end
		
		local icon, setID, isEquipped, numItems, numEquipped, unknown, numMissing, numIgnored = GetEquipmentSetInfoByName(setName);
		if(icon ~= nil and not isEquipped) then
			if(numMissing == 0) then
				local latency = select(4, GetNetStats());
				C_Timer.After(0.3 + latency / 1000, function()
					UseEquipmentSet(setName);
				end);
			end
		end
	end
	
	A:UpdateDatabrokerText();
end

function A:PLAYER_TALENT_UPDATE()
	if(InCombatLockdown()) then return end
	
	A:UpdateTalentFrame();
	A:UpdateTabIcons();
	A:UpdateDatabrokerText();
end

function A:PLAYER_LEVEL_UP()
	if(InCombatLockdown()) then return end
	
	A:UpdateTalentFrame();
	A:UpdateTabIcons();
	A:UpdateDatabrokerText();
end

function A:ChangeDualSpec()
	if(A.db.char.PreviousSpec == 0) then return end
	SetSpecialization(A.db.char.PreviousSpec);
end

function FlashTalentSpecButton_OnClick(self, button)
	if(button == "LeftButton") then
		A:ChangeDualSpec();
	elseif(button == "RightButton") then
		FlashTalentSpecButton.tooltip:Hide();
		A:OpenItemSetsMenu(self);
	end
end

function A:HideSpecButtonTooltip()
	if(not FlashTalentSpecButton.tooltip) then return end
	
	FlashTalentSpecButton.tooltip:Hide();
	LibQTip:Release(FlashTalentSpecButton.tooltip);
	FlashTalentSpecButton.tooltip = nil;
end

local ICON_ROLES = "Interface\\LFGFRAME\\LFGROLE";
local ROLES = {
	DAMAGER = "|T%s:14:14:0:0:64:16:16:32:0:16|t",
	TANK    = "|T%s:14:14:0:0:64:16:32:48:0:16|t",
	HEALER  = "|T%s:14:14:0:0:64:16:48:64:0:16|t",
};

function FlashTalentSpecButton_OnEnter(self)
	self.tooltip = LibQTip:Acquire("FlashTalentSpecButtonTooltip", 2, "LEFT", "RIGHT");
	
	self.tooltip:Clear();
	self.tooltip:ClearAllPoints();
	self.tooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, -2);
	
	self.tooltip.category = 1;
	
	local areSpecsUnlocked = UnitLevel("player") >= SHOW_SPEC_LEVEL;
	
	self.tooltip:AddHeader("|cffffdd00Specializations|r");
	self.tooltip:AddSeparator();
	
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, background, role = GetSpecializationInfo(specIndex);
		
		local color = "|cffeeeeee";
		local activeText = "";
		
		local isActiveSpecialization = (specIndex == GetSpecialization());
		
		if(isActiveSpecialization) then
			activeText = "|cff00ff00Active|r";
		end
		
		if(isActiveSpecialization or specIndex == A.db.char.PreviousSpec) then
			color = "|cff8ce2ff";
		end
		
		if(areSpecsUnlocked or isActiveSpecialization) then
			local lineIndex = self.tooltip:AddLine(
				string.format("%s %s%s|r %s", ICON_PATTERN:format(icon), color, name, ROLES[role]:format(ICON_ROLES)),
				activeText
			);
			
			if(areSpecsUnlocked) then
				self.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization()) then
						SetSpecialization(specIndex);
					end
				end);
			end
		end
	end
	
	if(areSpecsUnlocked and (A.db.char.PreviousSpec == nil or A.db.char.PreviousSpec == 0)) then
		self.tooltip:AddLine(string.format("|cffffdd00Left click a specialization to change to it.|r"));
	end
	
	if(areSpecsUnlocked) then
		local _, class = UnitClass("player");
		local petname = UnitName("pet");
		if(class == "HUNTER" and petname) then
			self.tooltip:AddLine(" ");
			self.tooltip:AddLine(string.format("|cffffdd00%s's Specialization|r", petname));
			self.tooltip:AddSeparator();
			
			for specIndex = 1, GetNumSpecializations(false, true) do
				local id, name, description, icon, background, role = GetSpecializationInfo(specIndex, false, true);
				
				local activeText = "";
				
				if(specIndex == GetSpecialization(false, true)) then
					activeText = "|cff00ff00Active|r";
				end
				
				local lineIndex = self.tooltip:AddLine(string.format("%s %s", ICON_PATTERN:format(icon), name), activeText);
				
				self.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization(false, true)) then
						SetSpecialization(specIndex, true);
					end
				end);
			end
		end
	end
	
	if(areSpecsUnlocked) then
		self.tooltip:AddLine(" ");
		if(A.db.char.PreviousSpec ~= nil and A.db.char.PreviousSpec ~= 0) then
			local _, name, _, _, _, role = GetSpecializationInfo(A.db.char.PreviousSpec, false, false);
			self.tooltip:AddLine(string.format("|cff00ff00Left click|r  Switch back to |cffffdd00%s|r %s", name, ROLES[role]:format(ICON_ROLES)));
		end
	else
		self.tooltip:AddLine(string.format("|cffffdd00Specializations unlock at level %s.|r", SHOW_SPEC_LEVEL));
		self.tooltip:AddLine(" ");
	end
	
	self.tooltip:AddLine("|cff00ff00Right click|r  View equipment sets.");
	
	self.tooltip:SetAutoHideDelay(0.35, self);
	self.tooltip.OnRelease = function()
		self.tooltip = nil;
	end
	
	self.tooltip:Show();
end

function FlashTalentSpecButton_OnLeave(self)
	if(not self.tooltip) then return end
	
	-- self.tooltip:Hide();
	-- LibQTip:Release(self.tooltip);
	-- self.tooltip = nil;
end

local function GetCheckButtonTexture(checked)
	if(checked) then return CHECKBUTTON_ICON_PATTERN:format("Interface\\Buttons\\UI-CheckBox-Check") end
	return CHECKBUTTON_ICON_PATTERN:format("Interface\\Buttons\\UI-CheckBox-Up");
end

function A:EQUIPMENT_SWAP_FINISHED(event, success, setName)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and FlashTalentSpecButton.tooltip.category == 2) then
		A:RefreshItemSetsMenu(setName);
	end
	
	if(success) then
		PaperDollEquipmentManagerPane.selectedSetName = setName;
		PaperDollFrame_ClearIgnoredSlots();
		PaperDollFrame_IgnoreSlotsForSet(setName);
		PaperDollEquipmentManagerPane_Update();
		
		A:UpdateDatabrokerText();
	end
end

local function AddScriptedTooltipLine(tooltip, text, onClick, onEnter, onLeave)
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

function A:GetSpecializationInfoByName(specName)
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, background, role, primaryStat = GetSpecializationInfo(specIndex);
		if(name == specName) then
			return id, name, description, icon, background, role, primaryStat;
		end
	end
end

function A:OpenItemSetsMenu(anchorFrame, forceRefresh, setName)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and not forceRefresh) then return end
	
	local positionData = {};
	if(forceRefresh and FlashTalentSpecButton.tooltip) then
		positionData = { FlashTalentSpecButton.tooltip:GetPoint() };
	end
	
	FlashTalentSpecButton.tooltip = LibQTip:Acquire("FlashTalentSpecButtonTooltip", 2, "LEFT", "RIGHT");
	FlashTalentSpecButton.tooltip.category = 2;
	
	local tooltip = FlashTalentSpecButton.tooltip;
	
	tooltip:Clear();
	tooltip:AddHeader("|cffffdd00Equipment Sets|r");
	
	local numEquipmentSets = GetNumEquipmentSets();
	if(numEquipmentSets > 0) then
		local specSets = {};
		for specIndex, setName in pairs(A.db.char.SpecSets) do
			specSets[setName] = specIndex;
		end
		
		for index = 1, numEquipmentSets do
			local lineIndex;
			local name, icon, setID, isEquipped, numItems, numEquipped, numInventory, numMissing, numIgnored = GetEquipmentSetInfo(index);
			
			if(setName) then
				isEquipped = (setName == name);
			end
			
			local specSetName = "";
			if(specSets[name]) then
				local _, specName, _, specIcon = GetSpecializationInfo(specSets[name]);
				specSetName = string.format(" |cffffee22%s %s|r", strtrim(ICON_PATTERN:format(specIcon)), specName);
			else
				local _, specName, _, specIcon = A:GetSpecializationInfoByName(name);
				if(specName) then
					specSetName = string.format(" |cffaaaaaa%s %s|r", strtrim(ICON_PATTERN:format(specIcon)), specName);
				end
			end
			
			local equipmentTitle;
			if(isEquipped) then
				lineIndex = tooltip:AddLine(string.format("%s |cff33ff00%s (equipped)|r", ICON_PATTERN:format(icon), name), specSetName);
			elseif(numMissing > 0) then
				lineIndex = tooltip:AddLine(string.format("%s |cffff2222%s|r (%d missing)", ICON_PATTERN:format(icon), name, numMissing), specSetName);
			else
				lineIndex = tooltip:AddLine(string.format("%s %s", ICON_PATTERN:format(icon), name), specSetName);
			end
			
			tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_LEFT");
				GameTooltip:SetEquipmentSet(name);
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine("Left click  |cffffffffSwitch to this set", 0, 1, 0);
				GameTooltip:AddLine("Right click  |cffffffffRename the set", 0, 1, 0);
				GameTooltip:AddLine("Shift Middle click  |cffffffffUpdate set", 0, 1, 0);
				GameTooltip:AddLine(" ");
				
				if(not specSets[name] or specSets[name] ~= GetSpecialization()) then
					local _, specName, _, specIcon = GetSpecializationInfo(GetSpecialization());
					GameTooltip:AddLine(string.format("Ctrl Shift Right click  |cffffffffTag this set for |cffffffff%s %s|r", ICON_PATTERN:format(specIcon), specName), 0, 1, 0);
				else
					GameTooltip:AddLine("Ctrl Shift Right click  |cffffffffRemove spec tag from this set", 0, 1, 0);
				end
				
				GameTooltip:Show();
			end);
			
			tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
				GameTooltip:Hide();
			end);
			
			tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
				if(IsShiftKeyDown() and IsControlKeyDown() and button == "RightButton") then
					local activeSpec = GetSpecialization();
					if(A.db.char.SpecSets[activeSpec] == name) then
						A.db.char.SpecSets[activeSpec] = nil;
					else
						A.db.char.SpecSets[activeSpec] = name;
						
						for specIndex, setName in pairs(A.db.char.SpecSets) do
							if(specIndex ~= activeSpec and setName == name) then
								A.db.char.SpecSets[specIndex] = nil;
							end
						end
					end
					
					A:RefreshItemSetsMenu();
				elseif(IsShiftKeyDown() and button == "MiddleButton") then
					A:UpdateEquipmentSet(name);
					
				elseif(button == "RightButton") then
					local icon, setID = GetEquipmentSetInfoByName(name);
					
					StaticPopup_Show("FLASHTALENT_RENAME_EQUIPMENT_SET", string.format("%s %s", ICON_PATTERN:format(icon), name), nil, {
						oldName = name,
					});
					
				elseif(button == "LeftButton") then
					UseEquipmentSet(name);
				end
			end);
		end
	else
		local lineIndex = tooltip:AddLine("No Equipment Sets");
		tooltip:SetLineTextColor(lineIndex, 0.6, 0.6, 0.6);
	end
	
	tooltip:AddSeparator();
	
	local lineIndex;
	if(self.db.char.AutoSwitchGearSet) then
		lineIndex = tooltip:AddLine("|cffffdd00Auto Switch Gear Set|r", "|cff33ff00Enabled|r");
	else
		lineIndex = tooltip:AddLine("|cffffdd00Auto Switch Gear Set|r", "|cffff2222Disabled|r");
	end
	
	tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", -6, 0);
		GameTooltip:SetWidth(280);
		
		GameTooltip:AddLine("Automatic Gear Set Change");
		GameTooltip:AddLine("Enable this to automatically change equipment set when changing specialization.", 1, 1, 1, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("If an equipment set with the spec name exists it will be automatically equipped if no items are missing.", 1, 1, 1, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("Alternatively you can also tag an equipment set for a specialization and still use a separate name if you |cffffdd00Ctrl Shift Right click|r the set name in the list. Tagged sets have priority.", 1, 1, 1, true);
		
		GameTooltip:Show();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
		GameTooltip:Hide();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self)
		A.db.char.AutoSwitchGearSet = not A.db.char.AutoSwitchGearSet;
		A:RefreshItemSetsMenu();
	end);
	
	AddScriptedTooltipLine(tooltip, "|cffffdd00Open Equipment Manager|r", function()
		if(not PaperDollFrame:IsVisible()) then
			ToggleCharacter("PaperDollFrame");
		end
		
		PaperDollSidebarTab3:Click();
		
		local numEquipmentSets = GetNumEquipmentSets();
		for setID = 1, numEquipmentSets do
			local name, icon, setID, isEquipped = GetEquipmentSetInfo(setID);
			
			if(isEquipped) then
				PaperDollEquipmentManagerPane.selectedSetName = name;
				PaperDollFrame_ClearIgnoredSlots();
				PaperDollFrame_IgnoreSlotsForSet(name);
				PaperDollEquipmentManagerPane_Update();
				
				break;
			end
		end
	end);
	
	tooltip:SetAutoHideDelay(0.5, anchorFrame);
	FlashTalentSpecButton.tooltip.OnRelease = function()
		FlashTalentSpecButton.tooltip = nil;
	end
	
	tooltip:ClearAllPoints();
	
	if(not forceRefresh) then
		tooltip:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, -2);
		A.ItemSetsMenuParent = anchorFrame;
	else
		tooltip:SetPoint(unpack(positionData));
	end
	
	tooltip:Show();
	
	return tooltip;
end

function A:UpdateEquipmentSet(setName)
	-- PaperDollEquipmentManagerPane.selectedSetName = setName;
	PaperDollFrame_ClearIgnoredSlots();
	PaperDollFrame_IgnoreSlotsForSet(setName);
	-- PaperDollEquipmentManagerPane_Update();
	
	SaveEquipmentSet(setName);
end

local FlashTalentMenuCursorAnchor;
function A:OpenItemSetsMenuAtCursor()
	if(not FlashTalentMenuCursorAnchor) then
		FlashTalentMenuCursorAnchor = CreateFrame("Frame", "FlashTalentMenuCursorAnchor", UIParent);
		FlashTalentMenuCursorAnchor:SetSize(20, 20);
	end
	
	local x, y = GetCursorPosition();
	local uiscale = UIParent:GetEffectiveScale();
	
	FlashTalentMenuCursorAnchor:ClearAllPoints();
	FlashTalentMenuCursorAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uiscale, y / uiscale);
	
	local tooltip = A:OpenItemSetsMenu(FlashTalentMenuCursorAnchor);
	
	if(tooltip) then
		tooltip:ClearAllPoints();
		tooltip:SetPoint("BOTTOM", FlashTalentMenuCursorAnchor, "CENTER", 0, -2);
	end
end

function A:RefreshItemSetsMenu(setName)
	A:OpenItemSetsMenu(A.ItemSetsMenuParent, true, setName);
end

function A:SetTalentTooltip(talentButton)
	GameTooltip:SetOwner(talentButton, "ANCHOR_RIGHT");
	
	if(talentButton.talentCategory == TALENT_PVE) then
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
		
	elseif(talentButton.talentCategory == TALENT_PVP) then
		GameTooltip:SetPvpTalent(talentButton.talentID);
	end
	
	GameTooltip:Show();
end

function A:MODIFIER_STATE_CHANGED(event, key, state)
	if(InCombatLockdown()) then return end
	
	if(not A.HoveredTalent) then return end
	
	if(key == "LSHIFT" or key == "RSHIFT") then
		if(state == 1) then
			if(A.HoveredTalent) then
				A:SetTalentTooltip(A.HoveredTalent);
			end
		elseif(not A.db.global.AlwaysShowTooltip) then
			GameTooltip:Hide();
		end
	end
end

function FlashTalentButtonTemplate_OnDragStart(self)
	if(InCombatLockdown() or not self.isSelected) then return end
	
	if(not IsAltKeyDown()) then
		if(self.talentCategory == TALENT_PVE) then
			PickupTalent(self.talentID);
		elseif(self.talentCategory == TALENT_PVP) then
			PickupPvpTalent(self.talentID);
		end
	end
end

function A:GetRealSpellID(spell_id)
	local spell_name = GetSpellInfo(spell_id);
	local name, _, _, _, _, _, realSpellID = GetSpellInfo(spell_name);
	
	return realSpellID or spell_id;
end

function A:UnitHasBuff(unit, spell)
	if(not unit or not spell) then return false end
	
	local realSpellID = A:GetRealSpellID(spell);
	local spell_name = GetSpellInfo(realSpellID);
	if(not spell_name) then return false end
	
	local name, _, _, _, _, duration, expirationTime, unitCaster = UnitAura(unit, spell_name, nil, "HELPFUL");
	if(not name) then
		return false;
	end
	
	return true, expirationTime - GetTime();
end

function A:CanChangeTalents()
	if(InCombatLockdown()) then return false end
	if(IsResting()) then return true end
	
	local buffs = {
		{ id = 227565, },            -- Codex of Clear Mind (100) 
		{ id = 226234, },            -- Codex of Tranquil Mind
		{ id = 227563, lvl = 100 },  -- Tome of Clear Mind (100)
		{ id = 227041 },             -- Tome of Tranquil Mind
	};
	
	local level = UnitLevel("player");
	
	for _, data in ipairs(buffs) do
		if(not data.lvl or (data.lvl and level <= data.lvl)) then
			local hasBuff, remaining = A:UnitHasBuff("player", data.id);
			if(hasBuff) then
				return true, remaining;
			end
		end
	end
	
	return false, nil;
end

function FlashTalentButtonTemplate_OnClick(self)
	if(FlashTalentFrame.isMoving or FlashTalentFrame.wasMoved) then
		FlashTalentFrame.wasMoved = false;
		return;
	end
	
	if(self.isUnlocked and self.talentID) then
		if(self.talentCategory == TALENT_PVE) then
			LearnTalent(self.talentID);
		elseif(self.talentCategory == TALENT_PVP) then
			LearnPvpTalent(self.talentID);
		end
	end
end

local GLOBAL_COOLDOWN = 61304;
local function GetGCD()
	local start, duration = GetSpellCooldown(GLOBAL_COOLDOWN);
	if(start > 0 and duration > 0) then
		return start + duration - GetTime();
	end
	
	return 0;
end

function A:FormatTime(seconds)
	if(seconds > 60) then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60);
	elseif(seconds > 3) then
		return string.format("%ds", seconds);
	else
		return string.format("%.01fs", seconds);
	end
end

function A:UpdateTalentCooldowns()
	if(A.CurrentTalentTab == 1) then
		A:UpdatePVETalentCooldowns();
	elseif(A.CurrentTalentTab == 2) then
		A:UpdatePVPTalentCooldowns();
	end
end

function A:UpdatePVETalentCooldowns()
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	local tierLevels = CLASS_TALENT_LEVELS[playerClass] or CLASS_TALENT_LEVELS.DEFAULT;
	
	for tier = 1, 7 do
		local tierIsOnCooldown = false;
		
		local tierFrame = _G[string.format("FlashTalentFrameTier%d", tier)];
		
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
						tierFrame.lockFade.levelText:SetText(A:FormatTime(remaining));
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

function A:UpdatePVPTalentCooldowns()
	local group = GetActiveSpecGroup();
	
	local honorLevel = UnitHonorLevel("player");
	
	for tier = 2, 7 do
		local tierIsOnCooldown = false;
		
		local tierFrame = _G[string.format("FlashTalentFrameTier%d", tier)];
		
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
					button.text:SetText(A:FormatTime(remaining));
					
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

local TALENT_COLOR_LOCKED               = { 0.22, 0.22, 0.22 };
local TALENT_COLOR_LOCKED_HOVER         = { 0.35, 0.35, 0.35 };

local TALENT_COLOR_CANLEARN             = { 0.82, 0.82, 0.82 };
local TALENT_COLOR_CANLEARN_HOVER       = { 1.0, 1.0, 1.0 };

local TALENT_COLOR_SELECTED             = { 0.9, 0.9, 0.9 };
local TALENT_COLOR_SELECTED_HOVER       = { 1.0, 1.0, 1.0 };

local function IconSetColor(frame, color)
	if(not frame or not color) then return end
	frame:SetVertexColor(unpack(color));
end

function A:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTier%dTalent%d", highlightTier, column);
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
	
	if(IsShiftKeyDown() or A.db.global.AlwaysShowTooltip) then
		A:SetTalentTooltip(self);
	end
	
	A:HideSpecButtonTooltip();
	
	A.HoveredTalent = self;
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
	
	A.HoveredTalent = nil;
end

function A:UpdateTalentFrame()
	if(InCombatLockdown()) then return end
	
	if(A.CurrentTalentTab == 1) then
		A:UpdatePVETalentFrame();
	elseif(A.CurrentTalentTab == 2) then
		A:UpdatePVPTalentFrame();
	end
	
	A:UpdateReagentCount();
end

function A:UpdatePVETalentFrame()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrameTier1:Show();
	FlashTalentFrameHonorLevel:Hide();
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	local tierLevels = CLASS_TALENT_LEVELS[playerClass] or CLASS_TALENT_LEVELS.DEFAULT;
	
	for tier = 1, 7 do
		A:HighlightTalent(tier, -1);
		
		local tierFrame = _G[string.format("FlashTalentFrameTier%d", tier)];
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
				A:HighlightTalent(tier, column);
			elseif(isUnlocked and talentID and isFree) then
				IconSetColor(button.icon, TALENT_COLOR_CANLEARN);
			end
			
			if(isFree and isUnlocked) then
				tierFrame.glowFrame:Show();
			end
			
			button.talentID = talentID;
			button.talentCategory = TALENT_PVE;
			
			button.isSelected = isSelected;
			
			button.spellName = spellName;
			
			button.tier = tier;
			button.column = column;
			
			button.tierFree = isFree;
			button.isUnlocked = isUnlocked;
			
			button.icon:SetTexture(icon);
			
			if(isUnlocked) then
				button.icon:SetDesaturated(false);
			else
				button.icon:SetDesaturated(true);
			end
		end
	end
end

local PVP_TALENT_LEVELS = {
	{  1, 13, 31 },
	{  2, 16, 34 },
	{  4, 19, 37 },
	{  6, 22, 40 },
	{  8, 25, 43 },
	{ 10, 28, 46 },
};

function A:IsPVPTalentUnlocked(honorLevel, row, column)
	return honorLevel >= PVP_TALENT_LEVELS[row][column], PVP_TALENT_LEVELS[row][column];
end

function A:UpdatePVPTalentFrame()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrameTier1:Hide();
	
	local honorLevel = UnitHonorLevel("player");
	
	FlashTalentFrameHonorLevel.text:SetText(string.format("|cffffdd00Level|r %s", honorLevel));
	FlashTalentFrameHonorLevel:Show();
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	for tier = 2, 7 do
		A:HighlightTalent(tier, -1, true);
		
		local tierFrame = _G[string.format("FlashTalentFrameTier%d", tier)];
		tierFrame.glowFrame:Hide();
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			
			local isUnlocked, unlockLevel = A:IsPVPTalentUnlocked(honorLevel, tier-1, column);
			
			local talentID, spellName, icon, isSelected, available, spellID = GetPvpTalentInfo(tier-1, column, group);
			local isRowFree = GetPvpTalentRowSelectionInfo(tier-1);
			
			if(isSelected) then
				A:HighlightTalent(tier, column);
			elseif(isUnlocked and talentID and isRowFree) then
				button.icon:SetVertexColor(0.6, 0.6, 0.6);
			end
			
			button.talentID = talentID;
			button.talentCategory = TALENT_PVP;
			
			button.isSelected = isSelected;
			
			button.spellName = spellName;
			
			button.tier = tier;
			button.column = column;
			
			button.tierFree = isRowFree;
			button.isUnlocked = isUnlocked;
			
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

function A:GetTalentClearInfo()
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

function A:UpdateReagentCount()
	local canChange, remainingTime = A:CanChangeTalents();
	if(canChange and remainingTime) then
		FlashTalentFrameReagents.text:SetText(string.format("|cff77ff00%s|r", A:FormatTime(remainingTime)));
		return;
	end
	
	local reagents = A:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[1]);
	
	if(reagentIcon) then
		local textPattern = "%s %d";
		if(canChange) then
			textPattern = "%s |cff77ff00%d|r";
		elseif(reagentCount == 0) then
			textPattern = "%s |cffff5511%d|r";
		end
		
		FlashTalentFrameReagents.text:SetFormattedText(textPattern, ICON_PATTERN_NOBORDER:format(reagentIcon), reagentCount);
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
	A:HideSpecButtonTooltip();
	
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", -2, 0);
	
	GameTooltip:AddLine("Tomes and Codices");
	
	GameTooltip:AddLine("|cff80bcffTo change talents while not resting you must first use either a tome or a codex.|r", nil, nil, nil, true);
	GameTooltip:AddLine(" ");
	
	local canChange, remainingTime = A:CanChangeTalents();
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
	
	local reagents = A:GetTalentClearInfo();
	for index, data in ipairs(reagents) do
		local itemID, count, icon = unpack(data);
		local name, link, quality = GetItemInfo(itemID);
		
		GameTooltip:AddDoubleLine(
			string.format("%s |cffffffff%dx|r %s", ICON_PATTERN:format(icon), count, name),
			string.format("|cff00ff00%s to use|r", clicks[index])
		);
	end
	
	if(remainingTime) then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(string.format("|cffffdd00You have |cff77ff00%s|cffffdd00 to change talents.|r", A:FormatTime(remainingTime)));
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
	
	local reagents = A:GetTalentClearInfo();
	local reagentID, reagentCount, reagentIcon = unpack(reagents[index]);
	local name = GetItemInfo(reagentID);
	
	if(reagentCount and reagentCount == 0) then
		UIErrorsFrame:AddMessage(ITEM_MISSING:format(name), 1.0, 0.1, 0.1, 1.0);
	end
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
		A:SavePosition();
	end
end

function FlashTalentFrameSettingsButton_OnEnter(self)
	if(DropDownList1:IsVisible()) then return end
	
	GameTooltip:ClearAllPoints();
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE");
	
	if(A.db.global.AnchorSide == "RIGHT") then
		GameTooltip:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", 2, 6);
	elseif(A.db.global.AnchorSide == "LEFT") then
		GameTooltip:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", -2, 6);
	end
	
	GameTooltip:AddLine("FlashTalent Pro Tips")
	GameTooltip:AddLine("Switch talents by hovering the one you wish to change to and |cff00ff00left click|r it.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("You can switch between class and honor talents by clicking the circles next to talent rows.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("The spec switch button will now change between your previously used spec so you can still use it to quickly switch between your most used specializations.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Hold alt and drag to move FlashTalent.", 0, 1, 0);
	if(not A.db.global.AlwaysShowTooltip) then
		GameTooltip:AddLine("Hold shift when hovering to display tooltip.", 0, 1, 0);
	end
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Click this icon to view options.", 1, 0.8, 0);
	
	GameTooltip:Show();
end

function FlashTalentFrameSettingsButton_OnLeave(self)
	GameTooltip:Hide();
end

function FlashTalentFrameSettingsButton_OnClick(self, button)
	GameTooltip:Hide();
	A:OpenContextMenu(self);
end

function A:UpdateFrame()
	if(not InCombatLockdown() and not FlashTalentFrame:IsVisible() and self.db.global.StickyWindow and self.db.global.IsWindowOpen) then
		FlashTalentFrame:Show();
	end
	
	if(self.db.global.AnchorSide == "RIGHT") then
		FlashTalentFrameTabs:ClearAllPoints();
		FlashTalentFrameTabs:SetPoint("TOPLEFT", FlashTalentFrameTier2, "TOPRIGHT", 4, 36);
		
		FlashTalentFrameSettingsButton:SetPoint("BOTTOM", FlashTalentFrameTabs, "BOTTOM", -5, 0);
	elseif(self.db.global.AnchorSide == "LEFT") then
		FlashTalentFrameTabs:ClearAllPoints();
		FlashTalentFrameTabs:SetPoint("TOPRIGHT", FlashTalentFrameTier2, "TOPLEFT", -4, 36);
		
		FlashTalentFrameSettingsButton:SetPoint("BOTTOM", FlashTalentFrameTabs, "BOTTOM", 6, 0);
	end
	
	FlashTalentFrame:SetScale(self.db.global.WindowScale);
end

function A:ToggleEscapeClose()
	if(not self.db.global.StickyWindow) then
		tinsert(UISpecialFrames, "FlashTalentFrame");
	else
		for k, v in ipairs(UISpecialFrames) do
			if(v == "FlashTalentFrame") then
				table.remove(UISpecialFrames, k);
				break;
			end
		end
	end
end

function A:GetWindowScaleMenu()
	local windowScales = { 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.3, 1.4, 1.5, };
	local menu = {};
	
	for index, scale in ipairs(windowScales) do
		tinsert(menu, {
			text = string.format("%d%%", scale * 100),
			func = function() self.db.global.WindowScale = scale; A:UpdateFrame(); CloseMenus(); end,
			checked = function() return self.db.global.WindowScale == scale end,
		});
	end
	
	return menu;
end

function A:GetMenuData()
	local data = {
		{
			text = "FlashTalent Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Always show tooltips",
			func = function() self.db.global.AlwaysShowTooltip = not self.db.global.AlwaysShowTooltip; end,
			checked = function() return self.db.global.AlwaysShowTooltip; end,
			isNotRadio = true,
		},
		{
			text = "Keep window open",
			func = function() self.db.global.StickyWindow = not self.db.global.StickyWindow; A:ToggleEscapeClose(); end,
			checked = function() return self.db.global.StickyWindow; end,
			isNotRadio = true,
		},
		{
			text = "Hide Blizzard alert about unspent points",
			func = function() self.db.global.HideBlizzAlert = not self.db.global.HideBlizzAlert; end,
			checked = function() return self.db.global.HideBlizzAlert; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Miscellaneous", isTitle = true, notCheckable = true,
		},
		{
			text = string.format("|cffffdd00Window scale:|r %d%%", A.db.global.WindowScale * 100),
			hasArrow = true,
			notCheckable = true,
			menuList = A:GetWindowScaleMenu(),
		},
		{
			text = string.format("|cffffdd00Anchor side:|r %s", string.lower(self.db.global.AnchorSide)),
			hasArrow = true,
			notCheckable = true,
			menuList = {
				{
					text = "Anchor side", isTitle = true, notCheckable = true,
				},
				{
					text = "To the right",
					func = function() self.db.global.AnchorSide = "RIGHT"; A:UpdateFrame(); end,
					checked = function() return self.db.global.AnchorSide == "RIGHT"; end,
				},
				{
					text = "To the left",
					func = function() self.db.global.AnchorSide = "LEFT"; A:UpdateFrame(); end,
					checked = function() return self.db.global.AnchorSide == "LEFT"; end,
				},
			},
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Close FlashTalent window",
			func = function() FlashTalentFrame:Hide(); end,
			notCheckable = true,
		},
	};
	
	return data;
end

function A:OpenContextMenu(parentframe)
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", ADDON_NAME .. "ContextMenuFrame", parentframe, "UIDropDownMenuTemplate");
	end
	
	A.ContextMenu:SetPoint("BOTTOM", parentframe, "CENTER", 0, 5);
	EasyMenu(A:GetMenuData(), A.ContextMenu, "cursor", 0, 0, "MENU", 5);
	
	DropDownList1:ClearAllPoints();
	
	if(self.db.global.AnchorSide == "RIGHT") then
		DropDownList1:SetPoint("TOPLEFT", parentframe, "TOPRIGHT", 1, 0);
	elseif(self.db.global.AnchorSide == "LEFT") then
		DropDownList1:SetPoint("TOPRIGHT", parentframe, "TOPLEFT", 1, 0);
	end
end
