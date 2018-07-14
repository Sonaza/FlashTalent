------------------------------------------------------------
-- FlashTalent by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

FLASHTALENT_ICON_PATTERN              = "|T%s:14:14:0:0|t";
FLASHTALENT_ICON_PATTERN_NOBORDER     = "|T%s:14:14:0:0:64:64:6:58:6:58|t";

FLASHTALENT_ICON_ROLES = {
	DAMAGER = "|TInterface\\LFGFRAME\\LFGROLE:14:14:0:0:64:16:16:32:0:16|t",
	TANK    = "|TInterface\\LFGFRAME\\LFGROLE:14:14:0:0:64:16:32:48:0:16|t",
	HEALER  = "|TInterface\\LFGFRAME\\LFGROLE:14:14:0:0:64:16:48:64:0:16|t",
};

BINDING_HEADER_FLASHTALENT = "FlashTalent";
_G["BINDING_NAME_CLICK FlashTalentFrameToggler:LeftButton"] = "Toggle FlashTalent Talents";
_G["BINDING_NAME_FLASHTALENT_CHANGE_DUALSPEC"] = "Quick Switch to Previous Spec";
_G["BINDING_NAME_FLASHTALENT_OPEN_ITEM_SETS_MENU"] = "Open Menus at Cursor";

StaticPopupDialogs["FLASHTALENT_NO_KEYBIND"] = {
	text = "FlashTalent does not currently have a keybinding. Do you want to open the key binding menu to set it?|n|nOption you are looking for is found under AddOns category.",
	button1 = YES,
	button2 = NO,
	button3 = "Don't Ask Again",
	OnAccept = function(self)
		KeyBindingFrame_LoadUI();
		KeyBindingFrame.mode = 1;
		ShowUIPanel(KeyBindingFrame);
	end,
	OnCancel = function(self)
	end,
	OnAlt = function()
		Addon:SetAskedBinding(true);
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
		local setID = data.setID;
		local oldName = data.oldName;
		local newName = strtrim(self.editBox:GetText());
		
		if(setID and oldName and newName and oldName ~= newName and strlen(newName) > 0) then
			C_EquipmentSet.ModifyEquipmentSet(setID, newName);
		end
	end,
	EditBoxOnEnterPressed = function(self, data)
		local setID = data.setID;
		local oldName = data.oldName;
		local newName = strtrim(self:GetParent().editBox:GetText());
		
		if(setID and oldName and newName and oldName ~= newName and strlen(newName) > 0) then
			C_EquipmentSet.ModifyEquipmentSet(setID, newName);
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
