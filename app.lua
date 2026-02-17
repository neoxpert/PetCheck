if select(2, UnitClass("player")) ~= "HUNTER" then
    return;
end

PetStatus = PetStatus or {}

PetListener = setmetatable({}, { __index = EventListener })
PetListener.__index = PetListener

function PetListener:new()
    local instance = EventListener.new(self)

    local textFrame = CreateFrame("Frame", nil, UIParent)
    textFrame:SetSize(400, 80)
    textFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    textFrame:SetClampedToScreen(true)
    textFrame:Hide()

    instance.textFrame = textFrame

    local text = textFrame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 48, "THICKOUTLINE")
    text:SetPoint("CENTER")

    instance.text = text

    instance:makeFrameMovable()

    instance:registerEvents()

    return instance
end

function PetListener:makeFrameMovable()
    local textFrame = self.textFrame

    textFrame:SetMovable(true)
    textFrame:EnableMouse(true)
    textFrame:RegisterForDrag("LeftButton")

    textFrame:SetScript("OnDragStart", function(f)
        if IsShiftKeyDown() then
            f:StartMoving()
        end
    end)

    textFrame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()

        local point, _, relPoint, x, y = f:GetPoint()
        PetStatus.point = point
        PetStatus.relPoint = relPoint
        PetStatus.x = x
        PetStatus.y = y
    end)
end

function PetListener:initialize()
    if PetStatus.petWasDead == nil then
        PetStatus.petWasDead = false
    end

    if PetStatus.onlyInInstance == nil then
        PetStatus.onlyInInstance = true
    end

    local point = PetStatus.point or "CENTER"
    local relPoint = PetStatus.relPoint or "CENTER"
    local x = PetStatus.x or 0
    local y = PetStatus.y or 150

    self.textFrame:ClearAllPoints()
    self.textFrame:SetPoint(
        point,
        UIParent,
        relPoint,
        x,
        y
    )

    self:setBlink(PetStatus.blink or false)

    self:updatePetStatus()
end

function PetListener:setupBlinkAnimation()
    if (self.blinkAnimation) then return end

    local tempAnimation = self.textFrame:CreateAnimationGroup()
    tempAnimation:SetLooping("REPEAT")

    local fadeOut = tempAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.5)
    fadeOut:SetDuration(1)
    fadeOut:SetOrder(1)

    local fadeIn = tempAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.5)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(1)
    fadeIn:SetOrder(2)

    self.blinkAnimation = tempAnimation
end

function PetListener:setBlink(opt)
    local toggle

    if opt == nil then
        if PetStatus.blink == nil then
            toggle = true
        else
            toggle = not PetStatus.blink
        end
    else
        if type(opt) == "string" then
            toggle = opt == "true"
        else
            toggle = opt
        end
    end

    PetStatus.blink = toggle

    if toggle then
        self:setupBlinkAnimation()

        if not self.blinkAnimation:IsPlaying() then
            self.blinkAnimation:Play()
        end
    else
        if self.blinkAnimation then
            self.blinkAnimation:Stop()
        end

        self.textFrame:SetAlpha(1) -- wichtig!
    end
end

function PetListener:reset()
    PetStatus.point = "CENTER"
    PetStatus.relPoint = "CENTER"
    PetStatus.x = 0
    PetStatus.y = 150
    PetStatus.blink = false

    self.textFrame:ClearAllPoints()
    self.textFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    self:setBlink(false)
end

function PetListener:registerEvents()
    local me = self;

    self:on("PLAYER_ENTERING_WORLD", function(...)
        me:initialize()
    end)

    self:on("ZONE_CHANGED_NEW_AREA", function(...)
        me:updatePetStatus()
    end)

    self:on("UNIT_PET", function(f, _, unit)
        if unit == "player" then
            me:updatePetStatus()
        end
    end)

    self:on("UNIT_HEALTH", function(f, _, unit)
        if unit == "pet" then
            me:updatePetStatus()
        end
    end)
end

function PetListener:updatePetStatus()
    local textFrame = self.textFrame
    local text = self.text

    local inInstance, instanceType = IsInInstance()

    if PetStatus.onlyInInstance and not inInstance then
        textFrame:Hide()
        return
    end

    -- Pet exists and not dead? Reset the store variable, hide the text.
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
        PetStatus.petWasDead = false
        textFrame:Hide()
        return
    end

    -- get the latest state. dead is more important than inactive.
    local wasDead = PetStatus.petWasDead

    if wasDead or UnitIsDeadOrGhost("pet") then
        -- Save it for later checks after reload, zone change etc.
        PetStatus.petWasDead = true

        text:SetText("Your pet is dead!")
        text:SetTextColor(1, 0.4, 0.4)
        textFrame:Show()
    elseif not UnitExists("pet") then
        text:SetText("No active pet!")
        text:SetTextColor(1, 0.2, 0.2)
        textFrame:Show()
    else
        textFrame:Hide()
    end
end

local petlistener = PetListener:new()

SLASH_PETCHECK1 = "/petcheck"

SlashCmdList["PETCHECK"] = function(msg)
    local args = {}

    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end

    if args[1] and args[1] == "reset" then
        petlistener:reset()
    end

    if args[1] and args[1] == "blink" then
        petlistener:setBlink(args[2])
    end
end

local category = Settings.RegisterVerticalLayoutCategory("PetCheck")

local function OnSettingChanged(setting, value)
    if setting:GetVariable() == "PetStatus_Blink_Toggle" then
        petlistener:setBlink(value)
    end

    if setting:GetVariable() == "PetStatus_InInstance_Toggle" then
        petlistener:updatePetStatus()
    end
end

do
    local name = "Blinking Text"
    local variable = "PetStatus_Blink_Toggle"
    local defaultValue = false

    local function GetValue()
        return PetStatus.blink or defaultValue
    end

    local function SetValue(value)
        PetStatus.blink = value
    end

    local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue,
        SetValue)
    setting:SetValueChangedCallback(OnSettingChanged)

    local tooltip = "Activates blinking text."
    Settings.CreateCheckbox(category, setting, tooltip)
end

do
    local name = "Only in instance"
    local variable = "PetStatus_InInstance_Toggle"
    local defaultValue = false

    local function GetValue()
        return PetStatus.onlyInInstance or defaultValue
    end

    local function SetValue(value)
        PetStatus.onlyInInstance = value
    end

    local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue,
        SetValue)
    setting:SetValueChangedCallback(OnSettingChanged)

    local tooltip = "Only show when in instance."
    Settings.CreateCheckbox(category, setting, tooltip)
end

Settings.RegisterAddOnCategory(category)
