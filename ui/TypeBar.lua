local addonName, ns = ...

-- ====================================================
-- TYPEBAR — barre Type / Fort vs / Faible vs + 10 types, en haut
-- de la colonne gauche (sous la recherche). Pilote le filtre natif
-- C_PetJournal et diffuse ROSTER_REFRESH pour que LeftPanel
-- reconstruise la liste.
-- ====================================================

ns.RegisterModule("TypeBar", {})

local bar, typeBtns, tabBtns, levelBtns, dupeBtn = nil, {}, {}, {}, nil
local state = { mode = "type", type = nil }
local accent = { 0.30, 0.55, 0.90 }

-- Filtre de niveau partage avec LeftPanel : nil | "max" (25) | "notmax".
ns.LevelFilter = ns.LevelFilter or nil
-- Filtre "doublons" (independant) : true = uniquement les especes possedees > 1 fois.
ns.DupeFilter = ns.DupeFilter or nil

local function TypeIcon(t)
    -- GetPetTypeTexture renvoie l'icone unique (celle de la liste Blizzard).
    -- On evite Interface\PetBattles\PetIcon-* qui est un sprite a 2 images.
    if GetPetTypeTexture then return GetPetTypeTexture(t) end
    if PET_TYPE_SUFFIX and PET_TYPE_SUFFIX[t] then
        return "Interface\\PetBattles\\PetIcon-" .. PET_TYPE_SUFFIX[t]
    end
end
local function TypeName(t) return _G["BATTLE_PET_NAME_" .. t] or tostring(t) end

local function ResolveTarget()
    if state.mode == "strong" then return ns.STRONG_AGAINST[state.type] end
    if state.mode == "tough"  then return ns.TOUGH_AGAINST[state.type]  end
    return state.type
end

local function ApplyFilter()
    if not C_PetJournal.SetPetTypeFilter then return end
    if not state.type then
        C_PetJournal.SetAllPetTypesChecked(true)
    else
        local target = ResolveTarget()
        C_PetJournal.SetAllPetTypesChecked(false)
        if target then C_PetJournal.SetPetTypeFilter(target, true) end
    end
    ns.Fire("ROSTER_REFRESH")
end

local function UpdateVisuals()
    for mode, b in pairs(tabBtns) do
        local on = (mode == state.mode)
        b.bg:SetColorTexture(on and accent[1] or 0.12, on and accent[2] or 0.12, on and accent[3] or 0.14, on and 0.55 or 0.9)
        b.text:SetTextColor(on and 1 or 0.7, on and 1 or 0.7, on and 1 or 0.72)
    end
    for i, b in ipairs(typeBtns) do
        local on = (state.type == i)
        -- Contour jaune si selectionne, invisible sinon (l'icone reste visible).
        b:SetBackdropBorderColor(on and 1 or 0, on and 0.82 or 0, 0, on and 1 or 0)
    end
    for _, b in pairs(levelBtns) do
        local on = (ns.LevelFilter == b.kind)
        b:SetBackdropBorderColor(on and 1 or 0, on and 0.82 or 0, 0, on and 1 or 0)
    end
    if dupeBtn then
        local on = ns.DupeFilter and true or false
        dupeBtn:SetBackdropBorderColor(on and 1 or 0, on and 0.82 or 0, 0, on and 1 or 0)
    end
end

local function MakeTab(mode, label, x, w)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(w, 18)
    b:SetPoint("TOPLEFT", x, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER"); b.text:SetText(label)
    b:SetScript("OnClick", function()
        state.mode = mode; UpdateVisuals()
        if state.type then ApplyFilter() end
    end)
    tabBtns[mode] = b
end

local function MakeType(petType, x, size)
    local b = CreateFrame("Button", nil, bar, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetPoint("TOPLEFT", x, -22)
    -- Plaque sombre + contour (jaune quand selectionne, via UpdateVisuals).
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, 0.45)
    b:SetBackdropBorderColor(0, 0, 0, 0)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture(TypeIcon(petType))
    -- L'icone nette est une sous-region de l'atlas PetIcon-* (memes
    -- TexCoords que la carte de mascotte Blizzard, quel que soit le type).
    icon:SetTexCoord(0.796875, 0.4921875, 0.50390625, 0.65625)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnClick", function()
        -- Toggle explicite : "cond and nil or x" ne peut jamais renvoyer nil.
        if state.type == petType then state.type = nil else state.type = petType end
        UpdateVisuals(); ApplyFilter()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(TypeName(petType), 1, 1, 1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    typeBtns[petType] = b
end

-- Bouton de filtre de niveau : meme style que les types, mais un chiffre
-- au centre. kind = "max" (25) ou "notmax" (1). Combinable avec un type.
local function MakeLevel(kind, label, tip, x, size)
    local b = CreateFrame("Button", nil, bar, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetPoint("TOPLEFT", x, -22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, 0.45)
    b:SetBackdropBorderColor(0, 0, 0, 0)
    b.kind = kind
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("CENTER"); t:SetText(label); t:SetTextColor(1, 0.82, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnClick", function()
        if ns.LevelFilter == kind then ns.LevelFilter = nil else ns.LevelFilter = kind end
        UpdateVisuals(); ns.Fire("ROSTER_REFRESH")
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(tip, 1, 1, 1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    levelBtns[kind] = b
end

-- Bouton filtre "doublons" : meme plaque que les types, mais une icone fixe.
-- Toggle independant (ns.DupeFilter), combinable avec type + filtre de niveau.
local function MakeDupe(x, size)
    local b = CreateFrame("Button", nil, bar, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetPoint("TOPLEFT", x, -22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, 0.45)
    b:SetBackdropBorderColor(0, 0, 0, 0)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture(132599)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnClick", function()
        ns.DupeFilter = (not ns.DupeFilter) or nil
        UpdateVisuals(); ns.Fire("ROSTER_REFRESH")
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(ns.L("FILTER_DUPES"), 1, 1, 1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dupeBtn = b
end

local function Build()
    if bar then return end
    local left = ns.Frame and ns.Frame.left
    if not left then return end

    bar = CreateFrame("Frame", nil, left)
    bar:SetPoint("TOPLEFT", 6, -34)
    bar:SetPoint("TOPRIGHT", -6, -34)
    bar:SetHeight(48)

    local W = math.floor(left:GetWidth()) - 12
    if W < 180 then W = 266 end
    local gearW, gap = 18, 3
    local tabW = math.floor((W - gearW - 4 - 4) / 3)
    MakeTab("type",   ns.L("TAB_TYPE"),   0,              tabW)
    MakeTab("strong", ns.L("TAB_STRONG"), tabW + 2,       tabW)
    MakeTab("tough",  ns.L("TAB_TOUGH"),  (tabW + 2) * 2, tabW)

    local gear = CreateFrame("Button", nil, bar)
    gear:SetSize(gearW, gearW); gear:SetPoint("TOPRIGHT", 0, 0)
    local g = gear:CreateTexture(nil, "ARTWORK"); g:SetAllPoints()
    g:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function()
        state.type = nil; ns.LevelFilter = nil; ns.DupeFilter = nil
        C_PetJournal.SetAllPetTypesChecked(true); UpdateVisuals(); ns.Fire("ROSTER_REFRESH")
    end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(ns.L("TYPEBAR_RESET_TIP"), 1, 1, 1); GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 13 colonnes : "25" | 10 types | "1" | doublons. Les filtres de niveau
    -- encadrent la rangee des types ; le filtre doublons suit, tous combinables.
    local n = ns.NUM_PET_TYPES
    local cols = n + 3
    local size = math.floor((W - (cols - 1) * gap) / cols)
    MakeLevel("max", "25", ns.L("LEVELFILTER_MAX"), 0, size)
    for i = 1, n do MakeType(i, i * (size + gap), size) end
    MakeLevel("notmax", "1", ns.L("LEVELFILTER_NOTMAX"), (n + 1) * (size + gap), size)
    MakeDupe((n + 2) * (size + gap), size)

    UpdateVisuals()
end

ns.On("MVL_FRAME_READY", Build)
