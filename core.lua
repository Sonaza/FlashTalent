------------------------------------------------------------
-- FlashTalent by Sonaza
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, SHARED = ...;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = A;
SHARED[1] = A;

local AceDB = LibStub("AceDB-3.0");
local LibQTip = LibStub("LibQTip-1.0");

local _;

BINDING_HEADER_FLASHTALENT = "FlashTalent";
_G["BINDING_NAME_CLICK FlashTalentFrameToggler:LeftButton"] = "Toggle FlashTalent";
_G["BINDING_NAME_FLASHTALENT_CHANGE_DUALSPEC"] = "Switch Dual Specs";
_G["BINDING_NAME_FLASHTALENT_OPEN_ITEM_SETS_MENU"] = "Open Equipment Menu at Cursor";

local ICON_PATTERN = "|T%s:14:14:0:0|t";
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

function A:OnInitialize()
	local defaults = {
		char = {
			AskedKeybind = false,
			AutoSwitchGearSet = false,
			SpecSets = {},
		},
		global = {
			AskedKeybind = false,
			Position = {
				Point = "CENTER",
				RelativePoint = "CENTER",
				x = 180,
				y = 0,
			},
			StickyWindow = false,
			IsWindowOpen = false,
			AlwaysShowTooltip = false,
			AnchorGlyphs = "RIGHT",
			ShowCooldown = true,
		},
	};
	
	self.db = AceDB:New("FlashTalentDB", defaults);
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
	A:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	A:RegisterEvent("PLAYER_TALENT_UPDATE");
	
	A:RegisterEvent("SCENARIO_UPDATE");
	A:RegisterEvent("CHALLENGE_MODE_START");
	A:RegisterEvent("CHALLENGE_MODE_RESET");
	A:RegisterEvent("CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET");
	
	A:RegisterEvent("USE_GLYPH");
	A:RegisterEvent("GLYPH_UPDATED");
	A:RegisterEvent("GLYPH_ADDED", "GLYPH_UPDATED");
	A:RegisterEvent("GLYPH_REMOVED", "GLYPH_UPDATED");
	
	A:RegisterEvent("PLAYER_LEVEL_UP");
	A:RegisterEvent("BAG_UPDATE_DELAYED");
	A:RegisterEvent("MODIFIER_STATE_CHANGED");
	
	A:RegisterEvent("SPELL_UPDATE_USABLE");
	self.updaterFrame = CreateFrame("Frame");
	self.updaterFrame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed;
		if(self.elapsed > 0.1) then
			A:UpdateTalentCooldowns();
			self.elapsed = 0;
		end
	end);
	
	A:RegisterEvent("EQUIPMENT_SWAP_FINISHED");
	A:RegisterEvent("EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED");
	
	A.SecureFrameToggler = CreateFrame("Button", "FlashTalentFrameToggler", nil, "SecureActionButtonTemplate");
	
	A.SecureFrameToggler:SetAttribute("type1", "macro");
	A.SecureFrameToggler:SetAttribute("macrotext",
		"/stopmacro [combat]\n"..
		"/click TalentMicroButton\n"..
		"/click [spec:1] PlayerSpecTab1\n"..
		"/click [spec:2] PlayerSpecTab2\n"..
		"/click PlayerTalentFrameTab3\n"..
		"/click PlayerTalentFrameTab2\n"..
		"/click TalentMicroButton\n"..
		"/run FlashTalent:ToggleFrame()"
	);
	
	A:UpdateTalentFrame();
	A:UpdateGlyphs();
	
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
	
	tinsert(UISpecialFrames, "FlashGlyphChangeFrame");
	
	if(not A:IsBindingSet() and not A:HasAskedBinding()) then
		StaticPopup_Show("FLASHTALENT_NO_KEYBIND");
	end
	
	if(C_Scenario.IsChallengeMode() and ScenarioChallengeModeBlock.timerID ~= nil) then
		A:CHALLENGE_MODE_START();
	end
	
	A:InitializeDatabroker();
end

function A:SPELL_UPDATE_USABLE()
	A:UpdateTalentCooldowns();
end

function A:HasChallengeModeRestriction()
	return C_Scenario.IsChallengeMode() and self.ChallengeModeActive;
end

function A:SCENARIO_UPDATE()
	if(not self.ChallengeModeActive and C_Scenario.IsChallengeMode() and ScenarioChallengeModeBlock.timerID ~= nil) then
		A:CHALLENGE_MODE_START();
	end
end

function A:CHALLENGE_MODE_START()
	self.ChallengeModeActive = true;
	A:UpdateTalentFrame();
	A:UpdateGlyphs();
	A:ClearSelections();
	FlashGlyphChangeFrame:Hide();
end

function A:CHALLENGE_MODE_RESET()
	self.ChallengeModeActive = false;
	A:UpdateTalentFrame();
	A:UpdateGlyphs();
end

function A:SavePosition()
	local point, _, relativePoint, x, y = FlashTalentFrame:GetPoint();
	self.db.global.Position.Point = point;
	self.db.global.Position.RelativePoint = relativePoint;
	self.db.global.Position.x = x;
	self.db.global.Position.y = y;
end

function A:RestorePosition()
	local position = self.db.global.Position;
	if(position and position.Point and position.RelativePoint and position.x and position.y) then
		FlashTalentFrame:ClearAllPoints();
		FlashTalentFrame:GetPoint(position.Point, UIparent, position.RelativePoint, position.x, position.y);
	end
end

function A:ToggleFrame()
	if(InCombatLockdown()) then return end
	
	if(not FlashTalentFrame:IsVisible()) then
		A:RestorePosition();
		
		A:UpdateTalentFrame();
		A:UpdateGlyphs();
		FlashTalentFrame:Show();
		-- FlashTalentFrame.fadein:Play();
	else
		FlashTalentFrame:Hide();
		FlashGlyphChangeFrame:Hide();
		-- FlashTalentFrame.fadeout:Play();
	end
	
	if(not A.ShortToggler) then
		A.ShortToggler = true;
		A.SecureFrameToggler:SetAttribute("macrotext", "/run FlashTalent:ToggleFrame()");
	end
end

function FlashTalentFrame_OnShow(self)
	A.db.global.IsWindowOpen = true;
end

function FlashTalentFrame_OnHide(self)
	if(A.EquipmentTooltip and A.EquipmentTooltip:IsVisible()) then
		LibQTip:Release(A.EquipmentTooltip);
		A.EquipmentTooltip = nil;
	end
	
	FlashGlyphChangeFrame:Hide();
	
	A.db.global.IsWindowOpen = false;
end

function FlashTalentFrame_OnFadeInPlay()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrame:Show();
end

function FlashTalentFrame_OnFadeOutFinished()
	if(InCombatLockdown()) then return end
	
	FlashTalentFrame:Hide();
	FlashGlyphChangeFrame:Hide();
end

function A:PLAYER_REGEN_DISABLED()
	if(not self.db.global.StickyWindow) then
		FlashTalentFrame:Hide();
	end
	
	FlashGlyphChangeFrame:Hide();
end

function A:BAG_UPDATE_DELAYED()
	if(InCombatLockdown()) then return end
	
	A:UpdateReagentCount()
end

function A:ACTIVE_TALENT_GROUP_CHANGED(event, activeSpec)
	if(InCombatLockdown()) then return end
	
	A:ClearSelections();
	FlashGlyphChangeFrame:Hide();
	
	A:UpdateTalentFrame();
	A:UpdateGlyphs();
	
	if(A.SpecTooltipOpen) then
		FlashTalentChangeDualSpecButton_OnEnter(FlashTalentChangeDualSpecButton);
	end
	
	if(self.db.char.AutoSwitchGearSet) then
		local setName;
		if(self.db.char.SpecSets[activeSpec]) then
			setName = self.db.char.SpecSets[activeSpec];
		end
		
		if(not setName or not GetEquipmentSetInfoByName(setName)) then
			local specID = GetSpecialization(false, false, activeSpec);
			if(specID) then
				local _, specName = GetSpecializationInfo(specID);
				setName = specName;
			end
		end
		
		local icon, setID, isEquipped, numItems, numEquipped, unknown, numMissing, numIgnored = GetEquipmentSetInfoByName(setName);
		if(icon ~= nil and not isEquipped) then
			if(numMissing == 0) then
				C_Timer.After(0.42, function()
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
	A:UpdateGlyphs();
	
	A:UpdateDatabrokerText();
end

function A:USE_GLYPH()
	if(InCombatLockdown()) then return end
	
	A:ClearSelections();
	FlashGlyphChangeFrame:Hide();
	
	A:UpdateDatabrokerText();
end

function A:GLYPH_UPDATED()
	if(InCombatLockdown()) then return end
	
	A:UpdateGlyphs();
	
	A:UpdateDatabrokerText();
end

function A:PLAYER_LEVEL_UP()
	if(InCombatLockdown()) then return end
	
	A:UpdateTalentFrame();
	A:UpdateGlyphs();
	
	A:UpdateDatabrokerText();
end

local glyphSlotLevels = {
	[1] = 25, -- Minor 1
	[2] = 25, -- Major 1
	[3] = 50, -- Minor 2
	[4] = 50, -- Major 2
	[5] = 75, -- Minor 3
	[6] = 75, -- Major 3
}

function A:UpdateGlyphs()
	if(InCombatLockdown()) then return end
	
	for glyphIndex = 1, 6 do
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		local glyph = _G['FlashGlyphsFrameGlyph' .. glyphIndex];
		
		glyph.glyphType = glyphType;
		glyph.ring:SetVertexColor(0, 0, 0);
		
		glyph.levelText:SetText(glyphSlotLevels[glyphIndex]);
		if(not enabled) then
			glyph.levelText:Show();
		else
			glyph.levelText:Hide();
		end
		
		if(glyphID and not A:HasChallengeModeRestriction()) then
			glyph:SetAttribute("shift-type2", "macro");
			glyph:SetAttribute("macrotext",
				"/stopmacro [combat]\n" ..
				"/click PlayerTalentFrameTab3\n"..
				"/click [spec:1] PlayerSpecTab1\n"..
				"/click [spec:2] PlayerSpecTab2\n"..
				"/click GlyphFrameGlyph" .. glyphIndex .. " RightButton\n" ..
				"/click StaticPopup1Button1\n"
			);
		elseif(A:HasChallengeModeRestriction()) then
			glyph:SetAttribute("macrotext", "");
		end
		
		glyph.unlocked = enabled;
		
		if(not enabled) then
			glyph.spell = nil;
			glyph.glyphID = nil;
			
			SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
			glyph.icon:SetVertexColor(0.2, 0.2, 0.2);
			glyph.icon:SetDesaturated(true);
			glyph:SetAlpha(0.9);
		elseif(not glyphSpell) then
			glyph.spell = nil;
			glyph.glyphID = nil;
			
			SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
			glyph.icon:SetVertexColor(0.4, 0.4, 0.4);
			glyph.icon:SetDesaturated(true);
			glyph:SetAlpha(1.0);
		else
			glyph.spell = glyphSpell;
			glyph.glyphID = glyphID;
			
			if(icon) then
				SetPortraitToTexture(glyph.icon, icon);
				glyph.icon:SetVertexColor(1.0, 1.0, 1.0);
				glyph.icon:SetDesaturated(false);
			else
				SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
				glyph.icon:SetVertexColor(0.4, 0.4, 0.4);
				glyph.icon:SetDesaturated(true);
			end
			
			glyph:SetAlpha(1.0);
		end
	end
end

function FlashGlyphButtonTemplate_OnLoad(self)
	self.glow:Play();
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function FlashGlyphButtonTemplate_OnEnter(self)
	if(self.unlocked and not A:HasChallengeModeRestriction()) then
		self.glow:Play();
		self.highlight:Show();
		-- self.ring:SetVertexColor(1, 1, 1);
	end
	
	if(IsShiftKeyDown() or A.db.global.AlwaysShowTooltip) then
		local glyphIndex = self:GetID();
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		if(glyphID) then
			GameTooltip:SetGlyphByID(glyphID);
		else
			if(glyphType == 1) then
				GameTooltip:AddLine("Empty Major Glyph Slot");
			elseif(glyphType == 2) then
				GameTooltip:AddLine("Empty Minor Glyph Slot");
			end
		end
		
		if(enabled) then
			if(glyphID) then
				GameTooltip:AddLine("Left click to change the glyph.", 0, 1, 0);
				GameTooltip:AddLine("Shift-Right click to unlearn.", 0, 1, 0);
			else
				GameTooltip:AddLine("Left click to set the glyph.", 0, 1, 0);
			end
		else
			GameTooltip:AddLine(string.format("Glyph Slot Unlocked at Level %d.", glyphSlotLevels[glyphIndex]), 1, 0, 0);
		end
		
		GameTooltip:Show();
	end
	
	A.HoveredGlyph = self;
end

function FlashGlyphButtonTemplate_OnLeave(self)
	GameTooltip:Hide();
	A.HoveredGlyph = nil;
	
	if(not self.isSelected) then
		self.highlight:Hide();
		self.ring:SetVertexColor(0, 0, 0);
	end
end

function A:ChangeDualSpec()
	if(GetNumSpecGroups() <= 1) then return end
	
	local activeSpec = GetActiveSpecGroup();
	if(activeSpec == 1) then SetActiveSpecGroup(2); end
	if(activeSpec == 2) then SetActiveSpecGroup(1); end
end

function FlashTalentChangeDualSpecButton_OnClick(self, button)
	if(button == "LeftButton") then
		A:ChangeDualSpec();
	elseif(button == "RightButton") then
		A.SpecTooltipOpen = false;
		GameTooltip:Hide();
		A:OpenItemSetsMenu(self);
	end
end

function FlashTalentChangeDualSpecButton_OnEnter(self)
	if(A.EquipmentTooltip and A.EquipmentTooltip:IsVisible()) then return end
	
	GameTooltip:ClearAllPoints();
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE");
	GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, -2);
	
	GameTooltip:AddLine("Specializations");
	
	local activeSpec = GetActiveSpecGroup();
	local numSpecs = GetNumSpecGroups();
	
	for specIndex = 1, numSpecs do
		local spec = GetSpecialization(false, false, specIndex);
		local name, description, icon;
		
		if(not spec) then
			icon = "Interface\\Icons\\Ability_Marksmanship";
			name = string.format("Specialization %d", specIndex);
		else
			_, name, description, icon = GetSpecializationInfo(spec);
		end
		
		if(specIndex == activeSpec) then
			GameTooltip:AddDoubleLine(string.format("%s %s", ICON_PATTERN:format(icon), name), "Active", 1, 1, 1, 0, 1, 0);
		else
			GameTooltip:AddDoubleLine(string.format("%s %s", ICON_PATTERN:format(icon), name), "", 1, 1, 1, 0, 1, 0);
		end
	end
	
	if(numSpecs < 2) then
		GameTooltip:AddDoubleLine(string.format("%s Specialization 2", ICON_PATTERN:format("Interface\\Icons\\Ability_Marksmanship"), name), "Locked", 1, 1, 1, 1, 0.2, 0.2);
		GameTooltip:AddLine(" ");
		
		local playerLevel = UnitLevel("player");
		
		if(playerLevel < 30) then
			GameTooltip:AddLine("Reach level 30 to unlock dual specialiation!");
		else
			GameTooltip:AddLine("Visit your class trainer to learn dual specialiation!");
		end
	end
	
	GameTooltip:AddLine(" ");
	
	if(numSpecs > 1) then
		GameTooltip:AddLine("Left click to switch specs", 0, 1, 0);
	end
	
	GameTooltip:AddLine("Right click to view equipment sets", 0, 1, 0);
	GameTooltip:Show();
	
	A.SpecTooltipOpen = true;
end

function FlashTalentChangeDualSpecButton_OnLeave(self)
	GameTooltip:Hide();
	A.SpecTooltipOpen = false;
end

local function GetCheckButtonTexture(checked)
	if(checked) then return CHECKBUTTON_ICON_PATTERN:format("Interface\\Buttons\\UI-CheckBox-Check") end
	return CHECKBUTTON_ICON_PATTERN:format("Interface\\Buttons\\UI-CheckBox-Up");
end

function A:EQUIPMENT_SWAP_FINISHED(event, success, setName)
	if(self.EquipmentTooltip and self.EquipmentTooltip:IsVisible()) then
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

function A:OpenItemSetsMenu(anchorFrame, forceRefresh, setName)
	if(self.EquipmentTooltip and self.EquipmentTooltip:IsVisible() and not forceRefresh) then return end
	
	local tooltip;
	local positionData = {};
	
	if(forceRefresh and self.EquipmentTooltip) then
		positionData = { self.EquipmentTooltip:GetPoint() };
		
		LibQTip:Release(self.EquipmentTooltip);
		self.EquipmentTooltip = nil;
	end
	
	tooltip = LibQTip:Acquire("FlashTalentEquipmentTooltip", 2, "LEFT", "RIGHT");
	self.EquipmentTooltip = tooltip;
	
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
				local specID = GetSpecialization(false, false, specSets[name]);
				local _, specName, _, specIcon = GetSpecializationInfo(specID);
				specSetName = string.format(" |cffaaaaaa%s %s|r", strtrim(ICON_PATTERN:format(specIcon)), specName);
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
				GameTooltip:AddLine("Left click |cffffffff| Switch to this set", 0, 1, 0);
				GameTooltip:AddLine("Right click |cffffffff| Rename the set", 0, 1, 0);
				GameTooltip:AddLine("Shift Middle click |cffffffff| Update set", 0, 1, 0);
				GameTooltip:AddLine(" ");
				
				if(not specSets[name] or specSets[name] ~= GetActiveSpecGroup()) then
					local _, specName, _, specIcon = GetSpecializationInfo(GetSpecialization());
					GameTooltip:AddLine(string.format("Ctrl-Shift Right click |cffffffff| Tag this set for |cffffffff%s %s|r", ICON_PATTERN:format(specIcon), specName), 0, 1, 0);
				else
					GameTooltip:AddLine("Ctrl-Shift Right click |cffffffff| Remove spec tag from this set", 0, 1, 0);
				end
				
				GameTooltip:Show();
			end);
			
			tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
				GameTooltip:Hide();
			end);
			
			tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
				if(IsShiftKeyDown() and IsControlKeyDown() and button == "RightButton") then
					local activeSpec = GetActiveSpecGroup();
					if(A.db.char.SpecSets[activeSpec] == name) then
						A.db.char.SpecSets[activeSpec] = nil;
					else
						A.db.char.SpecSets[activeSpec] = name;
						
						local inactiveSpec = 3-activeSpec;
						if(A.db.char.SpecSets[inactiveSpec] == name) then
							A.db.char.SpecSets[inactiveSpec] = nil;
						end
					end
					
					A:RefreshItemSetsMenu();
				elseif(IsShiftKeyDown() and button == "MiddleButton") then
					A:UpdateEquipmentSet(name);
				elseif(button == "RightButton") then
					local icon, setID = GetEquipmentSetInfoByName(name);
					icon = "Interface\\Icons\\" .. icon;
					
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
		GameTooltip:AddLine("Enable this to automatically change equipment set when changing dual specs.", 1, 1, 1, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("If an equipment set with the spec name exists it will be automatically equipped if no items are missing.", 1, 1, 1, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("Alternatively you can also tag an equipment set specific to a set and still use a separate name if you |cffffdd00Ctrl-Shift Right click|r the set in the list. Tagged sets have priority.", 1, 1, 1, true);
		
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
		
		SetCVar("characterFrameCollapsed", "0");
		CharacterFrame_Expand();
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

function A:ClearSelections(skip)
	for glyphIndex = 1, 6 do
		if(not skip or glyphIndex ~= skip) then
			local glyph = _G['FlashGlyphsFrameGlyph' .. glyphIndex];
			glyph.isSelected = false;
			glyph.highlight:Hide();
			glyph.ring:SetVertexColor(0, 0, 0);
		end
	end
end

function FlashGlyphButtonTemplate_PostClick(self, button)
	if(A:HasChallengeModeRestriction()) then
		UIErrorsFrame:AddMessage("Cannot change glyphs while in Challenge Mode.", 1.0, 0.1, 0.1, 1.0);
		return;
	elseif(button == "LeftButton") then
		local glyphIndex = self:GetID();
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		if(enabled) then
			if(not self.isSelected) then
				A:ClearSelections(glyphIndex);
				A:OpenGlyphChangeMenu(self, glyphIndex, glyphType, glyphID);
				self.isSelected = true;
			
				self.ring:SetVertexColor(1, 1, 1);
			else
				FlashGlyphChangeFrame:Hide();
				self.highlight:Show();
				self.isSelected = false;
			
				self.ring:SetVertexColor(0, 0, 0);
			end
		end
	end
end

function FlashGlyphChangeFrame_OnShow()
	
end

function FlashGlyphChangeFrame_OnHide()
	A:ClearSelections();
end

function A:GetUsableGlyphs()
	local glyphs = {
		[GLYPH_TYPE_MAJOR] = {},
		[GLYPH_TYPE_MINOR] = {},
	};
	
	local numGlyphs = GetNumGlyphs();
	for index = 1, numGlyphs do
		local name, glyphType, isKnown, icon, glyphID, glyphLink, spec, specMatches, excluded = GetGlyphInfo(index);
		if(name ~= "header" and isKnown == true and icon and specMatches) then
			tinsert(glyphs[glyphType], {
				index = index,
				name = name,
				icon = icon,
				glyphID = glyphID,
				spec = spec,
				excluded = excluded,
			});
		end
	end
	
	return glyphs;
end

function A:IsGlyphInUse(glyphID)
	local numGlyphs = GetNumGlyphs();
	for glyphIndex = 1, numGlyphs do
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, socketedGlyphID = GetGlyphSocketInfo(glyphIndex);
		if(glyphID == socketedGlyphID) then return true end
	end
	
	return false;
end

function A:OpenGlyphChangeMenu(glyphFrame, glyphIndex, glyphType, isActive)
	if(InCombatLockdown()) then return end
	if(not (glyphFrame and glyphIndex and glyphType)) then return end
	
	local glyphs = A:GetUsableGlyphs();
	local numGlyphs = #glyphs[glyphType];
	
	local slotName;
	if(glyphType == 1) then
		slotName = string.format("major%d", glyphIndex / 2);
	elseif(glyphType == 2) then
		slotName = string.format("minor%d", (glyphIndex + 1) / 2);
	end
	
	local columns = math.min(6, numGlyphs);
	local rows = math.ceil(numGlyphs / 6);
	
	FlashGlyphChangeFrame:SetWidth(columns * 28);
	FlashGlyphChangeFrame:SetHeight(rows * 28);
	
	local rowFirstButton = FlashGlyphChangeFrameButton1;
	local previousButton = FlashGlyphChangeFrameButton1;
	
	for index = 1, 50 do
		local button = _G['FlashGlyphChangeFrameButton' .. index];
		if(button) then
			button.glyphID = nil;
			button:SetAttribute("type", nil);
			button:Hide()
		else
			break;
		end
	end
	
	if(numGlyphs > 0) then
		local _, reagentCount = GetGlyphClearInfo();
		local hasReagents = (reagentCount or 0) > 0;
		
		FlashGlyphChangeFrame.noGlyphsWarning:Hide();
		
		for index = 1, numGlyphs do
			local data = glyphs[glyphType][index];
			
			local button = _G['FlashGlyphChangeFrameButton' .. index];
			if(not button) then
				button = CreateFrame("Button", 'FlashGlyphChangeFrameButton' .. index, FlashGlyphChangeFrame, "FlashGlyphChangeButtonTemplate");
				
				if(index ~= 1 and (index - 1) % 6 == 0) then
					button:SetPoint("TOPLEFT", rowFirstButton, "BOTTOMLEFT", 0, 0);
				elseif(index ~= 1) then
					button:SetPoint("TOPLEFT", previousButton, "TOPRIGHT", 0, 0);
				end
			end
			
			if(index ~= 1 and (index - 1) % 6 == 0) then
				rowFirstButton = button;
			end
			previousButton = button;
			
			button.freeChange = (glyphFrame.glyphID == nil);
			
			button.glyphID = data.glyphID;
			button.isActive = (data.glyphID == isActive);
			button.glyphInUse = A:IsGlyphInUse(data.glyphID);
			button.excluded = data.excluded;
			
			button.icon:SetTexture(data.icon);
			button.icon:SetVertexColor(0.9, 0.9, 0.9);
			button.icon:SetDesaturated(false);
			
			if(data.excluded) then
				button:SetAttribute("type", nil);
				button.icon:SetVertexColor(1.0, 0.2, 0.2);
				button.icon:SetDesaturated(true);
			elseif(button.glyphInUse) then
				button:SetAttribute("type", nil);
				button.icon:SetVertexColor(0.42, 0.42, 0.42);
				button.icon:SetDesaturated(true);
			elseif(not button.glyphInUse) then
				button:SetAttribute("type", "glyph");
				button:SetAttribute("glyph", data.name);
				button:SetAttribute("slot", slotName);
			end
			
			if(not hasReagents and glyphFrame.glyphID ~= nil) then
				button:SetAttribute("type", nil);
			end
			
			button:Show();
		end
	else
		FlashGlyphChangeFrame.noGlyphsWarning:Show();
		FlashGlyphChangeFrame:SetWidth(160);
		FlashGlyphChangeFrame:SetHeight(32);
	end
	
	FlashGlyphChangeFrame:SetParent(glyphFrame);
	FlashGlyphChangeFrame:ClearAllPoints();
	
	if(self.db.global.AnchorGlyphs == "RIGHT") then
		FlashGlyphChangeFrame:SetPoint("TOPLEFT", glyphFrame, "TOPRIGHT", 8, -1);
	elseif(self.db.global.AnchorGlyphs == "LEFT") then
		FlashGlyphChangeFrame:SetPoint("TOPRIGHT", glyphFrame, "TOPLEFT", -8, -1);
	end
	FlashGlyphChangeFrame:Show();
end

function FlashGlyphChangeButtonTemplate_PostClick(self)
	if(not self.excluded and not self.glyphInUse) then
		local reagent, reagentCount, reagentIcon, _, cost = GetGlyphClearInfo();
			
		if(reagentCount > 0 or self.freeChange or cost == 0) then
			FlashGlyphChangeFrame:Hide();
		elseif(reagentCount == 0 and not self.freeChange) then
			StaticPopup_Show("FLASHTALENT_NOT_ENOUGH_REAGENTS", "glyph", string.format("%s %s", ICON_PATTERN:format(reagentIcon), reagent));
		end
	end
end

function FlashGlyphChangeButtonTemplate_OnEnter(self)
	self.icon:SetVertexColor(1.0, 1.0, 1.0);
	
	if(self.excluded) then
		self.icon:SetVertexColor(1.0, 0.4, 0.4);
	elseif(self.glyphInUse) then
		self.icon:SetVertexColor(0.8, 0.8, 0.8);
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetGlyphByID(self.glyphID);
	if(not self.excluded and not self.glyphInUse) then
		GameTooltip:AddLine("Left click to change to this glyph.", 0, 1, 0);
	elseif(self.glyphInUse) then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("This glyph is currently in use.", 0.38, 0.77, 1.0);
	end
	GameTooltip:Show();
end

function FlashGlyphChangeButtonTemplate_OnLeave(self)
	self.icon:SetVertexColor(0.9, 0.9, 0.9);
	
	if(self.excluded) then
		self.icon:SetVertexColor(0.9, 0.3, 0.3);
	elseif(self.glyphInUse) then
		self.icon:SetVertexColor(0.3, 0.3, 0.3);
	end
	
	GameTooltip:Hide();
end
	
---------------------------------------------

function A:SetTalentTooltip(talentButton)
	GameTooltip:SetOwner(talentButton, "ANCHOR_RIGHT");
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
	
	GameTooltip:Show();
end

function FlashTalentButtonTemplate_OnEnter(self)
	if(self.tierFree and self.isUnlocked) then
		self.icon:SetVertexColor(1.0, 1.0, 1.0);
	elseif(not self.isSelected) then
		self.icon:SetVertexColor(0.35, 0.35, 0.35);
	else
		self.icon:SetVertexColor(1.0, 1.0, 1.0);
	end
	
	if(IsShiftKeyDown() or A.db.global.AlwaysShowTooltip) then
		A:SetTalentTooltip(self);
	end
	
	A.HoveredTalent = self;
end

function FlashTalentButtonTemplate_OnLeave(self)
	if(self.tierFree and self.isUnlocked) then
		self.icon:SetVertexColor(0.6, 0.6, 0.6);
	elseif(not self.isSelected) then
		self.icon:SetVertexColor(0.22, 0.22, 0.22);
	else
		self.icon:SetVertexColor(0.9, 0.9, 0.9);
	end
	
	GameTooltip:Hide();
	
	A.HoveredTalent = nil;
end

function A:MODIFIER_STATE_CHANGED(event, key, state)
	if(InCombatLockdown()) then return end
	
	if(not A.HoveredTalent and not A.HoveredGlyph) then return end
	
	if(key == "LSHIFT" or key == "RSHIFT") then
		if(state == 1) then
			if(A.HoveredTalent) then
				A:SetTalentTooltip(A.HoveredTalent);
			end
			
			if(A.HoveredGlyph) then
				FlashGlyphButtonTemplate_OnEnter(A.HoveredGlyph);
			end
		else
			GameTooltip:Hide();
		end
	end
end

function FlashTalentButtonTemplate_OnDragStart(self)
	if(InCombatLockdown() or not self.isSelected) then return end
	
	if(not IsAltKeyDown()) then
		PickupTalent(self.talentID);
	end
end

function FlashTalent_Learn(tier, talentID)
	if(InCombatLockdown()) then return end
	
	local isFree = GetTalentRowSelectionInfo(tier);
	C_Timer.After(isFree and 0 or 0.1, function()
		LearnTalents(talentID);
		A:DisableLearnButton();
	end);
end

function A:HighlightTalent(highlightTier, highlightColumn)
	for column = 1, 3 do
		local buttonName = string.format("FlashTalentFrameTier%dTalent%d", highlightTier, column);
		local button = _G[buttonName];
		
		if(button) then
			if(column == highlightColumn) then
				button.icon:SetVertexColor(0.9, 0.9, 0.9);
			else
				button.icon:SetVertexColor(0.22, 0.22, 0.22);
			end
		end
	end
end

function A:DisableLearnButton()
	PlayerTalentFrameTalentsLearnButton:Disable();
	PlayerTalentFrameTalentsLearnButton.Flash:Hide();
	PlayerTalentFrameTalentsLearnButton.FlashAnim:Stop();
end

function FlashTalentButtonTemplate_PreClick(self)
	if(A:HasChallengeModeRestriction()) then
		UIErrorsFrame:AddMessage("Cannot change talents while in Challenge Mode.", 1.0, 0.1, 0.1, 1.0);
	else
		local reagent, reagentCount, reagentIcon, _, cost = GetTalentClearInfo();
		if(reagentCount == 0 and not self.tierFree and self.isUnlocked and not self.isSelected and cost ~= 0) then
			StaticPopup_Show("FLASHTALENT_NOT_ENOUGH_REAGENTS", "talent", string.format("%s %s", ICON_PATTERN:format(reagentIcon), reagent));
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
			local talentID, spellName, icon = GetTalentInfo(tier, column, group);
			local isFree, selection = GetTalentRowSelectionInfo(tier);
			
			if(selection == talentID) then
				local start, duration, enable = GetSpellCooldown(spellName);
				
				if(start and duration and start > 0 and duration > 0) then
					local remaining = start + duration - GetTime();
					
					tierFrame.lockFade:Show();
					tierFrame.lockFade.levelText:SetText(A:FormatTime(remaining));
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

function A:UpdateTalentFrame()
	if(InCombatLockdown()) then return end
	
	A.SelectedTalents = {};
	
	local group = GetActiveSpecGroup();
	
	local playerLevel = UnitLevel("player");
	local _, playerClass = UnitClass("player");
	
	local tierLevels = CLASS_TALENT_LEVELS[playerClass] or CLASS_TALENT_LEVELS.DEFAULT;
	
	local _, reagentCount = GetTalentClearInfo();
	local hasReagents = (reagentCount or 0) > 0;
	
	for tier = 1, 7 do
		A:HighlightTalent(tier, -1);
		
		local tierFrame = _G[string.format("FlashTalentFrameTier%d", tier)];
		
		local isUnlocked = (playerLevel >= tierLevels[tier]);
		if(not isUnlocked) then
			tierFrame.lockFade.levelText:SetText(tierLevels[tier]);
			tierFrame.lockFade:Show();
		else
			tierFrame.lockFade:Hide();
		end
		
		for column = 1, 3 do
			local button = tierFrame["talent" .. column];
			
			local talentID, spellName, icon = GetTalentInfo(tier, column, group);
			local isFree, selection = GetTalentRowSelectionInfo(tier);
			local isSelected = (selection == talentID);
			
			button:SetAttribute("type1", "macro");
			
			if(isSelected) then
				A:HighlightTalent(tier, column);
				A.SelectedTalents[tier] = {
					column = column,
					talentID = talentID,
				};
				
				button:SetAttribute("macrotext", "");
			elseif(not isUnlocked or (not hasReagents and not isFree)) then
				button:SetAttribute("macrotext", "");
			elseif(talentID) then
				if(isFree) then
					button.icon:SetVertexColor(0.6, 0.6, 0.6);
					button:SetAttribute("macrotext",
						"/stopmacro [combat]\n" ..
						"/click TalentMicroButton\n"..
						"/click PlayerTalentFrameTab2\n"..
						"/click [spec:1] PlayerSpecTab1\n"..
						"/click [spec:2] PlayerSpecTab2\n"..
						"/click TalentMicroButton\n"..
						"/run FlashTalent_Learn(" .. tier .. ", " .. talentID .. ")\n"
					);
				else
					local talentButton = string.format("PlayerTalentFrameTalentsTalentRow%dTalent%d", tier, column);
					button:SetAttribute("macrotext",
						"/stopmacro [combat]\n" ..
						"/click TalentMicroButton\n"..
						"/click PlayerTalentFrameTab2\n"..
						"/click [spec:1] PlayerSpecTab1\n"..
						"/click [spec:2] PlayerSpecTab2\n"..
						"/click " .. talentButton .. "\n" ..
						"/click StaticPopup1Button1\n" ..
						"/click TalentMicroButton\n"..
						"/run FlashTalent_Learn(" .. tier .. ", " .. talentID .. ")\n"
					);
				end
			end
			
			if(A:HasChallengeModeRestriction()) then
				button:SetAttribute("macrotext", "");
			end
			
			button.talentID = talentID;
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
	
	A:UpdateReagentCount();
end

function A:UpdateReagentCount()
	local reagent, reagentCount, reagentIcon, _, cost = GetTalentClearInfo();
	if(reagentIcon) then
		local textPattern = "%s %d";
		if(cost == 0) then
			textPattern = "%s |cff4aff22%d|r";
		elseif(reagentCount == 0) then
			textPattern = "%s |cffff2222%d|r";
		end
		
		FlashTalentReagentText:SetFormattedText(textPattern, ICON_PATTERN:format(reagentIcon), reagentCount);
	else
		FlashTalentReagentText:SetText("");
	end
end

function FlashTalentFrame_OnMouseDown(self)
	if(IsAltKeyDown()) then
		FlashTalentFrame:StartMoving();
		FlashTalentFrame.isMoving = true;
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
	
	if(A.db.global.AnchorGlyphs == "RIGHT") then
		GameTooltip:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", 2, 6);
	elseif(A.db.global.AnchorGlyphs == "LEFT") then
		GameTooltip:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", -2, 6);
	end
	
	GameTooltip:AddLine("FlashTalent Pro Tips")
	GameTooltip:AddLine("Switch talents by hovering the one you wish to change to and left click it.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Switch glyphs by left clicking the glyph slot to open glyphs menu, choose a glyph and left click it. Remove glyph from slot by shift right clicking it.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Hold Alt and drag to move FlashTalent", 0, 1, 0);
	if(not A.db.global.AlwaysShowTooltip) then
		GameTooltip:AddLine("Hold Shift when hovering to display tooltip", 0, 1, 0);
	end
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Click this icon to view options", 1, 0.8, 0);
	
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
	
	if(self.db.global.AnchorGlyphs == "RIGHT") then
		FlashGlyphsFrame:ClearAllPoints();
		FlashGlyphsFrame:SetPoint("TOPLEFT", FlashTalentFrameTier1, "TOPRIGHT", 7, 0);
	elseif(self.db.global.AnchorGlyphs == "LEFT") then
		FlashGlyphsFrame:ClearAllPoints();
		FlashGlyphsFrame:SetPoint("TOPRIGHT", FlashTalentFrameTier1, "TOPLEFT", -7, 0);
	end
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
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Anchor glyphs", isTitle = true, notCheckable = true,
		},
		{
			text = "To the right",
			func = function() self.db.global.AnchorGlyphs = "RIGHT"; A:UpdateFrame(); end,
			checked = function() return self.db.global.AnchorGlyphs == "RIGHT"; end,
		},
		{
			text = "To the left",
			func = function() self.db.global.AnchorGlyphs = "LEFT"; A:UpdateFrame(); end,
			checked = function() return self.db.global.AnchorGlyphs == "LEFT"; end,
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
	
	if(self.db.global.AnchorGlyphs == "RIGHT") then
		DropDownList1:SetPoint("TOPLEFT", parentframe, "TOPRIGHT", 1, 0);
	elseif(self.db.global.AnchorGlyphs == "LEFT") then
		DropDownList1:SetPoint("TOPRIGHT", parentframe, "TOPLEFT", 1, 0);
	end
end