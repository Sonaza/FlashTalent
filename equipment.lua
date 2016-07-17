------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local data = Addon.data;
local _;

local LibStub = LibStub;
local AceDB = LibStub("AceDB-3.0");
local LibQTip = LibStub("LibQTip-1.0");

function Addon:EQUIPMENT_SWAP_FINISHED(event, success, setName)
	if(FlashTalentSpecButton.tooltip and FlashTalentSpecButton.tooltip:IsVisible() and FlashTalentSpecButton.tooltip.category == 2) then
		Addon:RefreshItemSetsMenu(setName);
	end
	
	if(success) then
		PaperDollEquipmentManagerPane.selectedSetName = setName;
		PaperDollFrame_ClearIgnoredSlots();
		PaperDollFrame_IgnoreSlotsForSet(setName);
		PaperDollEquipmentManagerPane_Update();
		
		Addon:UpdateDatabrokerText();
	end
end

function Addon:UpdateEquipmentSet(setName)
	PaperDollFrame_ClearIgnoredSlots();
	PaperDollFrame_IgnoreSlotsForSet(setName);
	SaveEquipmentSet(setName);
end

local FlashTalentMenuCursorAnchor;
function Addon:OpenItemSetsMenuAtCursor()
	if(not FlashTalentMenuCursorAnchor) then
		FlashTalentMenuCursorAnchor = CreateFrame("Frame", "FlashTalentMenuCursorAnchor", UIParent);
		FlashTalentMenuCursorAnchor:SetSize(20, 20);
	end
	
	local x, y = GetCursorPosition();
	local uiscale = UIParent:GetEffectiveScale();
	
	FlashTalentMenuCursorAnchor:ClearAllPoints();
	FlashTalentMenuCursorAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uiscale, y / uiscale);
	
	local tooltip = Addon:OpenItemSetsMenu(FlashTalentMenuCursorAnchor);
	
	if(tooltip) then
		tooltip:ClearAllPoints();
		tooltip:SetPoint("BOTTOM", FlashTalentMenuCursorAnchor, "CENTER", 0, -2);
	end
end

function Addon:RefreshItemSetsMenu(setName)
	Addon:OpenItemSetsMenu(Addon.ItemSetsMenuParent, true, setName);
end

function Addon:OpenItemSetsMenu(anchorFrame, forceRefresh, setName)
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
		for specIndex, setName in pairs(Addon.db.char.SpecSets) do
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
				specSetName = string.format(" |cffffee22%s %s|r", strtrim(FLASHTALENT_ICON_PATTERN:format(specIcon)), specName);
			else
				local _, specName, _, specIcon = Addon:GetSpecializationInfoByName(name);
				if(specName) then
					specSetName = string.format(" |cffaaaaaa%s %s|r", strtrim(FLASHTALENT_ICON_PATTERN:format(specIcon)), specName);
				end
			end
			
			local equipmentTitle;
			if(isEquipped) then
				lineIndex = tooltip:AddLine(string.format("%s |cff33ff00%s (equipped)|r", FLASHTALENT_ICON_PATTERN:format(icon), name), specSetName);
			elseif(numMissing > 0) then
				lineIndex = tooltip:AddLine(string.format("%s |cffff2222%s|r (%d missing)", FLASHTALENT_ICON_PATTERN:format(icon), name, numMissing), specSetName);
			else
				lineIndex = tooltip:AddLine(string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), name), specSetName);
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
					if(Addon.db.char.SpecSets[activeSpec] == name) then
						Addon.db.char.SpecSets[activeSpec] = nil;
					else
						Addon.db.char.SpecSets[activeSpec] = name;
						
						for specIndex, setName in pairs(Addon.db.char.SpecSets) do
							if(specIndex ~= activeSpec and setName == name) then
								Addon.db.char.SpecSets[specIndex] = nil;
							end
						end
					end
					
					Addon:RefreshItemSetsMenu();
				elseif(IsShiftKeyDown() and button == "MiddleButton") then
					Addon:UpdateEquipmentSet(name);
					
				elseif(button == "RightButton") then
					local icon, setID = GetEquipmentSetInfoByName(name);
					
					StaticPopup_Show("FLASHTALENT_RENAME_EQUIPMENT_SET", string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), name), nil, {
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
		Addon.db.char.AutoSwitchGearSet = not Addon.db.char.AutoSwitchGearSet;
		Addon:RefreshItemSetsMenu();
	end);
	
	Addon:AddScriptedTooltipLine(tooltip, "|cffffdd00Open Equipment Manager|r", function()
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
		Addon.ItemSetsMenuParent = anchorFrame;
	else
		tooltip:SetPoint(unpack(positionData));
	end
	
	tooltip:Show();
	
	return tooltip;
end
