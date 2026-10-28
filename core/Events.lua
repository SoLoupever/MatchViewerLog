local addonName, ns = ...

-- ====================================================
-- EVENTS — bus interne (ns.On / ns.Fire) et facade unique
-- pour les events WoW (ns.RegisterWowEvent). Un seul frame
-- d'ecoute : pas de CreateFrame:RegisterEvent eparpilles.
-- Les erreurs d'un abonne sont isolees (pcall) pour ne pas
-- casser les autres — anti effet domino.
-- ====================================================

local bus = {}

function ns.On(evt, fn)
    bus[evt] = bus[evt] or {}
    table.insert(bus[evt], fn)
end

function ns.Fire(evt, ...)
    local list = bus[evt]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then ns.Debug("event error", evt, err) end
    end
end

-- Etat de la fenetre : les handlers "visibleOnly" ne tournent que ouverte
-- (les refresh se refont deja a MVL_FRAME_SHOW).
local shown = false
ns.On("MVL_FRAME_SHOW", function() shown = true end)
ns.On("MVL_FRAME_HIDE", function() shown = false end)
function ns.IsFrameShown() return shown end

-- Facade events WoW. visibleOnly : ignore l'event tant que la fenetre est fermee.
local wowFrame    = CreateFrame("Frame")
local wowHandlers = {}

local function Dispatch(evt, ...)
    local list = wowHandlers[evt]
    if not list then return end
    for i = 1, #list do
        local h = list[i]
        if shown or not h.visibleOnly then
            local ok, err = pcall(h.fn, ...)
            if not ok then ns.Debug("wow event error", evt, err) end
        end
    end
end

function ns.RegisterWowEvent(evt, fn, visibleOnly)
    if not wowHandlers[evt] then
        wowHandlers[evt] = {}
        pcall(wowFrame.RegisterEvent, wowFrame, evt)
    end
    table.insert(wowHandlers[evt], { fn = fn, visibleOnly = visibleOnly })
end

wowFrame:SetScript("OnEvent", function(_, evt, ...) Dispatch(evt, ...) end)

-- Event filtre sur une unite (RegisterUnitEvent) : evite de recevoir
-- UNIT_AURA & co pour toutes les unites. Frame dediee : un RegisterEvent
-- sur le meme frame annulerait le filtre.
local unitFrame = CreateFrame("Frame")
unitFrame:SetScript("OnEvent", function(_, evt, ...) Dispatch(evt, ...) end)

function ns.RegisterWowUnitEvent(evt, unit, fn, visibleOnly)
    if not wowHandlers[evt] then
        wowHandlers[evt] = {}
        pcall(unitFrame.RegisterUnitEvent, unitFrame, evt, unit)
    end
    table.insert(wowHandlers[evt], { fn = fn, visibleOnly = visibleOnly })
end
