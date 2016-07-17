------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

function Addon:ToggleEscapeClose()
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

function Addon:GetWindowScaleMenu()
	local windowScales = { 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.3, 1.4, 1.5, };
	local menu = {};
	
	for index, scale in ipairs(windowScales) do
		tinsert(menu, {
			text = string.format("%d%%", scale * 100),
			func = function() self.db.global.WindowScale = scale; Addon:UpdateFrame(); CloseMenus(); end,
			checked = function() return self.db.global.WindowScale == scale end,
		});
	end
	
	return menu;
end

function Addon:GetMenuData()
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
			func = function() self.db.global.StickyWindow = not self.db.global.StickyWindow; Addon:ToggleEscapeClose(); end,
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
			text = string.format("|cffffdd00Window scale:|r %d%%", Addon.db.global.WindowScale * 100),
			hasArrow = true,
			notCheckable = true,
			menuList = Addon:GetWindowScaleMenu(),
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
					func = function() self.db.global.AnchorSide = "RIGHT"; Addon:UpdateFrame(); CloseMenus(); end,
					checked = function() return self.db.global.AnchorSide == "RIGHT"; end,
				},
				{
					text = "To the left",
					func = function() self.db.global.AnchorSide = "LEFT"; Addon:UpdateFrame(); CloseMenus(); end,
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

function Addon:OpenContextMenu(parentframe)
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", "FlashTalentContextMenuFrame", parentframe, "UIDropDownMenuTemplate");
	end
	
	Addon.ContextMenu:SetPoint("BOTTOM", parentframe, "CENTER", 0, 5);
	EasyMenu(Addon:GetMenuData(), Addon.ContextMenu, "cursor", 0, 0, "MENU", 5);
	
	DropDownList1:ClearAllPoints();
	
	if(self.db.global.AnchorSide == "RIGHT") then
		DropDownList1:SetPoint("TOPLEFT", parentframe, "TOPRIGHT", 1, 0);
	elseif(self.db.global.AnchorSide == "LEFT") then
		DropDownList1:SetPoint("TOPRIGHT", parentframe, "TOPLEFT", 1, 0);
	end
	
	DropDownList1:SetClampedToScreen(true);
end


function FlashTalentFrameSettingsButton_OnEnter(self)
	if(DropDownList1:IsVisible()) then return end
	
	GameTooltip:ClearAllPoints();
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE");
	
	if(Addon.db.global.AnchorSide == "RIGHT") then
		GameTooltip:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", 2, 0);
	elseif(Addon.db.global.AnchorSide == "LEFT") then
		GameTooltip:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", -2, 0);
	end
	
	GameTooltip:AddLine("FlashTalent Pro Tips")
	GameTooltip:AddLine("Switch talents by hovering the one you wish to change to and |cff00ff00left click|r it.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("You can switch between class and honor talents by clicking the circles next to talent rows.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("The spec switch button will now change between your previously used spec so you can still use it to quickly switch between your most used specializations.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Hold alt and drag to move FlashTalent.", 0, 1, 0);
	if(not Addon.db.global.AlwaysShowTooltip) then
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
	Addon:OpenContextMenu(self);
end
