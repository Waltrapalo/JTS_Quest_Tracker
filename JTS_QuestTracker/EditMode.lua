local JQT = JTS_QuestTracker;
local spanish = GetLocale():sub(1, 2) == "es";
local name = spanish and "Misiones (JTS)" or "Quests (JTS)";
local hint = spanish and "Arrastra para guardar la posición en el perfil de JTS."
    or "Drag to save the position in your JTS profile.";

local handle;
local dragProfile;

local function anchorHandle()
    local tracker = JQT.tracker;
    local point = tracker:IsGrowingUp() and "BOTTOMRIGHT" or "TOPRIGHT";
    handle:ClearAllPoints();
    handle:SetPoint(point, tracker, point);
    handle:SetSize(tracker:GetWidth(), math.max(30, tracker:GetHeight()));
end

local function createHandle()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate");
    frame:SetFrameStrata("DIALOG");
    frame:SetMovable(true);
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    });
    frame:SetBackdropColor(0.10, 0.37, 0.58, 0.28);
    frame:SetBackdropBorderColor(0.42, 0.78, 1, 1);

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    label:SetPoint("CENTER");
    label:SetText(name);

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT");
        GameTooltip:AddLine(name);
        GameTooltip:AddLine(hint, 1, 1, 1, true);
        GameTooltip:Show();
    end);
    frame:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end);
    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        dragProfile = JQT.db:GetCurrentProfile();
        self:StartMoving();
    end);
    frame:SetScript("OnDragStop", function(self)
        if not dragProfile then return end
        self:StopMovingOrSizing();
        self:SetUserPlaced(false);

        local tracker = JQT.tracker;
        if dragProfile == JQT.db:GetCurrentProfile() and not InCombatLockdown() then
            local x = self:GetRight() - UIParent:GetRight();
            local y = (tracker:IsGrowingUp() and self:GetBottom() or self:GetTop()) - UIParent:GetTop();
            tracker:SetPosition(x, y);
            JQT.db.profile.PositionX, JQT.db.profile.PositionY = tracker:GetPosition();
        end
        dragProfile = nil;
        anchorHandle();
    end);
    frame:SetScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        if not dragProfile then return end
        dragProfile = nil;
        self:StopMovingOrSizing();
        self:SetUserPlaced(false);
    end);
    return frame;
end

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if not JQT.tracker or InCombatLockdown() then return end
        if not handle then handle = createHandle() end
        anchorHandle();
        handle:Show();
    end, JQT);
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if handle then handle:Hide() end
    end, JQT);
end
