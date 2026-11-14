local JQT = JTS_QuestTracker;
local spanish = GetLocale():sub(1, 2) == "es";
local name = spanish and "Misiones (JTS)" or "Quests (JTS)";
local hint = spanish and "Arrastra el panel para moverlo o usa el tirador de la esquina para cambiar su tamaño."
    or "Drag the panel to move it or use the corner grip to resize it.";
local resizeHint = spanish and "Arrastra para ajustar el ancho y la altura máxima."
    or "Drag to adjust the width and maximum height.";

local handle;
local dragProfile;
local resize;
local pressedX, pressedY;

local function cursor()
    local x, y = GetCursorPosition();
    local scale = UIParent:GetEffectiveScale();
    return x / scale, y / scale;
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value));
end

local function heightLimit(tracker)
    local available = tracker:IsGrowingUp() and (UIParent:GetTop() - tracker:GetBottom())
        or (tracker:GetTop() - UIParent:GetBottom());
    return math.max(100, math.floor(available));
end

local function anchorHandle()
    local tracker = JQT.tracker;
    local point = tracker:IsGrowingUp() and "BOTTOMRIGHT" or "TOPRIGHT";
    handle:ClearAllPoints();
    handle:SetPoint(point, tracker, point);
    handle:SetSize(tracker:GetWidth(), math.min(JQT.db.profile.MaxHeight, heightLimit(tracker)));
    handle.grip:ClearAllPoints();
    local corner = tracker:IsGrowingUp() and "TOPLEFT" or "BOTTOMLEFT";
    handle.grip:SetPoint(corner, handle, corner, 2, tracker:IsGrowingUp() and -2 or 2);
end

local function previewResize()
    local x, y = cursor();
    local dx, dy = resize.x - x, resize.growUp and (y - resize.y) or (resize.y - y);
    resize.width = dx == 0 and resize.widthBefore
        or clamp(math.floor(resize.widthBefore + dx + 0.5), 100, resize.widthLimit);
    resize.height = dy == 0 and resize.heightBefore
        or clamp(math.floor(resize.previewHeight + dy + 0.5), 100, resize.heightLimit);
    handle:SetSize(resize.width, dy == 0 and resize.previewHeight or resize.height);
end

local function stopResize(grip, save)
    grip:SetScript("OnUpdate", nil);
    if not resize then return end

    if save and not InCombatLockdown() and resize.profile == JQT.db:GetCurrentProfile() then
        previewResize();
        local profile = JQT.db.profile;
        profile.Width, profile.MaxHeight = resize.width, resize.height;
        JQT.tracker:UpdateSettings({
            width = profile.Width, maxHeight = profile.MaxHeight,
        });
        JQT:RefreshView();
    end
    resize = nil;
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

    local grip = CreateFrame("Frame", nil, frame, "BackdropTemplate");
    frame.grip = grip;
    grip:SetSize(24, 24);
    grip:EnableMouse(true);
    grip:RegisterForDrag("LeftButton");
    grip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" });
    grip:SetBackdropColor(0.10, 0.37, 0.58, 1);
    local gripLabel = grip:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    gripLabel:SetPoint("CENTER");
    gripLabel:SetText("+");
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then pressedX, pressedY = cursor() end
    end);
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT");
        GameTooltip:AddLine(resizeHint, 1, 1, 1, true);
        GameTooltip:Show();
    end);
    grip:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end);
    grip:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        local tracker = JQT.tracker;
        local growUp = tracker:IsGrowingUp();
        resize = {
            x = pressedX, y = pressedY, growUp = growUp, profile = JQT.db:GetCurrentProfile(),
            widthBefore = tracker:GetWidth(), heightBefore = JQT.db.profile.MaxHeight,
            previewHeight = frame:GetHeight(),
            widthLimit = math.max(100, math.min(400, math.floor(tracker:GetRight() - UIParent:GetLeft()))),
            heightLimit = heightLimit(tracker),
        };
        self:SetScript("OnUpdate", previewResize);
    end);
    grip:SetScript("OnDragStop", function(self)
        stopResize(self, true);
        anchorHandle();
    end);

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
        if GameTooltip:IsOwned(grip) then GameTooltip:Hide() end
        stopResize(grip, false);
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
