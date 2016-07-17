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

function A:UpdateDatabrokerText()
	local text = {};
	
	local specID = GetSpecialization(false, false, GetActiveSpecGroup());
	if(specID) then
		local _, specName, _, icon = GetSpecializationInfo(specID);
		
		A.databroker.icon = icon;
		tinsert(text, specName);
	end
	
	if(GetNumUnspentTalents() > 0) then
		tinsert(text, string.format("|cffff4141%d|r|cffffdd00T|r", GetNumUnspentTalents()));
	end
	
	if(GetNumUnspentPvpTalents() > 0) then
		tinsert(text, string.format("|cffff4141%d|r|cffffdd00HT|r", GetNumUnspentPvpTalents()));
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
				if(frame.tooltip and frame.tooltip:IsVisible()) then
					LibQTip:Release(frame.tooltip);
					frame.tooltip = nil;
				end
				
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
			A:DataBroker_OnLeave(frame);
		end,
	});

	A:UpdateDatabrokerText();
end

local ICON_ROLES = "Interface\\LFGFRAME\\LFGROLE";
local ROLES = {
	DAMAGER = "|T%s:14:14:0:0:64:16:16:32:0:16|t",
	TANK    = "|T%s:14:14:0:0:64:16:32:48:0:16|t",
	HEALER  = "|T%s:14:14:0:0:64:16:48:64:0:16|t",
};

function A:DataBroker_OnEnter(parent)
	A:HideSpecButtonTooltip();
	
	parent.tooltip = LibQTip:Acquire("FlashTalentSpecButtonDataBrokerTooltip", 2, "LEFT", "RIGHT");
	A.DataBrokerTooltip = parent.tooltip;
	
	local point, relativePoint, offset = A:GetVerticalAnchors(parent);
	
	parent.tooltip:Clear();
	parent.tooltip:ClearAllPoints();
	parent.tooltip:SetPoint(point, parent, relativePoint, 0, offset);
	
	parent.tooltip:AddHeader("|cffffdd00Specializations|r");
	parent.tooltip:AddSeparator();
	
	for specIndex = 1, GetNumSpecializations() do
		local id, name, description, icon, background, role = GetSpecializationInfo(specIndex);
		
		local color = "|cffeeeeee";
		local activeText = "";
		
		if(specIndex == GetSpecialization()) then
			activeText = "|cff00ff00Active|r";
		end
		
		if(specIndex == GetSpecialization() or specIndex == A.db.char.PreviousSpec) then
			color = "|cff8ce2ff";
		end
		
		local lineIndex = parent.tooltip:AddLine(
			string.format("%s %s%s|r %s", ICON_PATTERN:format(icon), color, name, ROLES[role]:format(ICON_ROLES)),
			activeText
		);
		
		parent.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(parent, _, button)
			if(specIndex ~= GetSpecialization()) then
				SetSpecialization(specIndex);
				A:HideSpecButtonTooltip();
			end
		end);
	end
	
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
			
			local lineIndex = parent.tooltip:AddLine(string.format("%s %s", ICON_PATTERN:format(icon), name), activeText);
			
			parent.tooltip:SetLineScript(lineIndex, "OnMouseUp", function(parent, _, button)
				if(specIndex ~= GetSpecialization(false, true)) then
					SetSpecialization(specIndex, true);
					-- A:HideSpecButtonTooltip();
				end
			end);
		end
	end
	
	parent.tooltip:AddLine(" ");
	
	parent.tooltip:AddLine("|cff00ff00Left click|r  Toggle FlashTalent");
	
	if(A.db.char.PreviousSpec ~= nil and A.db.char.PreviousSpec ~= 0) then
		local _, name, _, _, _, role = GetSpecializationInfo(A.db.char.PreviousSpec, false, false);
		parent.tooltip:AddLine(string.format("|cff00ff00Middle click|r  Switch back to |cffffdd00%s|r %s", name, ROLES[role]:format(ICON_ROLES)));
	end
	
	parent.tooltip:AddLine("|cff00ff00Right click|r  View equipment sets");
	
	parent.tooltip:SetAutoHideDelay(0.25, parent);
	parent.tooltip:Show();
end

function A:DataBroker_OnLeave(parent)
	if(parent.tooltip and parent.tooltip:IsVisible()) then
		-- LibQTip:Release(parent.tooltip);
		-- parent.tooltip = nil;
	end
end