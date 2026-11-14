local JQT = JTS_QuestTracker;
local QuestLog = LibStub("JTSQTQuestLogHelper-1.0");
local Compat = LibStub("JTSQTCompat-1.0");

local label = GetLocale():sub(1, 2) == "es" and "Entregadas hoy" or "Turned in today";
local sectionKey = "TURNED_IN_TODAY";
local midnightTimer;

local function today()
    return date("%Y-%m-%d");
end

local function history(character)
    local day = today();
    local saved = character.TurnedInToday;
    if not saved or saved.day ~= day then
        saved = { day = day, entries = {} };
        character.TurnedInToday = saved;
    end
    return saved.entries;
end

local function refreshAtMidnight()
    if midnightTimer then return end

    local midnight = date("*t");
    midnight.day = midnight.day + 1;
    midnight.hour, midnight.min, midnight.sec, midnight.isdst = 0, 0, 0, nil;
    midnightTimer = C_Timer.NewTimer(math.max(1, time(midnight) - time() + 1), function()
        midnightTimer = nil;
        if JQT.tracker then JQT:RefreshView() end
    end);
end

function JQT:AddTurnedInToday(parent)
    local character = self.db.char;
    local entries = history(character);
    if #entries == 0 then return end

    refreshAtMidnight();

    local profile = self.db.profile;
    local tracker = self.tracker;
    local section = tracker:Container({ container = parent, metadata = {} });
    section:SetOrder(math.huge, false);

    local rows;
    local header = tracker:Container({
        container = section,
        margin = { top = 8, bottom = 5, left = 2 },
        events = {
            OnMouseUp = function(button)
                if button == "LeftButton" then
                    character.CollapsedSections[sectionKey] = rows:ToggleHidden() or nil;
                end
            end
        }
    });

    tracker:Font({
        container = header,
        label = ("%s (%d)"):format(label, #entries),
        color = profile.ZoneHeaderFontColor,
        size = profile.ZoneHeaderFontSize
    });

    rows = tracker:Container({
        container = section,
        hidden = character.CollapsedSections[sectionKey],
        margin = { left = 8 }
    });

    for index = #entries, 1, -1 do
        local entry = entries[index];
        tracker:Font({
            container = rows,
            label = ("%s  %s"):format(date("%H:%M", entry.at), entry.title),
            color = profile.ObjectiveFontColor,
            size = profile.ObjectiveFontSize,
            margin = { bottom = 4 }
        });
    end
end

JQT:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
    if not JQT.db or type(questID) ~= "number" or questID <= 0 then return end

    local quest = QuestLog:GetQuest(questID);
    local title = quest and quest.title;
    if not title or title == "" then
        title = Compat:GetQuestTitle(questID);
    end

    local entries = history(JQT.db.char);
    entries[#entries + 1] = {
        title = title and title ~= "" and title or ("#%d"):format(questID),
        at = time()
    };
    if JQT.tracker then JQT:RefreshView() end
end);
