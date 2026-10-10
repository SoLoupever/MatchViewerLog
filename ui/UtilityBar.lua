local addonName, ns = ...

-- ====================================================
-- UTILITYBAR — petite rangee au-dessus du panneau droit (frame.utilityAnchor) :
-- ranimer les mascottes (sort 125439, avec animation de recharge), Pierre de combat
-- sans defaut (98715), Pierre de dressage sans defaut (116429), Bandage
-- de mascotte (86143), Chapeau de safari (jouet 92738, buff 158486 :
-- clic = met / re-clic = enleve), Friandises pour familier (98114 / 98112).
-- Tout a droite : l'invocation de la mascotte favorite aleatoire (sort
-- 243819). Boutons SECURISES : utilisables seulement hors combat
-- (contrainte Blizzard sur cast/use).
-- ====================================================

ns.RegisterModule("UtilityBar", {})

local REVIVE_SPELL = 125439
local STONE_ITEM   = 98715
local TRAIN_ITEM   = 116429
local BANDAGE_ITEM = 86143
local SAFARI_TOY   = 92738
local SAFARI_BUFF  = 158486
local TREAT_ITEM   = 98114
local TREAT_LESSER = 98112
local SUMMON_SPELL = 243819

local BTN, GAP = 26, 6
local bar, buttons, built = nil, {}, false
local safariBtn

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(id)
        return i and i.name
    end
    return GetSpellInfo and GetSpellInfo(id) or nil
end

local function SpellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return select(3, GetSpellInfo(id))
end

local function SpellCooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local i = C_Spell.GetSpellCooldown(id)
        if i then return i.startTime, i.duration, i.isEnabled end
    elseif GetSpellCooldown then
        return GetSpellCooldown(id)
    end
end

local function ItemTexture(id)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
    return GetItemIcon and GetItemIcon(id) or nil
end

local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
    return GetItemInfo and GetItemInfo(id) or nil
end

local function SpellNameByID(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and GetSpellInfo(id) or nil
end

local function ItemCount(id)
    return (GetItemCount and GetItemCount(id)) or 0
end

-- Buff du chapeau de safari present sur le joueur ?
local function SafariActive()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(SAFARI_BUFF) ~= nil
    end
    if AuraUtil and AuraUtil.FindAuraBySpellID then
        return AuraUtil.FindAuraBySpellID(SAFARI_BUFF, "player", "HELPFUL") ~= nil
    end
    return false
end

-- Toggle du chapeau : macro "utiliser" quand absent, "annuler l'aura" quand
-- present. Fleche sur l'icone quand actif. Ne reecrit pas l'attribut en combat.
local function UpdateSafari(b)
    if not b then return end
    b.icon:SetTexture(ItemTexture(SAFARI_TOY) or 134400)
    b.icon:SetDesaturated(false)
    local active = SafariActive()
    if b.arrow then b.arrow:SetShown(active) end
    if not InCombatLockdown() then
        local toy  = ItemName(SAFARI_TOY)
        local buff = SpellNameByID(SAFARI_BUFF)
        if active and buff then
            b:SetAttribute("macrotext", "/cancelaura " .. buff)
        else
            b:SetAttribute("macrotext", toy and ("/use " .. toy) or ("/use item:" .. SAFARI_TOY))
        end
    end
end

-- Met a jour icone/compteur/recharge et grise si indisponible.
local function RefreshButton(b)
    if b.kind == "spell" then
        b.icon:SetTexture(SpellTexture(b.id) or 134400)
        b.icon:SetDesaturated(false)
        if b.cd then
            local start, dur = SpellCooldown(b.id)
            if start and dur and dur > 0 then b.cd:SetCooldown(start, dur) else b.cd:Clear() end
        end
    elseif b.kind == "safari" then
        UpdateSafari(b)
    else
        b.icon:SetTexture(ItemTexture(b.id) or 134400)
        local n = ItemCount(b.id)
        b.count:SetText(n > 0 and n or "")
        b.icon:SetDesaturated(n == 0)
    end
end

local function RefreshAll()
    for _, b in ipairs(buttons) do RefreshButton(b) end
end

local function MakeButton(parent, kind, id, macro)
    local b = CreateFrame("Button", "MatchViewerLogUtil" .. id, parent, "SecureActionButtonTemplate, BackdropTemplate")
    b:SetSize(BTN, BTN)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.kind, b.id = kind, id

    if macro then
        -- Sort hors grimoire (non castable par nom) : passe par la commande.
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", macro)
    elseif kind == "spell" then
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", SpellName(id) or id)
    elseif kind == "safari" then
        -- Toggle via macro (macrotext regle par UpdateSafari).
        b:SetAttribute("type", "macro")
    else
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. id)
    end

    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.12)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", 0, 1)

    -- Fleche "actif" du chapeau de safari (montree par UpdateSafari quand le buff est la).
    if kind == "safari" then
        b.arrow = b:CreateTexture(nil, "OVERLAY")
        b.arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        b.arrow:SetSize(24, 24)
        b.arrow:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.arrow:Hide()
    end

    -- Animation de recharge Blizzard (sort de ranimation).
    if kind == "spell" then
        b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        b.cd:SetAllPoints(b.icon)
        b.cd:SetDrawEdge(true)
    end

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if self.kind == "spell" then GameTooltip:SetSpellByID(self.id)
        else GameTooltip:SetItemByID(self.id) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function DoBuild()
    if built then return end
    local anchor = ns.Frame and ns.Frame.frame and ns.Frame.frame.utilityAnchor
    if not anchor then return end
    built = true

    bar = CreateFrame("Frame", nil, ns.Frame.frame)
    bar:SetHeight(BTN)
    bar:SetAllPoints(anchor)

    -- Groupe de gauche (ordre d'affichage) et groupe de droite (le dernier
    -- de la liste est colle au bord droit : le plus a droite de tous).
    local leftDefs = {
        { kind = "spell",  id = REVIVE_SPELL },
        { kind = "item",   id = STONE_ITEM },
        { kind = "item",   id = TRAIN_ITEM },
        { kind = "item",   id = BANDAGE_ITEM },
        { kind = "safari", id = SAFARI_TOY },
        { kind = "item",   id = TREAT_ITEM },
        { kind = "item",   id = TREAT_LESSER },
    }
    local rightDefs = {
        { kind = "spell",  id = SUMMON_SPELL, macro = "/randomfavoritepet" },
    }
    local prev
    for _, d in ipairs(leftDefs) do
        local b = MakeButton(bar, d.kind, d.id)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", GAP, 0) else b:SetPoint("LEFT", bar, "LEFT", 0, 0) end
        buttons[#buttons + 1], prev = b, b
        if d.kind == "safari" then safariBtn = b end
    end
    prev = nil
    for i = #rightDefs, 1, -1 do
        local d = rightDefs[i]
        local b = MakeButton(bar, d.kind, d.id, d.macro)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -GAP, 0) else b:SetPoint("RIGHT", bar, "RIGHT", 0, 0) end
        buttons[#buttons + 1], prev = b, b
    end
    RefreshAll()
end

-- Construction hors combat (les boutons securises ne peuvent pas etre
-- crees/configures en combat).
local function BuildWhenSafe()
    if built then return end
    if InCombatLockdown() then
        ns.RegisterWowEvent("PLAYER_REGEN_ENABLED", BuildWhenSafe)
        return
    end
    DoBuild()
end

ns.On("MVL_FRAME_READY", BuildWhenSafe)
ns.On("MVL_FRAME_SHOW", function() if built then RefreshAll() end end)
ns.RegisterWowEvent("BAG_UPDATE_DELAYED", function() if built then RefreshAll() end end)
ns.RegisterWowEvent("SPELLS_CHANGED", function() if built then RefreshAll() end end)
-- Recharge du sort de ranimation : rafraichit l'animation.
ns.RegisterWowEvent("SPELL_UPDATE_COOLDOWN", function() if built then RefreshAll() end end)
-- Buff du chapeau ajoute/retire : on met a jour le toggle.
ns.RegisterWowEvent("UNIT_AURA", function(unit)
    if unit == "player" and safariBtn then UpdateSafari(safariBtn) end
end)
-- Sortie de combat : (re)regle la macro du toggle qui etait bloquee en combat.
ns.RegisterWowEvent("PLAYER_REGEN_ENABLED", function() if safariBtn then UpdateSafari(safariBtn) end end)
