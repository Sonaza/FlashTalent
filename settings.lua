------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local AceDB = LibStub("AceDB-3.0");
local LibSharedMedia = LibStub("LibSharedMedia-3.0");

-- Adding default media to LibSharedMedia in case they're not already added
LibSharedMedia:Register("font", "DorisPP", [[Interface\AddOns\FlashTalent\media\DORISPP.TTF]]);

local defaults = {
	char = {
		AskedKeybind        = false,
		AutoSwitchGearSet   = false,
		OpenTalentTab       = 1,
		PreviousSpec        = 0,
		SpecSets            = {},
		LegionSetReset      = false,
	},
	global = {
		AskedKeybind        = false,
		
		FontFace            = "DorisPP",
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
		
		UseReagents         = false,
		
		HideBlizzAlert      = false,
		
	},
};

function Addon:OnInitialize()
	self.db = AceDB:New("FlashTalentDB", defaults);
	
	Addon.CurrentTalentTab = self.db.char.OpenTalentTab;
	
	-- Because set indexing changed, the sets must be reset. Sorry!
	if(not self.db.char.LegionSetReset) then
		self.db.char.SpecSets = {};
		self.db.char.LegionSetReset = true;
	end
end

function Addon:UpdateFonts()
	local fontPath = LibSharedMedia:Fetch("font", self.db.global.FontFace);
	FlashTalent_NumberFont_Large_Shadow:SetFont(fontPath, 17, "OUTLINE");
	FlashTalent_NumberFont_Med:SetFont(fontPath, 13, "OUTLINE");
	FlashTalent_NumberFont_Med_Shadow:SetFont(fontPath, 13, "OUTLINE");
end

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

function Addon:GetSharedFonts()
	local fonts = {};
	for index, font in ipairs(LibSharedMedia:List("font")) do
		tinsert(fonts, {
			text = font,
			func = function()
				self.db.global.FontFace = font;
				Addon:UpdateFrame();
				CloseMenus();
			end,
			checked = function() return self.db.global.FontFace == font; end,
		});
	end
	
	return fonts;
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
			text = "Automatically use a Tome if necessary",
			func = function() self.db.global.UseReagents = not self.db.global.UseReagents; Addon:UpdateTalentFrame(); end,
			checked = function() return self.db.global.UseReagents; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Miscellaneous", isTitle = true, notCheckable = true,
		},
		{
			text = string.format("|cffffd200Window scale:|r %d%%", Addon.db.global.WindowScale * 100),
			hasArrow = true,
			notCheckable = true,
			menuList = Addon:GetWindowScaleMenu(),
		},
		{
			text = string.format("|cffffd200Font:|r %s", Addon.db.global.FontFace),
			hasArrow = true,
			notCheckable = true,
			menuList = Addon:GetSharedFonts(),
		},
		{
			text = string.format("|cffffd200Anchor side:|r %s", string.lower(self.db.global.AnchorSide)),
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

local FlashTalentMenuCursorAnchor;
function Addon:OpenMenusAtCursor()
	if(not FlashTalentMenuCursorAnchor) then
		FlashTalentMenuCursorAnchor = CreateFrame("Frame", "FlashTalentMenuCursorAnchor", UIParent);
		FlashTalentMenuCursorAnchor:SetSize(20, 20);
	end
	
	local x, y = GetCursorPosition();
	local uiscale = UIParent:GetEffectiveScale();
	
	FlashTalentMenuCursorAnchor:ClearAllPoints();
	FlashTalentMenuCursorAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uiscale, y / uiscale);
	
	Addon:OpenItemSetsMenuAtCursor(FlashTalentMenuCursorAnchor);
	Addon:OpenSpecializationsMenuAtCursor(FlashTalentMenuCursorAnchor);
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
