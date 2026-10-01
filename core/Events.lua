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

-- Facade events WoW.
local wowFrame    = CreateFrame("Frame")
local wowHandlers = {}

function ns.RegisterWowEvent(evt, fn)
    if not wowHandlers[evt] then
        wowHandlers[evt] = {}
        pcall(wowFrame.RegisterEvent, wowFrame, evt)
    end
    table.insert(wowHandlers[evt], fn)
end

wowFrame:SetScript("OnEvent", function(_, evt, ...)
    local list = wowHandlers[evt]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then ns.Debug("wow event error", evt, err) end
    end
end)
