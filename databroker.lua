------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1");
local LibQTip = LibStub("LibQTip-1.0");

function Addon:UpdateDatabrokerText()
	local text = {};
	
	local specID = GetSpecialization(false, false, GetActiveSpecGroup());
	if(specID) then
		local _, specName, _, icon = GetSpecializationInfo(specID);
		
		Addon.databroker.icon = icon;
		tinsert(text, specName);
	end
	
	if(GetNumUnspentTalents() > 0) then
		tinsert(text, string.format("|cffff4141%d|r|cffffdd00T|r", GetNumUnspentTalents()));
	end
	
	if(GetNumUnspentPvpTalents() > 0) then
		tinsert(text, string.format("|cffff4141%d|r|cffffdd00HT|r", GetNumUnspentPvpTalents()));
	end
	
	Addon.databroker.text = table.concat(text, " / ");
end

function Addon:GetVerticalAnchors(frame)
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

function Addon:InitializeDatabroker()
	Addon.databroker = LibDataBroker:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "FlashTalent",
		text = "FlashTalent",
		icon = "Interface\\Icons\\Ability_Marksmanship",
		OnClick = function(frame, button)
			if(button == "LeftButton") then
				if(not InCombatLockdown()) then
					Addon:ToggleFrame();
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cffffd200FlashTalent|r Can't toggle window when in combat!");
				end
			elseif(button == "MiddleButton") then
				if(not InCombatLockdown()) then
					Addon:ChangeDualSpec();
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cffffd200FlashTalent|r Can't switch spec when in combat!");
				end
			elseif(button == "RightButton") then
				if(frame.tooltip and frame.tooltip:IsVisible()) then
					LibQTip:Release(frame.tooltip);
					frame.tooltip = nil;
				end
				
				local tooltip = Addon:OpenItemSetsMenu(frame);
				
				local point, relativePoint, offset = Addon:GetVerticalAnchors(frame);
				
				tooltip:ClearAllPoints();
				tooltip:SetPoint(point, frame, relativePoint, 0, offset);
			end
		end,
		OnEnter = function(frame)
			Addon:DataBroker_OnEnter(frame);
		end,
		OnLeave = function(frame)
			-- Addon:DataBroker_OnLeave(frame);
		end,
	});

	Addon:UpdateDatabrokerText();
end

function Addon:DataBroker_OnEnter(parent)
	Addon:HideSpecButtonTooltip();
	
	parent.tooltip = LibQTip:Acquire("FlashTalentDataBrokerTooltip", 2, "LEFT", "RIGHT");
	Addon.DataBrokerTooltip = parent.tooltip;
	
	local point, relativePoint, offset = Addon:GetVerticalAnchors(parent);
	
	parent.tooltip:Clear();
	parent.tooltip:ClearAllPoints();
	parent.tooltip:SetPoint(point, parent, relativePoint, 0, offset);
	
	local areSpecsUnlocked = UnitLevel("player") >= SHOW_SPEC_LEVEL;
	
	parent.tooltip:AddHeader("|cffffdd00Specializations|r");
	parent.tooltip:AddSeparator();
	
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
			local lineIndex = parent.tooltip:AddLine(
				string.format("%s %s%s|r %s", FLASHTALENT_ICON_PATTERN:format(icon), color, name, FLASHTALENT_ICON_ROLES[role]),
				activeText
			);
			
			if(areSpecsUnlocked) then
				parent.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization()) then
						SetSpecialization(specIndex);
					end
				end);
			end
		end
	end
	
	if(areSpecsUnlocked and (Addon.db.char.PreviousSpec == nil or Addon.db.char.PreviousSpec == 0)) then
		parent.tooltip:AddLine(string.format("|cffffdd00Left click a specialization to change to it.|r"));
	end
		
	if(areSpecsUnlocked) then
		local _, class = UnitClass("player");
		local petname = UnitName("pet");
		if(class == "HUNTER" and petname) then
			parent.tooltip:AddLine(" ");
			parent.tooltip:AddLine(string.format("|cffffdd00%s's Specialization|r", petname));
			parent.tooltip:AddSeparator();
			
			for specIndex = 1, GetNumSpecializations(false, true) do
				local id, name, description, icon, background, role = GetSpecializationInfo(specIndex, false, true);
				
				local activeText = "";
				
				if(specIndex == GetSpecialization(false, true)) then
					activeText = "|cff00ff00Active|r";
				end
				
				local lineIndex = parent.tooltip:AddLine(string.format("%s %s", FLASHTALENT_ICON_PATTERN:format(icon), name), activeText);
				
				parent.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
					if(specIndex ~= GetSpecialization(false, true)) then
						SetSpecialization(specIndex, true);
					end
				end);
			end
		end
	end
	
	if(not areSpecsUnlocked) then
		parent.tooltip:AddLine(string.format("|cffffdd00Specializations unlock at level %s.|r", SHOW_SPEC_LEVEL));
	end
	
	parent.tooltip:AddLine(" ");
	
	parent.tooltip:AddLine("|cff00ff00Left click|r  Toggle FlashTalent.");
	
	if(areSpecsUnlocked) then
		if(Addon.db.char.PreviousSpec ~= nil and Addon.db.char.PreviousSpec ~= 0) then
			local _, name, _, _, _, role = GetSpecializationInfo(Addon.db.char.PreviousSpec, false, false);
			parent.tooltip:AddLine(string.format("|cff00ff00Middle click|r  Switch back to |cffffdd00%s|r %s", name, FLASHTALENT_ICON_ROLES[role]));
		end
	end
	
	parent.tooltip:AddLine("|cff00ff00Right click|r  View equipment sets.");
	
	parent.tooltip:SetAutoHideDelay(0.25, parent);
	parent.tooltip.OnRelease = function()
		parent.tooltip = nil;
		Addon.DataBrokerTooltip = nil;
	end
	
	parent.tooltip:Show();
end
