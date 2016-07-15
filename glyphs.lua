------------------------------------------------------------
-- FlashTalent by Sonaza
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, SHARED = ...;
local _;

local _G = getfenv(0);

local A = unpack(SHARED);

local glyphSlotLevels = {
	[1] = 25, -- Minor 1
	[2] = 25, -- Major 1
	[3] = 50, -- Minor 2
	[4] = 50, -- Major 2
	[5] = 75, -- Minor 3
	[6] = 75, -- Major 3
}

function A:UpdateGlyphs()
	if(true or InCombatLockdown()) then return end
	
	for glyphIndex = 1, 6 do
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		local glyph = _G['FlashGlyphsFrameGlyph' .. glyphIndex];
		
		glyph.glyphType = glyphType;
		glyph.ring:SetVertexColor(0, 0, 0);
		
		glyph.levelText:SetText(glyphSlotLevels[glyphIndex]);
		if(not enabled) then
			glyph.levelText:Show();
		else
			glyph.levelText:Hide();
		end
		
		if(glyphID and not A:HasChallengeModeRestriction()) then
			glyph:SetAttribute("shift-type2", "macro");
			glyph:SetAttribute("macrotext",
				"/stopmacro [combat]\n" ..
				"/click PlayerTalentFrameTab3\n"..
				"/click [spec:1] PlayerSpecTab1\n"..
				"/click [spec:2] PlayerSpecTab2\n"..
				"/click GlyphFrameGlyph" .. glyphIndex .. " RightButton\n" ..
				"/click StaticPopup1Button1\n"
			);
		elseif(A:HasChallengeModeRestriction()) then
			glyph:SetAttribute("macrotext", "");
		end
		
		glyph.unlocked = enabled;
		
		if(not enabled) then
			glyph.spell = nil;
			glyph.glyphID = nil;
			
			SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
			glyph.icon:SetVertexColor(0.2, 0.2, 0.2);
			glyph.icon:SetDesaturated(true);
			glyph:SetAlpha(0.9);
		elseif(not glyphSpell) then
			glyph.spell = nil;
			glyph.glyphID = nil;
			
			SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
			glyph.icon:SetVertexColor(0.4, 0.4, 0.4);
			glyph.icon:SetDesaturated(true);
			glyph:SetAlpha(1.0);
		else
			glyph.spell = glyphSpell;
			glyph.glyphID = glyphID;
			
			if(icon) then
				SetPortraitToTexture(glyph.icon, icon);
				glyph.icon:SetVertexColor(1.0, 1.0, 1.0);
				glyph.icon:SetDesaturated(false);
			else
				SetPortraitToTexture(glyph.icon, "Interface\\Icons\\inv_glyph_majordruid");
				glyph.icon:SetVertexColor(0.4, 0.4, 0.4);
				glyph.icon:SetDesaturated(true);
			end
			
			glyph:SetAlpha(1.0);
		end
	end
end

function FlashGlyphButtonTemplate_OnLoad(self)
	self.glow:Play();
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function FlashGlyphButtonTemplate_OnEnter(self)
	if(true) then return; end
	
	if(self.unlocked and not A:HasChallengeModeRestriction()) then
		self.glow:Play();
		self.highlight:Show();
		-- self.ring:SetVertexColor(1, 1, 1);
	end
	
	if(IsShiftKeyDown() or A.db.global.AlwaysShowTooltip) then
		local glyphIndex = self:GetID();
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		if(glyphID) then
			GameTooltip:SetGlyphByID(glyphID);
		else
			if(glyphType == 1) then
				GameTooltip:AddLine("Empty Major Glyph Slot");
			elseif(glyphType == 2) then
				GameTooltip:AddLine("Empty Minor Glyph Slot");
			end
		end
		
		if(enabled) then
			if(glyphID) then
				GameTooltip:AddLine("Left click to change the glyph.", 0, 1, 0);
				GameTooltip:AddLine("Shift-Right click to unlearn.", 0, 1, 0);
			else
				GameTooltip:AddLine("Left click to set the glyph.", 0, 1, 0);
			end
		else
			GameTooltip:AddLine(string.format("Glyph Slot Unlocked at Level %d.", glyphSlotLevels[glyphIndex]), 1, 0, 0);
		end
		
		GameTooltip:Show();
	end
	
	A.HoveredGlyph = self;
end

function FlashGlyphButtonTemplate_OnLeave(self)
	GameTooltip:Hide();
	A.HoveredGlyph = nil;
	
	if(not self.isSelected) then
		self.highlight:Hide();
		self.ring:SetVertexColor(0, 0, 0);
	end
end

function FlashGlyphButtonTemplate_PostClick(self, button)
	if(A:HasChallengeModeRestriction()) then
		UIErrorsFrame:AddMessage("Cannot change glyphs while in Challenge Mode.", 1.0, 0.1, 0.1, 1.0);
		return;
	elseif(button == "LeftButton") then
		local glyphIndex = self:GetID();
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, glyphID = GetGlyphSocketInfo(glyphIndex);
		
		if(enabled) then
			if(not self.isSelected) then
				A:ClearSelections(glyphIndex);
				A:OpenGlyphChangeMenu(self, glyphIndex, glyphType, glyphID);
				self.isSelected = true;
			
				self.ring:SetVertexColor(1, 1, 1);
			else
				FlashGlyphChangeFrame:Hide();
				self.highlight:Show();
				self.isSelected = false;
			
				self.ring:SetVertexColor(0, 0, 0);
			end
		end
	end
end

function A:USE_GLYPH()
	if(InCombatLockdown()) then return end
	
	A:ClearSelections();
	FlashGlyphChangeFrame:Hide();
	
	A:UpdateDatabrokerText();
end

function A:GLYPH_UPDATED()
	if(InCombatLockdown()) then return end
	
	A:UpdateGlyphs();
	
	A:UpdateDatabrokerText();
end

function FlashGlyphChangeFrame_OnShow()
	
end

function FlashGlyphChangeFrame_OnHide()
	A:ClearSelections();
end

function A:GetUsableGlyphs()
	local glyphs = {
		[GLYPH_TYPE_MAJOR] = {},
		[GLYPH_TYPE_MINOR] = {},
	};
	
	local numGlyphs = GetNumGlyphs();
	for index = 1, numGlyphs do
		local name, glyphType, isKnown, icon, glyphID, glyphLink, spec, specMatches, excluded = GetGlyphInfo(index);
		if(name ~= "header" and isKnown == true and icon and specMatches) then
			tinsert(glyphs[glyphType], {
				index = index,
				name = name,
				icon = icon,
				glyphID = glyphID,
				spec = spec,
				excluded = excluded,
			});
		end
	end
	
	return glyphs;
end

function A:IsGlyphInUse(glyphID)
	local numGlyphs = GetNumGlyphs();
	for glyphIndex = 1, numGlyphs do
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon, socketedGlyphID = GetGlyphSocketInfo(glyphIndex);
		if(glyphID == socketedGlyphID) then return true end
	end
	
	return false;
end

function A:OpenGlyphChangeMenu(glyphFrame, glyphIndex, glyphType, isActive)
	if(InCombatLockdown()) then return end
	if(not (glyphFrame and glyphIndex and glyphType)) then return end
	
	local glyphs = A:GetUsableGlyphs();
	local numGlyphs = #glyphs[glyphType];
	
	local slotName;
	if(glyphType == 1) then
		slotName = string.format("major%d", glyphIndex / 2);
	elseif(glyphType == 2) then
		slotName = string.format("minor%d", (glyphIndex + 1) / 2);
	end
	
	local columns = math.min(6, numGlyphs);
	local rows = math.ceil(numGlyphs / 6);
	
	FlashGlyphChangeFrame:SetWidth(columns * 28);
	FlashGlyphChangeFrame:SetHeight(rows * 28);
	
	local rowFirstButton = FlashGlyphChangeFrameButton1;
	local previousButton = FlashGlyphChangeFrameButton1;
	
	for index = 1, 50 do
		local button = _G['FlashGlyphChangeFrameButton' .. index];
		if(button) then
			button.glyphID = nil;
			button:SetAttribute("type", nil);
			button:Hide()
		else
			break;
		end
	end
	
	if(numGlyphs > 0) then
		local _, reagentCount = GetGlyphClearInfo();
		local hasReagents = (reagentCount or 0) > 0;
		
		FlashGlyphChangeFrame.noGlyphsWarning:Hide();
		
		for index = 1, numGlyphs do
			local data = glyphs[glyphType][index];
			
			local button = _G['FlashGlyphChangeFrameButton' .. index];
			if(not button) then
				button = CreateFrame("Button", 'FlashGlyphChangeFrameButton' .. index, FlashGlyphChangeFrame, "FlashGlyphChangeButtonTemplate");
				
				if(index ~= 1 and (index - 1) % 6 == 0) then
					button:SetPoint("TOPLEFT", rowFirstButton, "BOTTOMLEFT", 0, 0);
				elseif(index ~= 1) then
					button:SetPoint("TOPLEFT", previousButton, "TOPRIGHT", 0, 0);
				end
			end
			
			if(index ~= 1 and (index - 1) % 6 == 0) then
				rowFirstButton = button;
			end
			previousButton = button;
			
			button.freeChange = (glyphFrame.glyphID == nil);
			
			button.glyphID = data.glyphID;
			button.isActive = (data.glyphID == isActive);
			button.glyphInUse = A:IsGlyphInUse(data.glyphID);
			button.excluded = data.excluded;
			
			button.icon:SetTexture(data.icon);
			button.icon:SetVertexColor(0.9, 0.9, 0.9);
			button.icon:SetDesaturated(false);
			
			if(data.excluded) then
				button:SetAttribute("type", nil);
				button.icon:SetVertexColor(1.0, 0.2, 0.2);
				button.icon:SetDesaturated(true);
			elseif(button.glyphInUse) then
				button:SetAttribute("type", nil);
				button.icon:SetVertexColor(0.42, 0.42, 0.42);
				button.icon:SetDesaturated(true);
			elseif(not button.glyphInUse) then
				button:SetAttribute("type", "glyph");
				button:SetAttribute("glyph", data.name);
				button:SetAttribute("slot", slotName);
			end
			
			if(not hasReagents and glyphFrame.glyphID ~= nil) then
				button:SetAttribute("type", nil);
			end
			
			button:Show();
		end
	else
		FlashGlyphChangeFrame.noGlyphsWarning:Show();
		FlashGlyphChangeFrame:SetWidth(160);
		FlashGlyphChangeFrame:SetHeight(32);
	end
	
	FlashGlyphChangeFrame:SetParent(glyphFrame);
	FlashGlyphChangeFrame:ClearAllPoints();
	
	if(self.db.global.AnchorGlyphs == "RIGHT") then
		FlashGlyphChangeFrame:SetPoint("TOPLEFT", glyphFrame, "TOPRIGHT", 8, -1);
	elseif(self.db.global.AnchorGlyphs == "LEFT") then
		FlashGlyphChangeFrame:SetPoint("TOPRIGHT", glyphFrame, "TOPLEFT", -8, -1);
	end
	FlashGlyphChangeFrame:Show();
end

function FlashGlyphChangeButtonTemplate_PostClick(self)
	if(not self.excluded and not self.glyphInUse) then
		local reagent, reagentCount, reagentIcon, _, cost = GetGlyphClearInfo();
			
		if(reagentCount > 0 or self.freeChange or cost == 0) then
			FlashGlyphChangeFrame:Hide();
		elseif(reagentCount == 0 and not self.freeChange) then
			StaticPopup_Show("FLASHTALENT_NOT_ENOUGH_REAGENTS", "glyph", string.format("%s %s", ICON_PATTERN:format(reagentIcon), reagent));
		end
	end
end

function FlashGlyphChangeButtonTemplate_OnEnter(self)
	self.icon:SetVertexColor(1.0, 1.0, 1.0);
	
	if(self.excluded) then
		self.icon:SetVertexColor(1.0, 0.4, 0.4);
	elseif(self.glyphInUse) then
		self.icon:SetVertexColor(0.8, 0.8, 0.8);
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetGlyphByID(self.glyphID);
	if(not self.excluded and not self.glyphInUse) then
		GameTooltip:AddLine("Left click to change to this glyph.", 0, 1, 0);
	elseif(self.glyphInUse) then
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine("This glyph is currently in use.", 0.38, 0.77, 1.0);
	end
	GameTooltip:Show();
end

function FlashGlyphChangeButtonTemplate_OnLeave(self)
	self.icon:SetVertexColor(0.9, 0.9, 0.9);
	
	if(self.excluded) then
		self.icon:SetVertexColor(0.9, 0.3, 0.3);
	elseif(self.glyphInUse) then
		self.icon:SetVertexColor(0.3, 0.3, 0.3);
	end
	
	GameTooltip:Hide();
end
	