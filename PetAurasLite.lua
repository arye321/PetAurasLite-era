-- ===========================
-- PetAurasLite Main
-- ===========================
local ADDON_NAME           = "PetAurasLite"

local ICON_SIZE            = 15
local ICON_SPACING         = 4
local CONTAINER_PADDING    = 4
local PLACEHOLDER_ALPHA    = 1
local CLICK_BG_ALPHA       = 0.35

-- ===========================
-- SavedVariables defaults
-- ===========================
PetAurasLiteDB             = PetAurasLiteDB or {}
PetAurasLiteDB.buffCount   = PetAurasLiteDB.buffCount or 5
PetAurasLiteDB.debuffCount = PetAurasLiteDB.debuffCount or 5
PetAurasLiteDB.locked      = PetAurasLiteDB.locked or false -- unlocked by default

-- ===========================
-- Helper: Create Aura Bar
-- ===========================
local function CreateAuraBar(name, anchorFrame, yOffset, numIcons)
    local barWidth  = ICON_SIZE * numIcons + ICON_SPACING * (numIcons + 1)
    local barHeight = ICON_SIZE + CONTAINER_PADDING * 2

    local bar       = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    bar:SetSize(barWidth, barHeight)

    if anchorFrame then
        bar:SetPoint("TOP", anchorFrame, "BOTTOM", 0, yOffset)
    else
        bar:SetPoint("CENTER")
    end

    bar.numIcons = numIcons
    bar.isDragging = false

    bar:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    bar:SetBackdropColor(0, 0, 0, 0)
    bar:SetBackdropBorderColor(0, 0, 0, 0)

    bar:SetMovable(true)
    bar:EnableMouse(false) -- click-through by default
    bar:RegisterForDrag("LeftButton")
    bar:SetFrameStrata("MEDIUM")

    -- ===========================
    -- Dragging (bar)
    -- ===========================
    bar:SetScript("OnDragStart", function(self)
        if PetAurasLiteDB.locked then return end
        self.isDragging = true
        self:EnableMouse(true)
        self:SetBackdropColor(0.1, 0.1, 0.1, CLICK_BG_ALPHA)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        self:StartMoving()
        -- enable all icons while dragging
        for _, icon in ipairs(self.icons) do
            icon:EnableMouse(true)
        end
    end)

    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false
        self:EnableMouse(false)
        self:SetBackdropColor(0, 0, 0, 0)
        self:SetBackdropBorderColor(0, 0, 0, 0)
        -- reset icon mouse based on whether they have an aura
        for i, icon in ipairs(self.icons) do
            if i == 1 then
                icon:EnableMouse(true) -- Slot 1 always draggable
            else
                icon:EnableMouse(icon.texture:IsShown())
            end
        end
    end)

    bar.icons = {}

    -- ===========================
    -- Icons
    -- ===========================
    for i = 1, numIcons do
        local icon = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", bar, "LEFT", CONTAINER_PADDING + (i - 1) * (ICON_SIZE + ICON_SPACING), 0)
        -- set icon color blue

        -- Slot 1 is always mouse-enabled
        if i == 1 then
            icon:EnableMouse(true)
        else
            icon:EnableMouse(false)
        end

        -- Placeholder
        icon.placeholder = icon:CreateTexture(nil, "BACKGROUND")
        icon.placeholder:SetAllPoints()
        icon.placeholder:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.placeholder:SetVertexColor(1, 1, 1, 0)
        icon.placeholder:SetShown(i == 1)
        -- Icon texture
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:Hide()

        -- Cooldown
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetDrawEdge(false)
        icon.cooldown:SetDrawBling(false)
        icon.cooldown:SetHideCountdownNumbers(true)
        icon.cooldown:Hide()

        -- Tooltip
        icon:SetScript("OnEnter", function(self)
            icon.placeholder:SetVertexColor(1, 1, 1, PLACEHOLDER_ALPHA)

            if self.unit and self.index then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.isDebuff then
                    GameTooltip:SetUnitDebuff(self.unit, self.index)
                else
                    GameTooltip:SetUnitBuff(self.unit, self.index)
                end
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            icon.placeholder:SetVertexColor(1, 1, 1, 0)
        end)

        -- Dragging from icon
        icon:RegisterForDrag("LeftButton")
        icon:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and not PetAurasLiteDB.locked then
                local parent = self:GetParent()
                parent.isDragging = true
                parent:EnableMouse(true)
                parent:SetBackdropColor(0.1, 0.1, 0.1, CLICK_BG_ALPHA)
                parent:SetBackdropBorderColor(0, 0, 0, 1)
                parent:StartMoving()
                -- enable all icons during drag
                for _, ic in ipairs(parent.icons) do
                    ic:EnableMouse(true)
                end
            end
        end)

        icon:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                local parent = self:GetParent()
                parent:StopMovingOrSizing()
                parent.isDragging = false
                parent:EnableMouse(false)
                parent:SetBackdropColor(0, 0, 0, 0)
                parent:SetBackdropBorderColor(0, 0, 0, 0)
                -- reset icon mouse based on whether they have an aura
                for i, ic in ipairs(parent.icons) do
                    if i == 1 then
                        ic:EnableMouse(true) -- Slot 1 always draggable
                    else
                        ic:EnableMouse(ic.texture:IsShown())
                    end
                end
            end
        end)

        bar.icons[i] = icon
    end

    return bar
end

-- ===========================
-- Create Bars
-- ===========================
debuffBar = CreateAuraBar(ADDON_NAME .. "DebuffBar", buffBar, -6, 10)

-- ===========================
-- Update Aura Bar
-- ===========================
function UpdateAuraBar(bar, unit, isDebuff)
    if not UnitExists(unit) then return end

    local iconSlot = 1
    local index = 1

    -- Reset icons
    for i, icon in ipairs(bar.icons) do
        icon.texture:Hide()
        icon.cooldown:Hide()
        icon.unit = nil
        icon.index = nil
        icon.isDebuff = nil
        icon.placeholder:SetShown(i == 1)
        -- Slot 1 always mouse-enabled
        if i == 1 then
            icon:EnableMouse(true)
        else
            -- mouse pass-through if idle and not dragging
            if not bar.isDragging then
                icon:EnableMouse(false)
            end
        end
    end

    -- Assign auras
    while iconSlot <= bar.numIcons do
        local name, texture, _, _, duration, expirationTime

        if isDebuff then
            name, texture, _, _, duration, expirationTime = UnitDebuff(unit, index)
        else
            name, texture, _, _, duration, expirationTime = UnitBuff(unit, index)
        end

        if not name then break end

        local icon = bar.icons[iconSlot]
        icon.texture:SetTexture(texture)
        icon.texture:Show()
        icon.placeholder:Hide()
        icon.unit = unit
        icon.index = index
        icon.isDebuff = isDebuff

        -- Enable mouse for active aura or dragging
        icon:EnableMouse(true)

        if duration and duration > 0 and expirationTime then
            icon.cooldown:SetReverse(true)
            CooldownFrame_Set(icon.cooldown, expirationTime - duration, duration, true)
            icon.cooldown:Show()
        end

        index = index + 1
        iconSlot = iconSlot + 1
    end
end

-- ===========================
-- Count setters
-- ===========================
function SetBuffCount(count)
    PetAurasLiteDB.buffCount = count
    buffBar.numIcons = count
    for i, icon in ipairs(buffBar.icons) do
        icon:SetShown(i <= count)
    end
    UpdateAuraBar(buffBar, "pet", false)
end

function SetDebuffCount(count)
    PetAurasLiteDB.debuffCount = count
    debuffBar.numIcons = count
    for i, icon in ipairs(debuffBar.icons) do
        icon:SetShown(i <= count)
    end
    UpdateAuraBar(debuffBar, "pet", true)
end

-- ===========================
-- Events
-- ===========================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN"
        or (event == "UNIT_PET" and arg1 == "player")
        or (event == "UNIT_AURA" and arg1 == "pet") then
        UpdateAuraBar(debuffBar, "pet", true)
    end
end)

-- ===========================
-- Slash Command
-- ===========================
SLASH_PETAURASLITE1 = "/petauras"
SlashCmdList["PETAURASLITE"] = function()
    -- if PetAurasLiteOptions then
    --     PetAurasLiteOptions:SetShown(not PetAurasLiteOptions:IsShown())
    -- end
    debuffBar.icons[1].placeholder:SetVertexColor(1, 1, 1, 1)
end

-- ===========================
-- Loaded Message
-- ===========================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function()
    print("|cff00ff00PetAurasLite loaded!|r Buffs: " ..
        PetAurasLiteDB.buffCount .. ", Debuffs: " .. PetAurasLiteDB.debuffCount)
    print("|cff00ff00Type |r/petauras |cff00ff00to open settings.|r")
end)
