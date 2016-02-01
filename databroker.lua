------------------------------------------------------------
-- FlashTalent by Sonaza
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, SHARED = ...;

local LibStub = LibStub;
local A = unpack(SHARED);

local _;

local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
local LibQTip = LibStub("LibQTip-1.0");

local ICON_PATTERN = "|T%s:14:14:0:0|t";

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
		
		A.databroker.icon = icon;
		tinsert(text, specName);
	else
		A.databroker.icon = "Interface\\Icons\\Ability_Marksmanship"
		tinsert(text, "No specialization");
	end
	
	if(GetNumUnspentTalents() > 0) then
		tinsert(text, string.format("|cffff4141%dT|r", GetNumUnspentTalents(), GetNumUnspentTalents() == 1 and "" or "s"));
	end
	
	if(GetNumEmptyGlyphSlots() > 0) then
		tinsert(text, string.format("|cffff4141%dG|r", GetNumEmptyGlyphSlots(), GetNumEmptyGlyphSlots() == 1 and "" or "s"));
	end
	
	A.databroker.text = table.concat(text, " / ");
end

function A:GetVerticalAnchors(frame)
	local point, relativePoint = "TOP", "BOTTOM";
	local offset = -4;
	
	local _, framey = frame:GetCenter();
	local scale = UIParent:GetEffectiveScale();
	
	if(framey / scale <= GetScreenHeight() / 2) then
		point, relativePoint = "BOTTOM", "TOP";
		offset = 4;
	end
	
	return point, relativePoint, offset;
end

function A:InitializeDatabroker()
	A.databroker = LDB:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "FlashTalent",
		text = "FlashTalent",
		icon = "Interface\\Icons\\Ability_Marksmanship",
		OnClick = function(frame, button)
			if(button == "LeftButton") then
				if(not InCombatLockdown()) then
					A:ToggleFrame();
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cffffd200FlashTalent|r Can't toggle window when in combat!");
				end
			elseif(button == "MiddleButton") then
				if(not InCombatLockdown()) then
					A:ChangeDualSpec();
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cffffd200FlashTalent|r Can't switch spec when in combat!");
				end
			elseif(button == "RightButton") then
				GameTooltip:Hide();
				
				local tooltip = A:OpenItemSetsMenu(frame);
				
				local point, relativePoint, offset = A:GetVerticalAnchors(frame);
				
				tooltip:ClearAllPoints();
				tooltip:SetPoint(point, frame, relativePoint, 0, offset);
			end
		end,
		OnEnter = function(frame)
			A:DataBroker_OnEnter(frame);
		end,
		OnLeave = function(frame)
			GameTooltip:Hide();
		end,
	});

	A:UpdateDatabrokerText();
end

function A:DataBroker_OnEnter(parent)
	if(A.EquipmentTooltip and A.EquipmentTooltip:IsVisible()) then return end
	
	GameTooltip:ClearAllPoints();
	
	GameTooltip:SetOwner(parent, "ANCHOR_PRESERVE");
	
	local point, relativePoint, offset = A:GetVerticalAnchors(parent);
	
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint(point, parent, relativePoint, 0, offset);
	
	GameTooltip:AddLine("FlashTalent");
	
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
	
	GameTooltip:AddLine("Left click to toggle FlashTalent", 0, 1, 0);
	
	if(numSpecs > 1) then
		GameTooltip:AddLine("Middle click to switch specs", 0, 1, 0);
	end
	
	GameTooltip:AddLine("Right click to view equipment sets", 0, 1, 0);
	GameTooltip:Show();
end