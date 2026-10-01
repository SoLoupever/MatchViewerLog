local addonName, ns = ...

-- ====================================================
-- OPTIONSPANEL — contenu du mode "Options" du panneau droit. Construit un
-- conteneur (comme RightPanelScript) affiche/masque par le mode. Ne stocke
-- rien : lit/ecrit l'etat via ns.Options. Aucune string en dur (ns.L).
-- ====================================================

local OptionsPanel = ns.RegisterModule("OptionsPanel", {})
ns.OptionsPanel = OptionsPanel

local container, sortBtn, nbCheck, xpBtn, baseCheck
-- Controles injectes par un compagnon (ns.optionControls) : frames deja poses
-- + ancre du dernier, pour empiler le suivant en dessous.
local extraCtrls, extraAnchor = {}, nil

-- Ordre des choix du menu + cle de libelle associee.
local SORT_ORDER = { "level_name", "level_rarity_name", "rarity_name", "name" }
local SORT_LABEL = {
    level_name        = "OPT_SORT_LEVEL_NAME",
    level_rarity_name = "OPT_SORT_LEVEL_RARITY",
    rarity_name       = "OPT_SORT_RARITY",
    name              = "OPT_SORT_NAME",
}
local function SortLabel(mode) return ns.L(SORT_LABEL[mode] or "OPT_SORT_LEVEL_NAME") end

-- Modes du slot aleatoire "XP" (file d'XP).
local XP_ORDER = { "closest25", "closest25_rare", "random", "lowest" }
local XP_LABEL = {
    closest25      = "OPT_XP_CLOSEST25",
    closest25_rare = "OPT_XP_RARE",
    random         = "OPT_XP_RANDOM",
    lowest         = "OPT_XP_LOWEST",
}
local function XpLabel(mode) return ns.L(XP_LABEL[mode] or "OPT_XP_CLOSEST25") end

-- Bouton-selecteur generique (meme style que le picker de categorie).
local function MakePicker(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0.12, 0.12, 0.16, 1); b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.fs:SetPoint("LEFT", 6, 0); b.fs:SetPoint("RIGHT", -18, 0)
    b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12); arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetAtlas("housing-floor-arrow-down-default")
    return b
end

-- Pose les controles compagnons pas encore batis, empiles sous le dernier.
local function BuildExtras()
    if not container then return end
    local defs = ns.optionControls or {}
    for i = #extraCtrls + 1, #defs do
        local def = defs[i]
        local ok, frame = pcall(def.build, container)
        if ok and frame then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", extraAnchor, "BOTTOMLEFT", 0, -16)
            frame:SetPoint("RIGHT", container, "RIGHT", -2, 0)
            extraAnchor = frame
            extraCtrls[i] = { def = def, frame = frame }
        else
            extraCtrls[i] = { def = def }   -- echec : on ne reessaie pas en boucle
        end
    end
end

local function Build(panel)
    if container then return end
    container = CreateFrame("Frame", nil, panel)
    container:SetPoint("TOPLEFT", 8, -38)
    container:SetPoint("BOTTOMRIGHT", -8, 34)

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 2, -2); title:SetText(ns.L("OPT_TITLE"))

    local sortLbl = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortLbl:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16); sortLbl:SetText(ns.L("OPT_SORT_LABEL"))

    -- Selecteur d'ordre de la liste de gauche.
    sortBtn = MakePicker(container)
    sortBtn:SetPoint("TOPLEFT", sortLbl, "BOTTOMLEFT", 0, -4)
    sortBtn:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    sortBtn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_OPT_SORT")
            for _, m in ipairs(SORT_ORDER) do
                root:CreateButton(SortLabel(m), function()
                    ns.Options.Set("sort", m)
                    self.fs:SetText(SortLabel(m))
                end)
            end
        end)
    end)

    -- Mascottes non-combattantes en dernier.
    nbCheck = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    nbCheck:SetSize(24, 24)
    nbCheck:SetPoint("TOPLEFT", sortBtn, "BOTTOMLEFT", -2, -16)
    nbCheck.label = nbCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nbCheck.label:SetPoint("LEFT", nbCheck, "RIGHT", 2, 0)
    nbCheck.label:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    nbCheck.label:SetJustifyH("LEFT"); nbCheck.label:SetWordWrap(true)
    nbCheck.label:SetText(ns.L("OPT_NONBATTLE_LAST"))
    nbCheck:SetScript("OnClick", function(self)
        ns.Options.Set("nonBattleLast", self:GetChecked() and true or false)
    end)

    -- File d'XP : choix de la mascotte du slot aleatoire "XP".
    local xpLbl = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpLbl:SetPoint("TOPLEFT", nbCheck, "BOTTOMLEFT", 2, -16); xpLbl:SetText(ns.L("OPT_XP_LABEL"))
    xpBtn = MakePicker(container)
    xpBtn:SetPoint("TOPLEFT", xpLbl, "BOTTOMLEFT", 0, -4)
    xpBtn:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    xpBtn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MVL_OPT_XP")
            for _, m in ipairs(XP_ORDER) do
                root:CreateButton(XpLabel(m), function()
                    ns.Options.Set("xpPick", m)
                    self.fs:SetText(XpLabel(m))
                end)
            end
        end)
    end)

    -- Afficher les mascottes renommees avec leur nom de base.
    baseCheck = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    baseCheck:SetSize(24, 24)
    baseCheck:SetPoint("TOPLEFT", xpBtn, "BOTTOMLEFT", -2, -16)
    baseCheck.label = baseCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    baseCheck.label:SetPoint("LEFT", baseCheck, "RIGHT", 2, 0)
    baseCheck.label:SetPoint("RIGHT", container, "RIGHT", -2, 0)
    baseCheck.label:SetJustifyH("LEFT"); baseCheck.label:SetWordWrap(true)
    baseCheck.label:SetText(ns.L("OPT_BASENAME"))
    baseCheck:SetScript("OnClick", function(self)
        ns.Options.Set("baseName", self:GetChecked() and true or false)
    end)

    -- Options natives posees : les compagnons s'empilent en dessous.
    extraAnchor = baseCheck
    BuildExtras()

    container:Hide()
end

-- Aligne les controles sur l'etat persiste (a chaque ouverture).
local function Sync()
    if not container then return end
    sortBtn.fs:SetText(SortLabel(ns.Options.Get("sort")))
    nbCheck:SetChecked(ns.Options.Get("nonBattleLast") and true or false)
    xpBtn.fs:SetText(XpLabel(ns.Options.Get("xpPick")))
    baseCheck:SetChecked(ns.Options.Get("baseName") and true or false)
    for _, c in ipairs(extraCtrls) do
        if c.def and c.def.sync then pcall(c.def.sync) end
    end
end

function OptionsPanel.OnShow(panel)
    Build(panel)
    Sync()
    container:Show()
end

function OptionsPanel.OnHide()
    if container then container:Hide() end
end

-- Un compagnon enregistre un controle apres coup : on le pose si le panneau
-- existe deja (sinon Build s'en chargera a la premiere ouverture).
ns.On("MVL_OPTIONCTRLS_CHANGED", function()
    if not container then return end
    BuildExtras()
    if container:IsShown() then Sync() end
end)
