------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local LibStub = LibStub;
local AceDB = LibStub("AceDB-3.0");
local LibQTip = LibStub("LibQTip-1.0");

function Addon:EQUIPMENT_SWAP_FINISHED(event, success, setID)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and FlashTalentSpecButton.tooltip.category == 2) then
		Addon:RefreshItemSetsMenu(setID);
	end
	
	if(success) then
		PaperDollEquipmentManagerPane.selectedSetID = setID;
		PaperDollFrame_ClearIgnoredSlots();
		PaperDollFrame_IgnoreSlotsForSet(setID);
		PaperDollEquipmentManagerPane_Update(true);
		
		Addon:UpdateDatabrokerText();
	end
end

function Addon:UpdateEquipmentSet(setID)
	PaperDollFrame_ClearIgnoredSlots();
	PaperDollFrame_IgnoreSlotsForSet(setID);
	C_EquipmentSet.SaveEquipmentSet(setID);
end

function Addon:OpenItemSetsMenuAtCursor(anchorFrame)
	local tooltip = Addon:OpenItemSetsMenu(anchorFrame);
	
	if(tooltip) then
		tooltip:ClearAllPoints();
		tooltip:SetPoint("BOTTOM", anchorFrame, "CENTER", 0, -1);
	end
end

function Addon:RefreshItemSetsMenu(setID)
	Addon:OpenItemSetsMenu(Addon.ItemSetsMenuParent, true, setID);
end

function Addon:OpenItemSetsMenu(anchorFrame, forceRefresh, changedSetID)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and not forceRefresh) then return end
	
	local positionData = {};
	if(forceRefresh and FlashTalentSpecButton.tooltip) then
		positionData = { FlashTalentSpecButton.tooltip:GetPoint() };
	end
	
	FlashTalentSpecButton.tooltip = LibQTip:Acquire("FlashTalentSpecButtonTooltip", 2, "LEFT", "RIGHT");
	FlashTalentSpecButton.tooltip.category = 2;
	
	local tooltip = FlashTalentSpecButton.tooltip;
	
	tooltip:Clear();
	tooltip:AddHeader("|cffffd200Equipment Sets|r");
	
	local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
	local numEquipmentSets = C_EquipmentSet.GetNumEquipmentSets();
	if(equipmentSetIDs and numEquipmentSets > 0) then
		for index, setID in ipairs(equipmentSetIDs) do
			local lineIndex;
			local setName, icon, _, isEquipped, numItems, numEquipped, numInventory, numMissing, numIgnored = C_EquipmentSet.GetEquipmentSetInfo(setID);
			
			if(icon == nil) then
				icon = "Interface\\icons\\INV_Misc_QuestionMark";
			end
			
			if(changedSetID) then
				isEquipped = (changedSetID == setID);
			end
			
			local specSetName = "";
			local assignedSpecID = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID);
			if(assignedSpecID) then
				local _, specName, _, specIcon = GetSpecializationInfo(assignedSpecID, nil, nil, nil, UnitSex("player"));
				specSetName = string.format(" |cffffee22%s %s|r", strtrim(FLASHTALENT_ICON_PATTERN:format(specIcon)), specName);
			elseif(Addon.db.char.MatchSpecNames) then
				local _, specName, _, specIcon = Addon:GetSpecializationInfoBySpecName(setName);
				if(specName) then
					specSetName = string.format(" |cffaaaaaa%s %s|r", strtrim(FLASHTALENT_ICON_PATTERN:format(specIcon)), specName);
				end
			end
			
			local equipmentTitle;
			if(isEquipped) then
				lineIndex = tooltip:AddLine(string.format("%s |cff33ff00%s (equipped)|r", FLASHTALENT_ICON_PATTERN:format(icon), setName), specSetName);
			elseif(numMissing > 0) then
				lineIndex = tooltip:AddLine(string.format("%s |cffff2222%s|r (%d missing)", FLASHTALENT_ICON_PATTERN:format(icon), setName, numMissing), specSetName);
			else
				lineIndex = tooltip:AddLine(string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), setName), specSetName);
			end
			
			tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_LEFT");
				GameTooltip:SetEquipmentSet(setID);
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine("Left click  |cffffffffSwitch to this set", 0, 1, 0);
				GameTooltip:AddLine("Right click  |cffffffffRename the set", 0, 1, 0);
				GameTooltip:AddLine("Shift Middle click  |cffffffffUpdate set", 0, 1, 0);
				GameTooltip:AddLine(" ");
				
				if(not assignedSpecID or assignedSpecID ~= GetSpecialization()) then
					local _, specName, _, specIcon = GetSpecializationInfo(GetSpecialization(), nil, nil, nil, UnitSex("player"));
					GameTooltip:AddLine(string.format("Ctrl Shift Right click  |cffffffffTag this set for |cffffffff%s %s|r", FLASHTALENT_ICON_PATTERN:format(specIcon), specName), 0, 1, 0);
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
					
					local assignedSpecID = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID);
					if(assignedSpecID ~= activeSpec) then
						C_EquipmentSet.AssignSpecToEquipmentSet(setID, activeSpec);
					else
						C_EquipmentSet.UnassignEquipmentSetSpec(setID);
					end
					PaperDollEquipmentManagerPane_Update(true);
					
					Addon:RefreshItemSetsMenu();
					
				elseif(IsShiftKeyDown() and button == "MiddleButton") then
					Addon:UpdateEquipmentSet(setID);
					
				elseif(button == "RightButton") then
					local setName, icon = C_EquipmentSet.GetEquipmentSetInfo(setID);
					StaticPopup_Show("FLASHTALENT_RENAME_EQUIPMENT_SET", string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), setName), nil, {
						oldName = setName,
						setID = setID,
					});
					
				elseif(button == "LeftButton") then
					C_EquipmentSet.UseEquipmentSet(setID);
				end
			end);
		end
	else
		local lineIndex = tooltip:AddLine("No Equipment Sets");
		tooltip:SetLineTextColor(lineIndex, 0.6, 0.6, 0.6);
	end
	
	tooltip:AddSeparator();
	
	local lineIndex;
	if(self.db.char.MatchSpecNames) then
		lineIndex = tooltip:AddLine("|cffffd200Match Spec Names|r", "|cff33ff00Enabled|r");
	else
		lineIndex = tooltip:AddLine("|cffffd200Match Spec Names|r", "|cffff2222Disabled|r");
	end
	
	tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", -6, 0);
		GameTooltip:SetWidth(280);
		
		GameTooltip:AddLine("Match Spec Names");
		GameTooltip:AddLine("Enable this to match set names to spec names. If an equipment set with the spec name exists it will be automatically equipped if no items are missing.", 1, 1, 1, true);
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("You can also tag an equipment set for a specialization by |cffffd200Ctrl Shift Right clicking|r the set name in the list. Tagged sets will be always switched to and have priority.", 1, 1, 1, true);
		
		GameTooltip:Show();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
		GameTooltip:Hide();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self)
		Addon.db.char.MatchSpecNames = not Addon.db.char.MatchSpecNames;
		Addon:RefreshItemSetsMenu();
	end);
	
	Addon:AddScriptedTooltipLine(tooltip, "|cffffd200Open Equipment Manager|r", function()
		if(not PaperDollFrame:IsVisible()) then
			ToggleCharacter("PaperDollFrame");
		end
		
		PaperDollSidebarTab3:Click();
		
		local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
		for index, setID in ipairs(equipmentSetIDs) do
			local lineIndex;
			local name, icon, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID);
			
			if(isEquipped) then
				PaperDollEquipmentManagerPane.selectedSetId = setID;
				PaperDollFrame_ClearIgnoredSlots();
				PaperDollFrame_IgnoreSlotsForSet(setID);
				PaperDollEquipmentManagerPane_Update(true);
				
				break;
			end
		end
	end);
	
	tooltip:SetAutoHideDelay(0.4, anchorFrame);
	FlashTalentSpecButton.tooltip.OnRelease = function()
		FlashTalentSpecButton.tooltip = nil;
	end
	
	tooltip:ClearAllPoints();
	
	if(not forceRefresh) then
		tooltip:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, -2);
		Addon.ItemSetsMenuParent = anchorFrame;
	else
		tooltip:SetPoint(unpack(positionData));
	end
	
	tooltip:SetClampedToScreen(true);
	tooltip:Show();
	
	return tooltip;
end
