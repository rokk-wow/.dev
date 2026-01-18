# World of Warcraft Beta Addon Development Guide

## Critical Information for AI Assistants

This document provides essential context for developing addons for the **Beta version of World of Warcraft**. The Beta environment has undergone significant API changes that break many patterns from previous expansions.

---

## ⚠️ Important: LibSAdCore Framework

**This addon uses LibSAdCore as its underlying framework.**

LibSAdCore handles core functionality including:
- Event registration and management
- Zone change detection
- Slash command registration
- Common addon utilities

**Do not implement custom event handlers, slash commands, or zone tracking without first checking if LibSAdCore already provides this functionality.**

📖 **See `Libs/LibSAdCore/README.md` for detailed documentation on LibSAdCore's features and usage patterns.**

When adding new features, always:
1. Check if LibSAdCore provides the capability
2. Use LibSAdCore's patterns for consistency
3. Extend LibSAdCore if the functionality is generic enough to benefit other addons

---

## Understanding FStack Screenshots

### What is FStack?

FStack (Frame Stack) is a debugging tool in WoW that shows the hierarchy of UI frames at the mouse cursor position.

### How to Read FStack Screenshots

When a user provides an FStack screenshot, it contains two critical pieces of information:

1. **Frame Hierarchy (Text Display)**
   - Shows the parent-child relationship of frames
   - Lists from top-level parent down to the deepest child
   - Indentation indicates nesting level
   - **Look for the SOURCE line** - shows which XML/addon creates the frame
   - Example from Essential Cooldowns screenshot:
     ```
     <3> EssentialCooldownViewer.1b634137b20.ChargeCount
     <2> EssentialCooldownViewer.1b634137b20.1b5f7c88730
     <2> EssentialCooldownViewer.1b634137b20.1b5f7c88820
     <2> EssentialCooldownViewer.1b634137b20.Icon
     <!> EssentialCooldownViewer
     SOURCE: Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml:54
     ```
   - Example from Buff Icon Viewer screenshot:
     ```
     <3> BuffIconCooldownViewer.1b6341d4d570.Applications
     <3> BuffIconCooldownViewer.1b6341d4d570.DebuffBorder
     <2> BuffIconCooldownViewer.1b6341d4d570.Cooldown
     <2> BuffIconCooldownViewer.1b6341d4d570.Icon
     <!> BuffIconCooldownViewer
     SOURCE: Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml:189
     [fsobj] = BuffIconCooldownViewer.1b6341d4d570.DebuffBorder
     ```

2. **Visual Context (Mouse Cursor Location)**
   - **The mouse cursor shows EXACTLY what UI element the user is asking about**
   - Look for the cursor in the screenshot to identify the specific visual element
   - The frame stack tells you the technical hierarchy
   - The cursor tells you which specific instance/element they're concerned with

### Key Takeaway

**Always locate the mouse cursor in FStack screenshots** - this tells you exactly which visual element needs modification, even if the frame stack shows many elements.

---

## Beta API Changes - Critical Differences

### 1. Combat Log Elimination

**CRITICAL:** The combat log API has been largely removed in Beta.

- **Old Pattern (BROKEN):** Many addons relied on `COMBAT_LOG_EVENT_UNFILTERED`
- **Impact:** Thousands of addons that parsed combat log events no longer work
- **Alternative:** Use specific unit/spell events instead of combat log parsing

```lua
-- ❌ OLD (Broken in Beta)
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
function addon:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, event, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
    -- This no longer works reliably
end

-- ✅ NEW (Beta Compatible)
addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
function addon:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    -- Use direct unit events instead
end
```

### 2. New API Namespaces

Beta introduces new C_ namespaced APIs. **Always search for these first.**

#### Example: C_CooldownViewer API

The Cooldown Manager in Beta uses **four separate frame containers**:

```lua
-- 1. ESSENTIAL COOLDOWNS - Core class abilities with short cooldowns
EssentialCooldownViewer
-- Example: Thunder Focus Tea, Rising Sun Kick, Touch of Death
-- Frame path: Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml

-- 2. UTILITY COOLDOWNS - Defensive/utility abilities with longer cooldowns
UtilityCooldownViewer
-- Example: Fortifying Brew, Diffuse Magic, Ring of Peace

-- 3. TRACKED BUFFS (Icon Display) - Active buffs you want to monitor
BuffIconCooldownViewer
-- Example: Invoke Chi-Ji, Invoke Yu'lon (shown in "Not Displayed" list)
-- Frame path: Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml:189

-- 4. TRACKED BUFFS (Bar Display) - Buffs displayed as bars with progress indicators
BuffBarCooldownViewer
-- These are distinguishable by containing actual progress bar UI elements
-- Example: Resource tracking, channel bars

-- C_ API Functions
C_CooldownViewer.IsCooldownViewerAvailable()  -- Returns: isAvailable, failureReason
C_Spell.IsSpellUsable(spellID)                -- Check if spell is usable
C_Spell.IsSpellInRange(spellID)               -- Check spell range
C_Spell.EnableSpellRangeCheck(spellID, enable) -- Enable range checking
C_Spell.SpellHasRange(spellID)                -- Check if spell has a range requirement
```

**CRITICAL:** These are completely separate containers. When inspecting FStack:
- Look at the frame hierarchy to identify which viewer you're targeting
- `EssentialCooldownViewer` ≠ `BuffIconCooldownViewer` ≠ `UtilityCooldownViewer`
- Each viewer has its own structure and update methods

#### Cooldown Viewer Frame Structure

From Blizzard's source code, each cooldown item has this structure:

```lua
-- For EssentialCooldownViewer and UtilityCooldownViewer children:
child.Icon          -- Texture for the spell icon
child.Cooldown      -- Cooldown frame (with capital C)
child.ChargeCount   -- Charge count display
child.OutOfRange    -- Out of range indicator
child.CooldownFlash -- Flash animation on cooldown expiration

-- For BuffIconCooldownViewer children:
child.Icon          -- Icon frame containing texture
child.Cooldown      -- Cooldown frame
child.Applications  -- Application/stack count display

-- For BuffBarCooldownViewer children:
child.Icon          -- Icon frame
child.Bar           -- Status bar frame
child.Bar.Name      -- Buff name text
child.Bar.Duration  -- Duration text
child.Bar.Pip       -- Progress indicator
```

#### Cooldown Frame API Methods

The Cooldown frame within each child supports these methods:

```lua
-- Setting cooldown swipe appearance
cooldown:SetSwipeColor(r, g, b, a)  -- r, g, b, a are 0-1 values
cooldown:SetDrawSwipe(bool)         -- Show/hide the swipe animation
cooldown:SetDrawEdge(bool)          -- Show/hide the edge
cooldown:SetUseAuraDisplayTime(bool) -- Use aura time display mode

-- Cooldown control
cooldown:SetCooldown(startTime, duration, modRate)
cooldown:Clear()                     -- Clear the cooldown
cooldown:Pause()                     -- Pause the cooldown animation
cooldown:Resume()                    -- Resume the cooldown animation

-- Countdown text
cooldown:SetCountdownFont(fontPath)  -- Set font for countdown numbers
cooldown:SetHideCountdownNumbers(bool) -- Show/hide countdown text
cooldown:GetHideCountdownNumbers()   -- Check if countdown is hidden

-- Texture customization
cooldown:SetSwipeTexture(texturePath)    -- Set custom swipe texture
cooldown:SetTexCoordRange(low, high)     -- Set texture coordinates
cooldown:SetMinDurationForDisplay(milliseconds) -- Min duration to show countdown
cooldown:SetRotation(radians)           -- Rotate the cooldown
cooldown:SetReverse(bool)               -- Reverse the cooldown direction
```

#### Cooldown Viewer Constants

Blizzard defines these color constants (from CooldownViewer.lua):

```lua
CooldownViewerConstants = {
    ITEM_USABLE_COLOR = CreateColor(1.0, 1.0, 1.0, 1.0),         -- White
    ITEM_NOT_ENOUGH_MANA_COLOR = CreateColor(0.5, 0.5, 1.0, 1.0), -- Blue
    ITEM_NOT_USABLE_COLOR = CreateColor(0.4, 0.4, 0.4, 1.0),     -- Gray
    ITEM_NOT_IN_RANGE_COLOR = CreateColor(0.64, 0.15, 0.15, 1.0), -- Red
    
    ITEM_AURA_COLOR = CreateColor(1, 0.95, 0.57, 0.7),          -- Gold/Yellow with transparency
    ITEM_COOLDOWN_COLOR = CreateColor(0, 0, 0, 0.7),            -- Black with 70% opacity (DEFAULT)
}
```

#### Relevant Events

```lua
-- Cooldown-specific events
"SPELL_UPDATE_COOLDOWN"              -- Fires when spell cooldowns update
"COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" -- Spell override changes
"COOLDOWN_VIEWER_TABLE_HOTFIXED"     -- Cooldown data hotfixed

-- Aura events (for BuffIconCooldownViewer)
"UNIT_AURA"                          -- Unit aura changed
"PLAYER_TOTEM_UPDATE"                -- Totem updated

-- Other relevant events
"SPELL_UPDATE_USABLE"                -- Spell usability changed
"PLAYER_REGEN_ENABLED"               -- Left combat
"PLAYER_REGEN_DISABLED"              -- Entered combat
"PLAYER_LEVEL_CHANGED"               -- Player level changed
```

#### EventRegistry Callbacks

Cooldown Viewer uses EventRegistry for internal communication:

```lua
EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", callback, self)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", callback, self)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", callback, self)
```

#### CVar Settings

```lua
-- Enable/disable cooldown viewer
CVarCallbackRegistry:GetCVarValueBool("cooldownViewerEnabled")
CVarCallbackRegistry:SetCVarValueBool("cooldownViewerEnabled", enabled)

-- Show unlearned spells in settings
CVarCallbackRegistry:GetCVarValueBool("cooldownViewerShowUnlearned")
```

### 3. Frame Structure Changes

**Cooldown frames have changed:**

```lua
-- Old pattern (may not work)
button.cooldown:SetSwipeColor(r, g, b, a)

-- Check new structure first
-- BuffIconCooldownViewer children may have:
child.Cooldown  -- Capital C
child.Icon
child.Count
```

---

## 3. Additional Midnight Beta API Changes

### Major API Additions and Changes in 12.0

Based on Blizzard's official source code and the 12.0 (Midnight) patch notes, the Beta has undergone extensive API modernization beyond just the C_CooldownViewer system. Here are the most significant changes:

#### Critical: Deprecated APIs Removed in 12.0

⚠️ **These APIs no longer exist and will cause errors if used:**

1. **Combat Log Functions** - Many traditional COMBAT_LOG_EVENT functions removed or deprecated
2. **Old Spell Book Functions** - Replaced with C_Spell and C_SpellBook namespaces
3. **Traditional UnitAura()** - Replaced with C_UnitAuras namespace
4. **Old Specialization APIs** - Moved to C_SpecializationInfo namespace
5. **Old Guild Functions** - Moved to C_GuildInfo namespace

#### New C_ Namespace APIs in Midnight

**C_AssistedCombat** - New assisted combat/rotation system:
```lua
C_AssistedCombat.GetActionSpell()                    -- Get the assisted combat action spell
C_AssistedCombat.GetNextCastSpell(checkForVisibleButton) -- Get next recommended spell
C_AssistedCombat.GetRotationSpells()                 -- Get full rotation spell list
C_AssistedCombat.IsAvailable()                       -- Check if assisted combat is available
```

**C_PlayerInfo** - Expanded player capability checks:
```lua
C_PlayerInfo.CanPlayerEnterChromieTime()    -- Check Chromie Time eligibility
C_PlayerInfo.CanPlayerUseAreaLoot()         -- Check area loot availability
C_PlayerInfo.CanPlayerUseMountEquipment()   -- Check mount equipment system
C_PlayerInfo.CanPlayerUseEventScheduler()   -- Check event scheduler access
```

**C_ClassTalents** - Complete talent system API:
```lua
C_ClassTalents.CanChangeTalents()           -- Returns: canChange, canAdd, changeError
C_ClassTalents.CanEditTalents()             -- Check if talents can be edited
C_ClassTalents.HasUnspentPoints()           -- Returns: hasUnspent, numClassPoints, numSpecPoints
C_ClassTalents.GetActiveConfigID()          -- Get current talent config
C_ClassTalents.ImportLoadout(configID, entries, name) -- Import talent loadout
```

**C_UnitAuras** - Complete aura system rewrite:
```lua
-- Instance-based aura system (replaces old UnitAura)
C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
C_UnitAuras.GetAuraDataBySpellID(unit, spellID)
C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)     -- First instance only
C_UnitAuras.GetUnitAuras(unit, filter, maxCount, continuationToken)
C_UnitAuras.WantsAlteredForm(unit)                  -- Check if unit wants alternate form display
```

**C_Spell** - Centralized spell information:
```lua
C_Spell.DoesSpellExist(spellIdentifier)      -- Check if spell exists in game
C_Spell.GetSpellInfo(spellIdentifier)        -- Returns full SpellInfo table
C_Spell.GetSpellName(spellIdentifier)        -- Just the name
C_Spell.GetSpellTexture(spellIdentifier)     -- Just the icon fileID
C_Spell.GetSpellDescription(spellIdentifier) -- Spell description text
C_Spell.GetSpellSubtext(spellIdentifier)     -- Spell subtext (e.g., "Rank 2")
C_Spell.IsSpellUsable(spellIdentifier)       -- Check usability
C_Spell.IsSpellPassive(spellIdentifier)      -- Check if passive
C_Spell.IsSpellHelpful(spellIdentifier)      -- Check if helpful (healing/buff)
C_Spell.IsSpellHarmful(spellIdentifier)      -- Check if harmful (damage/debuff)
C_Spell.GetSpellCooldown(spellIdentifier)    -- Returns SpellCooldownInfo table
C_Spell.GetSpellCharges(spellIdentifier)     -- Returns SpellChargeInfo table
```

**C_SpellBook** - Spell book management:
```lua
C_SpellBook.GetNumSpellBookSkillLines()      -- Number of spell categories
C_SpellBook.GetSpellBookSkillLineInfo(index) -- Returns SpellBookSkillLineInfo
C_SpellBook.GetSpellBookItemInfo(index, spellBank) -- Full item info
C_SpellBook.GetSpellBookItemType(index, spellBank) -- Type + spellID
C_SpellBook.GetSpellBookItemName(index, spellBank)
C_SpellBook.GetSpellBookItemTexture(index, spellBank)
C_SpellBook.IsSpellInSpellBook(spellID, spellBank, includeOverrides)
C_SpellBook.IsSpellKnown(spellID, spellBank)
C_SpellBook.CastSpellBookItem(slotIndex, spellBank, targetSelf)
C_SpellBook.PickupSpellBookItem(index, spellBank)
```

#### Important Enum Changes

**Enum.SpellBookSpellBank** (replaces string "bookType"):
```lua
-- OLD WAY (deprecated):
local spellName = GetSpellBookItemName(5, "spell")

-- NEW WAY (12.0+):
local spellName = C_SpellBook.GetSpellBookItemName(5, Enum.SpellBookSpellBank.Player)

-- Enum values:
Enum.SpellBookSpellBank.Player  -- Replaces "spell" / BOOKTYPE_SPELL
Enum.SpellBookSpellBank.Pet     -- Replaces "pet" / BOOKTYPE_PET
```

**Enum.TraitNodeEntryType** (talent trees):
```lua
Enum.TraitNodeEntryType.SpendSquare  -- Square talent nodes
Enum.TraitNodeEntryType.SpendCircle  -- Circular talent nodes
```

#### Critical Breaking Changes for Addon Developers

**1. Region:ClearAllPoints() Behavior Changed:**
```lua
-- WRONG - Will fail in 12.0:
local width = frame:GetWidth()
frame:ClearAllPoints()
frame:SetSize(width, 50)  -- width is now invalid!

-- CORRECT - Measure before clearing:
local width = frame:GetWidth()
local height = frame:GetHeight()
frame:ClearAllPoints()
frame:SetSize(width, height)  -- Use stored values
```

**2. Spell Identifier Flexibility:**

The new "spellIdentifier" parameter accepts multiple formats:
```lua
-- All of these work:
C_Spell.GetSpellInfo(12345)                -- Spell ID
C_Spell.GetSpellInfo("Fireball")          -- Spell name
C_Spell.GetSpellInfo("Fireball(Rank 5)")  -- Name with subtext
C_Spell.GetSpellInfo(spellLink)           -- Spell link from chat
```

**3. Aura System is Now Instance-Based:**

```lua
-- OLD WAY (deprecated):
local name, icon, count = UnitAura("player", 1, "HELPFUL")

-- NEW WAY (12.0+):
local auraData = C_UnitAuras.GetAuraDataByIndex("player", 1, "HELPFUL")
if auraData then
    local name = auraData.name
    local icon = auraData.icon
    local count = auraData.applications
    local auraInstanceID = auraData.auraInstanceID  -- NEW: unique instance ID
end
```

**4. UNIT_AURA Event Structure Changed:**

```lua
-- Event handler now receives UnitAuraUpdateInfo
function MyAddon:UNIT_AURA(unit, updateInfo)
    -- updateInfo structure:
    {
        isFullUpdate = false,              -- true = full refresh needed
        removedAuraInstanceIDs = {123, 456}, -- Array of removed aura IDs
        addedAuras = {AuraData, AuraData},  -- Array of new AuraData
        updatedAuraInstanceIDs = {789}      -- Array of changed aura IDs
    }
    
    -- Handle removed auras
    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            -- Aura was removed
        end
    end
    
    -- Handle added auras
    if updateInfo.addedAuras then
        for _, auraData in ipairs(updateInfo.addedAuras) do
            -- New aura: auraData.auraInstanceID, auraData.name, etc.
        end
    end
    
    -- Handle updated auras
    if updateInfo.updatedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
            -- Aura was updated (duration, stacks, etc.)
        end
    end
end
```

#### Common Migration Examples

```lua
-- ===== SPELL INFORMATION =====
-- OLD:
local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID)
local isPassive = IsPassiveSpell(spellID)
local isUsable, notEnoughMana = IsUsableSpell(spellID)

-- NEW:
local spellInfo = C_Spell.GetSpellInfo(spellID)
local name, icon, castTime = spellInfo.name, spellInfo.iconID, spellInfo.castTime
local minRange, maxRange = spellInfo.minRange, spellInfo.maxRange
local isPassive = C_Spell.IsSpellPassive(spellID)
local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)

-- ===== SPELL COOLDOWNS =====
-- OLD:
local start, duration, enabled = GetSpellCooldown(spellID)

-- NEW:
local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
local start, duration, enabled = cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.isEnabled

-- ===== SPELL CHARGES =====
-- OLD:
local currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spellID)

-- NEW:
local chargeInfo = C_Spell.GetSpellCharges(spellID)
local currentCharges = chargeInfo.currentCharges
local maxCharges = chargeInfo.maxCharges
local cooldownStart = chargeInfo.cooldownStartTime
local cooldownDuration = chargeInfo.cooldownDuration

-- ===== SPELL BOOK =====
-- OLD:
local numTabs = GetNumSpellTabs()
local name, texture, offset, numSlots = GetSpellTabInfo(tabIndex)
local spellType, spellID = GetSpellBookItemInfo(slotIndex, "spell")

-- NEW:
local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(tabIndex)
local name, texture, offset, numSlots = skillLineInfo.name, skillLineInfo.iconID, 
                                        skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
local spellType, spellID = C_SpellBook.GetSpellBookItemType(slotIndex, Enum.SpellBookSpellBank.Player)

-- ===== AURAS =====
-- OLD:
local name, icon, count, debuffType, duration, expirationTime = UnitAura("player", 1, "HELPFUL")

-- NEW:
local auraData = C_UnitAuras.GetAuraDataByIndex("player", 1, "HELPFUL")
if auraData then
    local name = auraData.name
    local icon = auraData.icon
    local count = auraData.applications
    local debuffType = auraData.dispelName
    local duration = auraData.duration
    local expirationTime = auraData.expirationTime
    local auraInstanceID = auraData.auraInstanceID
end

-- ===== GUILD =====
-- OLD:
GuildInvite(playerName)
GuildPromote(playerName)

-- NEW:
C_GuildInfo.Invite(playerName)
C_GuildInfo.Promote(playerName)
```

#### Nameplate and UI Improvements

Midnight also includes major nameplate enhancements:
- New visual style options
- Improved combat information display (interrupts show player name)
- Enhanced threat/aggro visual indicators
- Better buff/debuff display on nameplates
- New options menu under Gameplay settings

#### Resources for Addon Developers

For the most comprehensive migration guide, refer to:
- `11_0_0_SpellBookAPITransitionGuide.lua` in Blizzard_Deprecated addon
- `Deprecated_*.lua` files in various Blizzard_Deprecated* addons
- API documentation in `Blizzard_APIDocumentationGenerated` addons

**Key Blizzard Documentation Files:**
- `SpellDocumentation.lua`
- `SpellBookDocumentation.lua`
- `SpellSharedDocumentation.lua`
- `UnitAuraDocumentation.lua`
- `ClassTalentsDocumentation.lua`

---

## 4. Frame Structure Changes

**Cooldown frames have changed:**

```lua
-- Old pattern (may not work)
button.cooldown:SetSwipeColor(r, g, b, a)

-- Check new structure first
-- BuffIconCooldownViewer children may have:
child.Cooldown  -- Capital C
child.Icon
child.Count
```

---

## 5. Development Methodology and Best Practices

### Research Before Coding

⚠️ **Prioritize understanding over guessing.** In the Beta environment where APIs have changed significantly, it's critical to verify the correct approach before writing production code.

#### Test-Driven Exploration

When you don't know which approach will work:

**1. Write Test Functions with Visual Indicators**
```lua
-- Test multiple approaches with color-coded backgrounds
function addon.testApproaches()
    -- Approach 1: Try child.cooldown (lowercase)
    for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
        if child.cooldown then
            child:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            child:SetBackdropColor(1, 0, 0, 0.5)  -- RED = lowercase worked
        end
    end
    
    -- Approach 2: Try child.Cooldown (capital C)
    for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
        if child.Cooldown then
            child:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            child:SetBackdropColor(0, 1, 0, 0.5)  -- GREEN = capital C worked
        end
    end
    
    -- Approach 3: Try GetRegions
    for _, region in ipairs({EssentialCooldownViewer:GetRegions()}) do
        if region.SetSwipeColor then
            region:GetParent():SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            region:GetParent():SetBackdropColor(0, 0, 1, 0.5)  -- BLUE = regions worked
        end
    end
end

-- Result: If you see GREEN backgrounds in-game, you know child.Cooldown is correct
```

**Why this works:**
- Visual feedback is immediate and unambiguous
- Test multiple theories simultaneously
- Color coding makes it obvious which approach succeeded
- No need to toggle code on/off repeatedly

#### Targeted Print Debugging

When troubleshooting, use print statements strategically:

**❌ TOO VERBOSE:**
```lua
for i, child in ipairs({frame:GetChildren()}) do
    print("Iteration:", i)
    print("Child:", child:GetName())
    print("Child type:", child:GetObjectType())
    print("Has Cooldown:", child.Cooldown and "yes" or "no")
    print("Cooldown color:", child.Cooldown and "checking..." or "N/A")
    -- This floods chat and exceeds buffer limits
end
```

**✅ TARGETED:**
```lua
for _, child in ipairs({frame:GetChildren()}) do
    if child.Cooldown then
        print("Found Cooldown on:", child:GetName() or "unnamed")
    end
end
-- Only prints what you need to know
```

**Chat Window Limitations:**
- **Horizontal space**: ~80-100 characters before wrapping
- **Vertical space**: ~20-30 visible lines depending on chat size
- **Buffer**: Last ~128 messages before scrolling off
- **Solution**: Keep messages short, focused, and count-limited

**Better Print Practices:**
```lua
-- Limit output quantity
local count = 0
for _, child in ipairs({frame:GetChildren()}) do
    if child.Cooldown then
        print(string.format("CD#%d: %s", count, child:GetName() or "?"))
        count = count + 1
        if count >= 5 then break end  -- Stop after 5 to avoid spam
    end
end

-- Use abbreviations to save space
print(string.format("EC:%d BC:%d", essentialCount, buffCount))  -- Not "EssentialCooldownCount: 5"

-- Combine related info on one line
print(string.format("%s|c:%d|t:%s", name, count, tostring(hasTexture)))
```

#### Clean Up Failed Attempts

**Critical Rule: Remove code that didn't work.**

```lua
-- BAD: Leaving dead code
function addon.updateUI.customizeEssentialCooldowns()
    -- This didn't work but we left it commented out:
    -- for _, region in ipairs({frame:GetRegions()}) do
    --     if region.cooldown then
    --         region.cooldown:SetSwipeColor(0, 0, 0, 0.5)
    --     end
    -- end
    
    -- This also didn't work:
    -- for _, button in ipairs(ActionButtons) do
    --     button.cooldown:SetSwipeColor(0, 0, 0, 0.5)
    -- end
    
    -- Final working solution:
    for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
        if child.Cooldown then
            child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
        end
    end
end

-- GOOD: Only the working code remains
function addon.updateUI.customizeEssentialCooldowns()
    for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
        if child.Cooldown then
            child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
        end
    end
end
```

**Why this matters:**
- Failed code adds confusion
- Makes debugging harder ("Is this dead code or does it do something?")
- Increases file size unnecessarily
- Future developers waste time reading irrelevant code
- Git history preserves deleted code if you need to reference it

#### Hook Functions Are Essential

**Critical Pattern: Almost all UI modifications require hook functions.**

UI elements in WoW frequently reset or recreate themselves. Your initial modification will work once, but then get overridden. You must use hooks to reapply your changes.

**Pattern: Initial Setup + Hook**
```lua
-- Define the modification as a reusable function
local function ApplyMyCustomization(frame)
    frame:SetAlpha(0)  -- Hide the frame
    frame:SetScale(0.8)
    -- etc.
end

-- Apply initially
ApplyMyCustomization(SomeFrame)

-- Hook to reapply whenever the frame updates
hooksecurefunc(SomeFrame, "Show", ApplyMyCustomization)
-- OR hook a parent method:
hooksecurefunc(ParentFrame, "UpdateSomething", function()
    ApplyMyCustomization(SomeFrame)
end)
```

**Common Hookable Methods:**
- `Show()` - When frame becomes visible
- `SetCooldown()` - When cooldown is set
- Any Update method (`UpdateCooldowns`, `UpdateLayout`, etc.)

**✅ GOOD: Refactored Common Code**
```lua
function addon.updateUI.hidePlayerFrame()
    -- Common function for the modification
    local function HideFrame()
        if PlayerFrame then
            PlayerFrame:SetAlpha(0)
        end
    end
    
    -- Apply initially
    HideFrame()
    
    -- Hook to reapply
    hooksecurefunc(PlayerFrame, "Show", HideFrame)
end
```

**❌ BAD: Duplicated Code**
```lua
function addon.updateUI.hidePlayerFrame()
    -- Initial setup (duplicated code)
    if PlayerFrame then
        PlayerFrame:SetAlpha(0)
    end
    
    -- Hook with duplicated code
    hooksecurefunc(PlayerFrame, "Show", function()
        if PlayerFrame then
            PlayerFrame:SetAlpha(0)  -- Same code repeated
        end
    end)
end
```

**When to Use Hooks:**
- ✅ Hiding/showing frames (they reappear)
- ✅ Changing colors/textures (they reset)
- ✅ Modifying sizes/positions (layout updates override)
- ✅ Setting cooldown properties (cooldowns get reset)
- ❌ One-time global settings (like CVars)
- ❌ Creating new frames (only do once)

**Debugging Hook Issues:**
```lua
-- Add a counter to see if your hook is being called
local callCount = 0
hooksecurefunc(Frame, "Method", function()
    callCount = callCount + 1
    print("Hook called:", callCount)
    ApplyCustomization()
end)
```

### Development Workflow Summary

1. **Research First**: Check Beta documentation, FStack, and C_ APIs
2. **Test Visually**: Use color-coded backgrounds to test multiple approaches simultaneously
3. **Debug Targeted**: Print only what you need, keep it short
4. **Hook Everything**: UI changes need hooks to persist
5. **Refactor Common Code**: Don't duplicate between initial setup and hooks
6. **Validate In-Game**: Always `/reload` and verify the actual result
7. **Clean Up**: Remove failed attempts before committing

### When Stuck

1. Use FStack to inspect the actual frame structure
2. Write a test function with visual indicators
3. Check if the frame/API exists: `print(type(FrameName))`
4. Look for EventRegistry callbacks or hooks
5. Search Blizzard source code (Gethe/wow-ui-source on GitHub)

---

## 6. API Reference for Beta

### 1. Always Search for New APIs First

When solving any problem:
- Check for `C_<NameSpace>` APIs related to your task
- Use `/fstack` in-game to inspect actual frame structures
- Assume old patterns may not work

### 2. Avoid These Old Patterns

❌ **Combat log parsing** - Combat log API largely removed  
❌ **Global function names** - Many moved to C_ namespaces  
❌ **Hardcoded frame structures** - Frame hierarchies have changed  
❌ **Old event names** - Some events renamed or removed  

### 3. Use These Modern Patterns

✅ **C_ namespaced APIs** - `C_CooldownViewer`, `C_Spell`, `C_UnitAuras`, etc.  
✅ **Direct unit events** - `UNIT_SPELLCAST_*`, `UNIT_AURA`, etc.  
✅ **Frame inspection** - Use FStack to verify actual structure  
✅ **hooksecurefunc** - Hook Blizzard functions to apply customizations  

---

## Practical Example: Customizing Cooldown Overlays

### Problem
User wants to change cooldown swipe color on Essential Cooldowns (the Thunder Focus Tea icon).

### Solution Process

1. **Read FStack Screenshot Carefully**
   - Mouse cursor shows the specific cooldown icon (Thunder Focus Tea)
   - Frame stack reveals: `EssentialCooldownViewer.1b634137b20.Icon`
   - **SOURCE line confirms:** `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml:54`
   - This is **EssentialCooldownViewer**, NOT BuffIconCooldownViewer
   - These are separate containers!

2. **Understand the Four Cooldown Containers**
   - **EssentialCooldownViewer** - Core class abilities (Thunder Focus Tea, Rising Sun Kick)
   - **UtilityCooldownViewer** - Defensive/utility abilities (Fortifying Brew, Ring of Peace)
   - **BuffIconCooldownViewer** - Tracked buffs shown as icons (Invoke Chi-Ji)
   - **BuffBarCooldownViewer** - Tracked buffs shown as bars with progress indicators

3. **Inspect Frame Structure for the Correct Viewer**
   ```lua
   if EssentialCooldownViewer then  -- NOT BuffIconCooldownViewer!
       for _, child in pairs({EssentialCooldownViewer:GetChildren()}) do
           -- Check what properties exist
           if child.Cooldown then  -- Capital C - this is a Cooldown frame
               -- Set cooldown swipe color to black with 50% opacity
               child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
           end
       end
   end
   ```

4. **Hook for Dynamic Updates**
   
   **Method 1: Direct Frame Iteration (Recommended for Beta)**
   ```lua
   -- Cooldown frames are created dynamically based on known spells
   -- Hook into the viewer's data change to reapply customizations
   if EssentialCooldownViewer then
       local function CustomizeEssentialCooldowns()
           for _, child in pairs({EssentialCooldownViewer:GetChildren()}) do
               if child.Cooldown then
                   child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
               end
           end
       end
       
       -- Run immediately
       CustomizeEssentialCooldowns()
       
       -- Hook to data changes (when spells are learned/talents change)
       EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", 
           CustomizeEssentialCooldowns)
   end
   ```

   **Method 2: Event-Based (Most Reliable)**
   ```lua
   -- Listen to relevant events that trigger cooldown updates
   local function OnCooldownUpdate()
       if EssentialCooldownViewer then
           for _, child in pairs({EssentialCooldownViewer:GetChildren()}) do
               if child.Cooldown then
                   child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
               end
           end
       end
   end
   
   addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnCooldownUpdate)
   addon:RegisterEvent("SPELLS_CHANGED", OnCooldownUpdate)
   addon:RegisterEvent("TRAIT_CONFIG_UPDATED", OnCooldownUpdate) -- Talent changes
   ```

5. **Complete Working Example**
   ```lua
   function addon.updateUI.customizeEssentialCooldowns()
       local function CustomizeCooldowns()
           if EssentialCooldownViewer then
               for _, child in pairs({EssentialCooldownViewer:GetChildren()}) do
                   if child.Cooldown then
                       -- Set cooldown swipe color to black with 50% opacity
                       child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
                       
                       -- Optional: Customize other cooldown properties
                       child.Cooldown:SetDrawSwipe(true)     -- Ensure swipe is shown
                       child.Cooldown:SetDrawEdge(false)     -- Hide edge texture
                   end
               end
           end
       end
       
       -- Apply immediately
       CustomizeCooldowns()
       
       -- Reapply when cooldown data changes
       EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", 
           CustomizeCooldowns)
   end
   ```

### Common Mistake: Confusing the Viewers

```lua
-- ❌ WRONG - This targets TRACKED BUFFS (icon display), not essential cooldowns
if BuffIconCooldownViewer then
    for _, child in pairs({BuffIconCooldownViewer:GetChildren()}) do
        child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
    end
end

-- ✅ CORRECT - This targets ESSENTIAL COOLDOWNS
if EssentialCooldownViewer then
    for _, child in pairs({EssentialCooldownViewer:GetChildren()}) do
        child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
    end
end

-- ✅ ALSO CORRECT - This targets UTILITY COOLDOWNS
if UtilityCooldownViewer then
    for _, child in pairs({UtilityCooldownViewer:GetChildren()}) do
        child.Cooldown:SetSwipeColor(0, 0, 0, 0.5)
    end
end
```

### Advanced Customization Options

```lua
-- Different colors for different states
local function CustomizeCooldownAdvanced(cooldownFrame, child)
    -- Check if spell is on cooldown
    local start, duration = cooldownFrame:GetCooldownTimes()
    local isOnCooldown = start > 0 and duration > 0
    
    if isOnCooldown then
        -- Black during cooldown
        cooldownFrame:SetSwipeColor(0, 0, 0, 0.5)
    else
        -- Different color when ready (e.g., green tint)
        cooldownFrame:SetSwipeColor(0, 0.8, 0, 0.3)
    end
    
    -- Customize based on spell usability
    local spellID = child.spellID  -- If available on the child frame
    if spellID then
        local isUsable = C_Spell.IsSpellUsable(spellID)
        if not isUsable then
            -- Red tint when not usable
            cooldownFrame:SetSwipeColor(0.8, 0, 0, 0.5)
        end
    end
end
```

**Key Lesson:** Always check the FStack SOURCE line and parent frame name. The Cooldown Manager has four separate containers, and each must be targeted individually.

---

## Testing in Beta

### Essential Commands

```lua
/fstack          -- Show frame stack at cursor
/framestack      -- Alternative command
/dump frame      -- Inspect frame properties in chat
/etrace          -- Event trace (see what events fire)
```

### Verification Steps

1. Use `/fstack` to confirm frame structure matches your code
2. Check for Lua errors after reloading (`/reload`)
3. Test that customizations persist through:
   - Combat transitions
   - Zone changes
   - UI reloads
   - Talent changes (abilities may change)

---

## Common Beta Gotchas

### 1. Frame Children Are Dynamic

Cooldown viewers create children dynamically. Always iterate and check:

```lua
-- ✅ Good - Iterates dynamically created children
for _, child in pairs({BuffIconCooldownViewer:GetChildren()}) do
    -- Apply customization
end

-- ❌ Bad - Assumes fixed children
local icon1 = BuffIconCooldownViewer.Icon1  -- May not exist
```

### 2. APIs May Not Exist Yet

Beta is in development. Some APIs may:
- Not be implemented yet
- Change between builds
- Have incomplete documentation

Always check if functions exist:

```lua
if BuffIconCooldownViewer and BuffIconCooldownViewer.UpdateCooldowns then
    -- Safe to hook
end
```

### 3. Secure vs Insecure Frames

Combat lockdown restrictions still apply:

```lua
function addon:ApplyCustomization()
    if InCombatLockdown() then
        -- Defer until combat ends
        addon.pendingUpdate = true
        return
    end
    -- Apply changes
end
```

---

## Resources for Beta Development

### Finding New APIs

1. **Blizzard's FrameXML** - Check Beta client's FrameXML folder
2. **API Changes Threads** - Wowpedia and WoW UI & Macros forum
3. **FStack** - Your best friend for discovering actual implementations
4. **Community Beta Discord** - Other developers share discoveries

### Useful Lua Patterns

```lua
-- Check if API exists before using
if C_CooldownViewer then
    local cooldowns = C_CooldownViewer.GetCooldowns()
end

-- Safely iterate unknown structures
for key, value in pairs(someFrame) do
    print(key, type(value))
end

-- Dump frame info
DevTools_Dump(BuffIconCooldownViewer)  -- If DevTools loaded
```

---

## Summary for AI Assistants

When helping with WoW Beta addon development:

1. **Read FStack screenshots carefully** - Find the mouse cursor to identify the exact element
2. **Assume old patterns are broken** - Especially combat log related code
3. **Search for C_ APIs first** - New namespaced APIs are the modern approach
4. **Verify frame structures** - Don't assume frame hierarchies from old expansions
5. **Test with /fstack in mind** - Suggest users provide FStack screenshots for precision
6. **Avoid legacy code patterns** - Combat log, global functions, old event names

Remember: Beta is evolving. Code that works today may need adjustment in the next build.

# AI Assistant Instructions for SAdUI Project

## Project Overview
This is a **World of Warcraft Beta addon** (version 11.2.x/12.0.x) that customizes the default UI. The Beta environment has **significant API changes** that break many patterns from previous expansions.

## Critical Guidelines

### 1. Always Consult the Beta Guide
**Before making any changes**, review `WOW_BETA_ADDON_DEVELOPMENT_GUIDE.md` for:
- Understanding FStack screenshots (look for SOURCE line and mouse cursor position)
- Beta-specific API changes (C_CooldownViewer, C_Spell, C_UnitAuras, etc.)
- Frame structure differences between Beta and Live
- Deprecated APIs that no longer exist in Beta

### 2. FStack Screenshot Interpretation
When the user provides FStack screenshots:
- **Check the SOURCE line** to identify which addon creates the frame
- **Look at the mouse cursor** to see exactly what UI element they're referencing
- Frames may have different structures than expected (e.g., `child.Cooldown` not `child.cooldown`)
- Essential Cooldowns ≠ Buff Icon Viewer ≠ Action Bars (they're separate systems)

### 3. Beta API Considerations
- Many traditional APIs are deprecated or removed
- Use `C_*` namespace functions (C_Spell, C_SpellBook, C_UnitAuras, etc.)
- Spell identifiers now accept IDs, names, or links
- Aura system is instance-based with `auraInstanceID`
- `Region:ClearAllPoints()` immediately invalidates measurements
- Combat log functions are mostly eliminated

### 4. Code Style
- Use descriptive variable names
- Add comments explaining Beta-specific workarounds
- Test frame existence before accessing child properties
- Use EventRegistry for dynamic frame updates when applicable

### 5. Testing Reminders
- Remind user to test with `/reload` in-game
- Beta behavior may differ from documentation
- Frame structures should be verified with FStack if issues occur

## Common Pitfalls to Avoid
1. ❌ Don't assume frame structures match Live WoW
2. ❌ Don't use deprecated APIs (GetSpellInfo, UnitAura, etc.)
3. ❌ Don't confuse different cooldown viewers (Essential vs Buff Icon vs Action Bars)
4. ❌ Don't call GetWidth/GetHeight after ClearAllPoints
5. ❌ Don't target action bars when user wants cooldown viewers

## Helpful Files
- `development_guide.md` - Comprehensive Beta API reference
- `SAdUI.lua` - Main addon code
- `Localization.lua` - Localization strings
- `.dev/deploy.ps1` - Deployment script to WoW addons folder

## Deployment
After making changes, user can run `.\.dev\deploy.ps1` to copy the addon to their WoW folder and test in-game.


# SAdCore Style Guide

This document outlines the coding standards and requirements for the SAdCore framework.

## Tools and Linting

**LUA Helper by Tencent** is used to apply linting to LUA files. Ensure your code passes linting checks before committing.

## Scope

These constraints apply **ONLY** to `addon.*` functions (functions on the addon table). Local (private) functions are NOT subject to these requirements as they cannot be hooked by external addons.

## Critical Coding Constraints

### 1. Hook Requirement

Every `addon.*` function MUST include:
- `callHook(self, "BeforeFunctionName", ...)` as the first line
- `callHook(self, "AfterFunctionName", returnValue)` before EVERY return statement

### 2. Return Value Requirement

Every `addon.*` function MUST explicitly return a value:
- Success functions typically return `true` or the actual result
- Failed/error conditions MUST return `false` or the actual result (NEVER `nil`)
- NO function should end without an explicit return statement
- NEVER return `nil` - use `false` for failures, `true` for success, or actual data

### 3. Short-Circuit Returns

When returning early (error conditions, validation failures):
- MUST call the After hook with the return value
- MUST explicitly return that value (`false` for errors, never `nil`)

Example:
```lua
if not data then
    callHook(self, "AfterFunctionName", false)
    return false
end
```

### 4. Standard Function Pattern

```lua
function addon:FunctionName(params)
    callHook(self, "BeforeFunctionName", params)
    
    -- Early return example
    if errorCondition then
        callHook(self, "AfterFunctionName", false)
        return false
    end
    
    -- Function logic here
    
    local returnValue = true
    callHook(self, "AfterFunctionName", returnValue)
    return returnValue
end
```

## Localization Requirements

### All User-Facing Messages Must Use Localization

All `info` and `error` messages MUST use localization strings via `self:L()`:

**✅ Correct:**
```lua
self:error(self:L("frameNotFound") .. ": " .. frameName)
self:info(self:L("importSuccess"))
```

**❌ Incorrect:**
```lua
self:error("Frame not found: " .. frameName)
self:info("Import successful")
```

This ensures the framework can be localized for different languages.

### Tagline Translation Guidelines

The framework tagline "Simple Addons—Bare minimum addons for bare minimum brains." must follow specific translation rules:

**Critical Rules:**

1. **"Simple Addons" MUST remain in English** - This is the source of the "SAd" acronym and MUST NOT be translated
2. **Self-deprecating humor** - The tagline is intentionally self-deprecating and humorous in tone
3. **"brains" = intellectual capacity** - When translating "brains", use words that refer to intellectual capacity or mental ability, NOT the physical brain organ

**Translation Pattern:**
```
Simple Addons—[Minimal/bare minimum] [addons/extensions] for [minimal/bare minimum] [minds/intellects].
```

**Examples:**
- Spanish: "Simple Addons—Addons mínimos para mentes mínimas."
- Russian: "Simple Addons—Минимальные аддоны для минимального ума."
- French: "Simple Addons—Addons minimaux pour esprits minimaux."
- German: "Simple Addons—Minimale Addons für minimale Köpfe."

**Note:** "Simple Addons" staying in English preserves brand identity across all languages while the humor translates naturally.

## Code Comments

### Minimal Comments Philosophy

Code should be self-documenting. Comments should be rare and strategic.

### Allowed Comments

**Only the following types of comments are permitted:**

1. **Section Header Comments** - Large sections with `do` scopes:
   ```lua
   do -- Initialization
       -- functions here
   end
   
   do -- Settings Panels
       -- functions here
   end
   ```

2. **File Header Comments** - Copyright, license, and framework description at the top of files

### Prohibited Comments

**Do NOT use comments for:**
- Explaining what code does (write clearer code instead)
- TODO notes (use issue tracking)
- Inline explanations (refactor for clarity)
- Parameter documentation (use clear parameter names)

### Examples

**❌ Bad (over-commented):**
```lua
-- Set the width to 500
local width = 500

-- Loop through all items
for i = 1, #items do
    -- Get the current item
    local item = items[i]
    -- Process the item
    processItem(item)
end
```

**✅ Good (self-documenting):**
```lua
local defaultDialogWidth = 500

for _, item in ipairs(items) do
    processItem(item)
end
```

## Code Clarity

### Write Self-Explanatory Code

Scoped code should be written clearly enough that its purpose is understandable without comments.

**Strategies for self-documenting code:**
- Use descriptive variable names
- Use descriptive function names
- Keep functions small and focused
- Use meaningful constants instead of magic numbers
- Structure code logically

### Affirmative Logic Requirement

**All logic must be written in the affirmative case.** Avoid negative variable names and double negatives in conditionals.

**✅ Correct (affirmative):**
```lua
local visible = frame:IsVisible()
if visible then
    showFrame()
end

local enabled = GetSettingValue("feature")
if enabled then
    activateFeature()
end

local success = ProcessData(data)
if success then
    self:info(self:L("operationSuccess"))
end
```

**❌ Incorrect (negative):**
```lua
local hidden = not frame:IsVisible()
if not hidden then
    showFrame()
end

local disabled = not GetSettingValue("feature")
if not disabled then
    activateFeature()
end

local failed = not ProcessData(data)
if not failed then
    self:info(self:L("operationSuccess"))
end
```

**Rationale:** Double negatives (`if not hidden`, `if not disabled`) are harder to read and reason about. Affirmative logic makes code intention immediately clear and reduces cognitive load when reading conditions.

**Note:** This is a general rule. There are always exceptions. If the code becomes complex or harder to read because of trying to follow this rule, then it might be a valid exception. Use your judgment to prioritize overall code clarity.

### Developer Documentation Location

**Do NOT put developer documentation in code comments.**

Documentation for developers implementing or using SAdCore should go in:
- **README.md** - User guide, getting started, examples
- **API documentation** - Function signatures and usage
- **This style guide** - Coding standards and patterns

The main code should be clean and focused on implementation.

### Comment Policy

**Comments should be minimal and limited to simple section headers.**

**Permitted comments:**
- File header (at the very top of the file only): license, copyright, or brief file description
- Simple section headers for large code blocks: `-- Section Name` (e.g., `-- Russian`, `-- Utility Functions`)
- Block scope headers: `do -- Section Name` (as part of a `do` block declaration)

**PROHIBITED comments:**
- Explanatory comments describing what code does
- Usage examples in the code itself
- Multi-line documentation blocks within code
- Inline comments explaining behavior or logic
- Comments before or within functions explaining implementation
- Verbose or detailed comments within data structures

**Guidelines for section headers:**
- Keep them SHORT (1-3 words maximum)
- Use only for major sections that span many lines
- Do NOT use for small blocks of code
- Do NOT explain what the section does, just label it

**Examples:**

✅ **Good (permitted):**
```lua
-- French
SAdCore.prototype.locale.frFR = { ... }

do -- Zone Management
    function addon:RegisterZone() ... end
end
```

❌ **Bad (prohibited):**
```lua
-- This merges user-provided locale with default locale
for localeKey, prototypeLocale in pairs(...) do

-- Get the current value from settings
local value = self.settings[key]
```

**Rationale:** Developers will not be reading the framework code directly. Most comments are unnecessary noise that belongs in README.md or other documentation files. Code should be self-explanatory through clear naming and structure. Simple section headers are acceptable ONLY to organize very large sections of code (like localization tables or major functional blocks).

## Rationale

These constraints enable external addons to hook into ANY `addon.*` function's execution for monitoring, modification, or extension purposes. Failure to follow these patterns breaks the extensibility contract of the framework.

The minimal comments philosophy keeps the codebase clean, maintainable, and forces developers to write clear, understandable code rather than relying on comments as a crutch.

# Style Guide

This document outlines the coding standards and requirements for the SAdCore framework.

## Tools and Linting

**LUA Helper by Tencent** is used to apply linting to LUA files. Ensure your code passes linting checks before committing.

## Scope

These constraints apply **ONLY** to `addon.*` functions (functions on the addon table). Local (private) functions are NOT subject to these requirements as they cannot be hooked by external addons.

## Critical Coding Constraints

### 1. Hook Requirement

Every `addon.*` function MUST include:
- `callHook(self, "BeforeFunctionName", ...)` as the first line
- `callHook(self, "AfterFunctionName", returnValue)` before EVERY return statement

### 2. Return Value Requirement

Every `addon.*` function MUST explicitly return a value:
- Success functions typically return `true` or the actual result
- Failed/error conditions MUST return `false` or the actual result (NEVER `nil`)
- NO function should end without an explicit return statement
- NEVER return `nil` - use `false` for failures, `true` for success, or actual data

### 3. Short-Circuit Returns

When returning early (error conditions, validation failures):
- MUST call the After hook with the return value
- MUST explicitly return that value (`false` for errors, never `nil`)

Example:
```lua
if not data then
    callHook(self, "AfterFunctionName", false)
    return false
end
```

### 4. Standard Function Pattern

```lua
function addon:FunctionName(params)
    callHook(self, "BeforeFunctionName", params)
    
    -- Early return example
    if errorCondition then
        callHook(self, "AfterFunctionName", false)
        return false
    end
    
    -- Function logic here
    
    local returnValue = true
    callHook(self, "AfterFunctionName", returnValue)
    return returnValue
end
```

## Localization Requirements

### All User-Facing Messages Must Use Localization

All `info` and `error` messages MUST use localization strings via `self:L()`:

**✅ Correct:**
```lua
self:error(self:L("frameNotFound") .. ": " .. frameName)
self:info(self:L("importSuccess"))
```

**❌ Incorrect:**
```lua
self:error("Frame not found: " .. frameName)
self:info("Import successful")
```

This ensures the framework can be localized for different languages.

### Tagline Translation Guidelines

The framework tagline "Simple Addons—Bare minimum addons for bare minimum brains." must follow specific translation rules:

**Critical Rules:**

1. **"Simple Addons" MUST remain in English** - This is the source of the "SAd" acronym and MUST NOT be translated
2. **Self-deprecating humor** - The tagline is intentionally self-deprecating and humorous in tone
3. **"brains" = intellectual capacity** - When translating "brains", use words that refer to intellectual capacity or mental ability, NOT the physical brain organ

**Translation Pattern:**
```
Simple Addons—[Minimal/bare minimum] [addons/extensions] for [minimal/bare minimum] [minds/intellects].
```

**Examples:**
- Spanish: "Simple Addons—Addons mínimos para mentes mínimas."
- Russian: "Simple Addons—Минимальные аддоны для минимального ума."
- French: "Simple Addons—Addons minimaux pour esprits minimaux."
- German: "Simple Addons—Minimale Addons für minimale Köpfe."

**Note:** "Simple Addons" staying in English preserves brand identity across all languages while the humor translates naturally.

## Code Comments

### Minimal Comments Philosophy

Code should be self-documenting. Comments should be rare and strategic.

### Allowed Comments

**Only the following types of comments are permitted:**

1. **Section Header Comments** - Large sections with `do` scopes:
   ```lua
   do -- Initialization
       -- functions here
   end
   
   do -- Settings Panels
       -- functions here
   end
   ```

2. **File Header Comments** - Copyright, license, and framework description at the top of files

### Prohibited Comments

**Do NOT use comments for:**
- Explaining what code does (write clearer code instead)
- TODO notes (use issue tracking)
- Inline explanations (refactor for clarity)
- Parameter documentation (use clear parameter names)

### Examples

**❌ Bad (over-commented):**
```lua
-- Set the width to 500
local width = 500

-- Loop through all items
for i = 1, #items do
    -- Get the current item
    local item = items[i]
    -- Process the item
    processItem(item)
end
```

**✅ Good (self-documenting):**
```lua
local defaultDialogWidth = 500

for _, item in ipairs(items) do
    processItem(item)
end
```

## Code Clarity

### Write Self-Explanatory Code

Scoped code should be written clearly enough that its purpose is understandable without comments.

**Strategies for self-documenting code:**
- Use descriptive variable names
- Use descriptive function names
- Keep functions small and focused
- Use meaningful constants instead of magic numbers
- Structure code logically

### Affirmative Logic Requirement

**All logic must be written in the affirmative case.** Avoid negative variable names and double negatives in conditionals.

**✅ Correct (affirmative):**
```lua
local visible = frame:IsVisible()
if visible then
    showFrame()
end

local enabled = GetSettingValue("feature")
if enabled then
    activateFeature()
end

local success = ProcessData(data)
if success then
    self:info(self:L("operationSuccess"))
end
```

**❌ Incorrect (negative):**
```lua
local hidden = not frame:IsVisible()
if not hidden then
    showFrame()
end

local disabled = not GetSettingValue("feature")
if not disabled then
    activateFeature()
end

local failed = not ProcessData(data)
if not failed then
    self:info(self:L("operationSuccess"))
end
```

**Rationale:** Double negatives (`if not hidden`, `if not disabled`) are harder to read and reason about. Affirmative logic makes code intention immediately clear and reduces cognitive load when reading conditions.

**Note:** This is a general rule. There are always exceptions. If the code becomes complex or harder to read because of trying to follow this rule, then it might be a valid exception. Use your judgment to prioritize overall code clarity.

### Developer Documentation Location

**Do NOT put developer documentation in code comments.**

Documentation for developers implementing or using SAdCore should go in:
- **README.md** - User guide, getting started, examples
- **API documentation** - Function signatures and usage
- **This style guide** - Coding standards and patterns

The main code should be clean and focused on implementation.

### Comment Policy

**Comments should be minimal and limited to simple section headers.**

**Permitted comments:**
- File header (at the very top of the file only): license, copyright, or brief file description
- Simple section headers for large code blocks: `-- Section Name` (e.g., `-- Russian`, `-- Utility Functions`)
- Block scope headers: `do -- Section Name` (as part of a `do` block declaration)

**PROHIBITED comments:**
- Explanatory comments describing what code does
- Usage examples in the code itself
- Multi-line documentation blocks within code
- Inline comments explaining behavior or logic
- Comments before or within functions explaining implementation
- Verbose or detailed comments within data structures

**Guidelines for section headers:**
- Keep them SHORT (1-3 words maximum)
- Use only for major sections that span many lines
- Do NOT use for small blocks of code
- Do NOT explain what the section does, just label it

**Examples:**

✅ **Good (permitted):**
```lua
-- French
SAdCore.prototype.locale.frFR = { ... }

do -- Zone Management
    function addon:RegisterZone() ... end
end
```

❌ **Bad (prohibited):**
```lua
-- This merges user-provided locale with default locale
for localeKey, prototypeLocale in pairs(...) do

-- Get the current value from settings
local value = self.settings[key]
```

**Rationale:** Developers will not be reading the framework code directly. Most comments are unnecessary noise that belongs in README.md or other documentation files. Code should be self-explanatory through clear naming and structure. Simple section headers are acceptable ONLY to organize very large sections of code (like localization tables or major functional blocks).

## Rationale

These constraints enable external addons to hook into ANY `addon.*` function's execution for monitoring, modification, or extension purposes. Failure to follow these patterns breaks the extensibility contract of the framework.

The minimal comments philosophy keeps the codebase clean, maintainable, and forces developers to write clear, understandable code rather than relying on comments as a crutch.
