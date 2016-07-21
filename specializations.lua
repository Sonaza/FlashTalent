------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local LibQTip = LibStub("LibQTip-1.0");

function FlashTalentSpecButton_OnClick(self, button)
	if(button == "LeftButton") then
		Addon:ChangeDualSpec();
	elseif(button == "RightButton") then
		FlashTalentSpecButton.tooltip:Hide();
		Addon:OpenItemSetsMenu(self);
	end
end

function FlashTalentSpecButton_OnEnter(self)
	self.tooltip = LibQTip:Acquire("FlashTalentSpecButtonTooltip", 2, "LEFT", "RIGHT");
	Addon:OpenSpecializationsMenu(self, self.tooltip);
end

function Addon:OpenSpecializationsMenu(anchorFrame, tooltip)
	if(not tooltip) then return end
	
	tooltip:Clear();
	tooltip:ClearAllPoints();
	tooltip:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, -2);
	
	tooltip.category = 1;
	
	local areSpecsUnlocked = UnitLevel("player") >= SHOW_SPEC_LEVEL;
	
	tooltip:AddHeader("|cffffd200Specializations|r");
	tooltip:AddSeparator();
	
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, background, role = GetSpecializationInfo(specIndex);
		
		local color = "|cffeeeeee";
		local activeText = "";
		
		local isActiveSpecialization = (specIndex == GetSpecialization());
		
		if(isActiveSpecialization) then
			activeText = "|cff00ff00Active|r";
		end
		
		if(isActiveSpecialization or specIndex == Addon.db.char.PreviousSpec) then
			color = "|cff8ce2ff";
		end
		
		if(areSpecsUnlocked or isActiveSpecialization) then
			local lineIndex = tooltip:AddLine(
				string.format("%s %s%s|r %s", FLASHTALENT_ICON_PATTERN:format(icon), color, name, FLASHTALENT_ICON_ROLES[role]),
				activeText
			);
			
			if(areSpecsUnlocked) then
				tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization()) then
						SetSpecialization(specIndex);
					end
				end);
			end
		end
	end
	
	if(areSpecsUnlocked and (Addon.db.char.PreviousSpec == nil or Addon.db.char.PreviousSpec == 0)) then
		tooltip:AddLine(string.format("|cffffd200Left click a specialization to change to it.|r"));
	end
	
	if(areSpecsUnlocked) then
		local _, class = UnitClass("player");
		local petname = UnitName("pet");
		if(class == "HUNTER" and petname) then
			tooltip:AddLine(" ");
			tooltip:AddLine(string.format("|cffffd200%s's Specialization|r", petname));
			tooltip:AddSeparator();
			
			for specIndex = 1, GetNumSpecializations(false, true) do
				local id, name, description, icon, background, role = GetSpecializationInfo(specIndex, false, true);
				
				local activeText = "";
				
				if(specIndex == GetSpecialization(false, true)) then
					activeText = "|cff00ff00Active|r";
				end
				
				local lineIndex = tooltip:AddLine(string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), name), activeText);
				
				tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization(false, true)) then
						SetSpecialization(specIndex, true);
					end
				end);
			end
		end
	end
	
	if(areSpecsUnlocked) then
		tooltip:AddLine(" ");
		if(Addon.db.char.PreviousSpec ~= nil and Addon.db.char.PreviousSpec ~= 0) then
			local _, name, _, _, _, role = GetSpecializationInfo(Addon.db.char.PreviousSpec, false, false);
			tooltip:AddLine(string.format("|cff00ff00Left click|r  Switch back to |cffffd200%s|r %s", name, FLASHTALENT_ICON_ROLES[role]));
		end
	else
		tooltip:AddLine(string.format("|cffffd200Specializations unlock at level %s.|r", SHOW_SPEC_LEVEL));
		tooltip:AddLine(" ");
	end
	
	tooltip:AddLine("|cff00ff00Right click|r  View equipment sets.");
	
	tooltip:SetAutoHideDelay(0.35, anchorFrame);
	tooltip.OnRelease = function()
		tooltip = nil;
	end
	
	tooltip:Show();
end

function Addon:OpenSpecializationsMenuAtCursor(anchorFrame)
	local tooltip = LibQTip:Acquire("FlashTalentSpecButtonCursorTooltip", 2, "LEFT", "RIGHT");
	Addon:OpenSpecializationsMenu(anchorFrame, tooltip);
	
	if(tooltip) then
		tooltip:ClearAllPoints();
		tooltip:SetPoint("TOP", anchorFrame, "CENTER", 0, 1);
	end
end

function Addon:UpdateSpecTooltips()
	if(InCombatLockdown()) then return end
	
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and FlashTalentSpecButton.tooltip.category == 1) then
		FlashTalentSpecButton_OnEnter(FlashTalentSpecButton);
	end
	
	if(Addon.DataBrokerTooltip and Addon.DataBrokerTooltip:IsVisible()) then
		local _, parent = Addon.DataBrokerTooltip:GetPoint()
		Addon:DataBroker_OnEnter(parent);
	end
end

function Addon:HideSpecButtonTooltip()
	if(not FlashTalentSpecButton.tooltip) then return end
	
	FlashTalentSpecButton.tooltip:Hide();
	LibQTip:Release(FlashTalentSpecButton.tooltip);
	FlashTalentSpecButton.tooltip = nil;
end

function Addon:PLAYER_SPECIALIZATION_CHANGED(event, unit)
	if(InCombatLockdown()) then return end
	if(unit ~= "player") then return end
	
	if(Addon.OldSpecialization ~= nil and Addon.OldSpecialization ~= 0) then
		Addon.db.char.PreviousSpec = Addon.OldSpecialization;
	end
	
	Addon:UpdateTalentFrame();
	Addon:UpdateSpecTooltips();
	
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
	
	Addon:UpdateDatabrokerText();
end

function Addon:PET_SPECIALIZATION_CHANGED()
	Addon:UpdateSpecTooltips();
end

function Addon:ChangeDualSpec()
	if(Addon.db.char.PreviousSpec == 0) then return end
	SetSpecialization(Addon.db.char.PreviousSpec);
end