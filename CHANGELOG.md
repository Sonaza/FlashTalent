## 2.1.2
* Added option to right click in specialization tooltip to switch current quick switch specialization.
* Fixed Tome of the Clear Mind usage level.

## 2.1.1
* You can now link talents directly from FlashTalent by shift-clicking a talent.
* Added notice on the talent tooltip when you have no tomes for auto-use.
* Fixed tooltip note about talent tomes showing up when inappropriate.
* Fixed auto equipper equipping item sets when changing talents if it is enabled.
* Prevent auto tome use if talent row is free.

## 2.1.0
* The key binding to open equipment sets menu at cursor now also opens specializations menu at cursor.
* Added an option to automatically consume a Tome of the Clear/Tranquil Mind when it is necessary. The option is disabled by default.
* Addon should now properly recognise battleground, arena and dungeon preparation grace period.

## 2.0.3
* Fixed nil error with missing equipment set icons.

## 2.0.2
* Removed erroneous tooltip message for honor tab.

## 2.0.1
* Fix to scripts alert caused by the addon.
* Disabled honor tab until level 110.
* Added slash commands **/ft [tab]** and **/flashtalent [tab]**. Command will open FlashTalent window on the given tab index and defaults to class talents tab.

## 2.0.0
* Legion update.
  * Updated to support changed talent API.
  * Added support for Honor talents.
  * You can change between class and honor talents using new tabs next to the talents.
  * Removed glyph support since Legion glyphs are only minor and have mostly one-time use cases. Rest in peace.
  * Changed specializations tooltips to allow changing to any available specialization by clicking them on the list.
    * To counter the removal of dual spec, FlashTalent now tracks what specializations you used last and will allow you to quick change back to the previously used specialization via the specialization button and the optional keybind.
    * Added support for hunter pet specializations.
  * Updated reagent listing to display number of the tomes and the codices instead.
    * Clicking the number will allow you to use a tome or a codex to be able to change talents in non-rest zones.
  * Improved visual look and distinction of empty talent rows.
  * Added new keybind option to directly open honor talents tab. The old keybind now directly opens class talents tab.
  * Added option to change window scale between 80% and 150%.
  * Added option to disable Blizzard alert about unspent talent points.
  * Reorganized internal frame structure so that the whole window stays clamped inside game screen.
  * Disabled challenge mode restriction (temporarily?) because systems have changed and I'm unable to test it without beta.
  * Added a default font changeable in the options menu.
  * Plenty of miscellaneous bug fixes and other minor changes.

## 1.2.0
* Added options menu with various options:
  * Always displaying tooltips when hovering talents and glyphs.
  * Keep window open at all times, even while in combat.
  * Changing glyph buttons anchor to left or right side.
* Added cooldown display for talent rows that displays time until another talent change on the row is possible.
* Switched dual spec change to middle button on the databroker module. Left click now toggles the FlashTalent window.
