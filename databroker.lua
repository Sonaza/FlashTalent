------------------------------------------------------------
-- FlashTalent by Sonaza
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, SHARED = ...;

local LibStub = LibStub;
local A = unpack(SHARED);

local _;

local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
local AceDB = LibStub("AceDB-3.0")
local LibQTip = LibStub("LibQTip-1.0");

function GetNumEmptyGlyphSlots()
	local emptySlots = 0;
	
	for slotIndex = 1,6 do
		local enabled, _, _, glyphSpellID = GetGlyphSocketInfo(slotIndex);
		if(enabled and glyphSpellID == nil) then
			emptySlots = emptySlots + 1;
		end
	end
	
	return emptySlots;
end

function A:UpdateDatabrokerText()
	local text = {};
	
	local specID = GetSpecialization(false, false, GetActiveSpecGroup());
	if(specID) then
		local _, specName, _, icon = GetSpecializationInfo(specID);
		tinsert(text, specName);
		
		A.databroker.icon = icon;
	end
	
	if(GetNumUnspentTalents() > 0) then
		tinsert(text, string.format("|cffff4141%dT|r", GetNumUnspentTalents(), GetNumUnspentTalents() == 1 and "" or "s"));
	end
	
	if(GetNumEmptyGlyphSlots() > 0) then
		tinsert(text, string.format("|cffff4141%dG|r", GetNumEmptyGlyphSlots(), GetNumEmptyGlyphSlots() == 1 and "" or "s"));
	end
	
	A.databroker.text = table.concat(text, " / ");
end

function A:InitializeDatabroker()
	A.databroker = LDB:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "FlashTalent",
		text = "FlashTalent",
		icon = "Interface\\Icons\\Ability_Marksmanship",
		OnClick = function(frame, button)
			if(button == "LeftButton") then
				A:ChangeDualSpec();
			elseif(button == "RightButton") then
				GameTooltip:Hide();
				
				local tooltip = A:OpenItemSetsMenu(frame);
				
				local point, relativePoint = "TOP", "BOTTOM";
				local offset = -4;
				
				local _, framey = frame:GetCenter();
				local scale = UIParent:GetEffectiveScale();
				
				if(framey / scale <= GetScreenHeight() / 2) then
					point, relativePoint = "BOTTOM", "TOP";
					offset = 4;
				end
				
				tooltip:ClearAllPoints();
				tooltip:SetPoint(point, frame, relativePoint, 0, offset);
			end
		end,
		OnEnter = function(frame)
			FlashTalentChangeDualSpecButton_OnEnter(frame);
			
			local point, relativePoint = "TOP", "BOTTOM";
			local offset = -4;
			
			local _, framey = frame:GetCenter();
			local scale = UIParent:GetEffectiveScale();
			
			if(framey / scale <= GetScreenHeight() / 2) then
				point, relativePoint = "BOTTOM", "TOP";
				offset = 4;
			end
			
			GameTooltip:ClearAllPoints();
			GameTooltip:SetPoint(point, frame, relativePoint, 0, offset);
		end,
		OnLeave = function(frame)
			GameTooltip:Hide();
		end,
	});

	A:UpdateDatabrokerText();
end