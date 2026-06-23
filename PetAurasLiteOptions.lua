-- ===========================
-- PetAurasLite Options Frame
-- ===========================
PetAurasLiteOptions = CreateFrame("Frame", "PetAurasLiteOptionsFrame", UIParent, "BackdropTemplate")
PetAurasLiteOptions:SetSize(420, 300) -- increased height for bottom padding
PetAurasLiteOptions:SetPoint("CENTER")
PetAurasLiteOptions:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
})
PetAurasLiteOptions:SetBackdropColor(0, 0, 0, 1)
PetAurasLiteOptions:Hide()

PetAurasLiteOptions:SetMovable(true)
PetAurasLiteOptions:EnableMouse(true)
PetAurasLiteOptions:RegisterForDrag("LeftButton")
PetAurasLiteOptions:SetScript("OnDragStart", function(self) self:StartMoving() end)
PetAurasLiteOptions:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Close button
local closeBtn = CreateFrame("Button", nil, PetAurasLiteOptions, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

-- Title
local title = PetAurasLiteOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("PetAurasLite Settings")

-- ===========================
-- Helpers
-- ===========================
local function CreateHeader(text, yOffset)
    local header = PetAurasLiteOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    return header
end

local function CreateCheckbox(label, x, y, onClick)
    local cb = CreateFrame("CheckButton", nil, PetAurasLiteOptions, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.text:SetText(label)
    cb:SetScript("OnClick", onClick)
    return cb
end

-- ===========================
-- Lock Bars Checkbox
-- ===========================
CreateHeader("General", -50)

local lockBarsCheckbox = CreateCheckbox("Lock Buff & Debuff Bars", 40, -80, function(self)
    PetAurasLiteDB.locked = self:GetChecked()
end)

-- Function to sync checkbox with saved variable
local function UpdateLockCheckbox()
    if lockBarsCheckbox then
        lockBarsCheckbox:SetChecked(PetAurasLiteDB.locked)
    end
end

-- Sync on login
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    -- ensure the DB has defaults
    PetAurasLiteDB             = PetAurasLiteDB or {}
    PetAurasLiteDB.buffCount   = PetAurasLiteDB.buffCount or 5
    PetAurasLiteDB.debuffCount = PetAurasLiteDB.debuffCount or 5
    PetAurasLiteDB.locked      = PetAurasLiteDB.locked or false

    UpdateLockCheckbox()
end)

-- ===========================
-- Buff Icons
-- ===========================
local presetValues = { 3, 5, 8, 10 }

CreateHeader("Buff Icons", -120)
local buffCheckboxes = {}

for i, count in ipairs(presetValues) do
    buffCheckboxes[i] = CreateCheckbox(
        count .. " Slots",
        40 + (i - 1) * 80,
        -150,
        function(self)
            for _, cb in ipairs(buffCheckboxes) do
                if cb ~= self then cb:SetChecked(false) end
            end
            SetBuffCount(count)
            self:SetChecked(true)
        end
    )

    if PetAurasLiteDB.buffCount == count then
        buffCheckboxes[i]:SetChecked(true)
    end
end

-- ===========================
-- Debuff Icons
-- ===========================
CreateHeader("Debuff Icons", -200)
local debuffCheckboxes = {}

for i, count in ipairs(presetValues) do
    debuffCheckboxes[i] = CreateCheckbox(
        count .. " Slots",
        40 + (i - 1) * 80,
        -230,
        function(self)
            for _, cb in ipairs(debuffCheckboxes) do
                if cb ~= self then cb:SetChecked(false) end
            end
            SetDebuffCount(count)
            self:SetChecked(true)
        end
    )

    if PetAurasLiteDB.debuffCount == count then
        debuffCheckboxes[i]:SetChecked(true)
    end
end
