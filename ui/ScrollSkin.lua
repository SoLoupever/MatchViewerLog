local addonName, ns = ...

-- ====================================================
-- SCROLLSKIN — restyle les barres de defilement classiques (Faux/UIPanel)
-- en version fine et plate facon moderne : fleches masquees, rail discret,
-- curseur bleu clair. Un seul point d'entree : ns.ScrollSkin.Apply(scrollFrame).
-- ====================================================

local Skin = ns.RegisterModule("ScrollSkin", {})
ns.ScrollSkin = Skin

-- Bleu clair (couleur demandee) : curseur au repos / au survol, et rail.
local THUMB    = { 0.38, 0.70, 1.00, 0.90 }
local THUMB_HL = { 0.60, 0.85, 1.00, 1.00 }
local TRACK    = { 0.16, 0.22, 0.32, 0.55 }

local WHITE = "Interface\\Buttons\\WHITE8x8"

local function hideButton(btn)
    if not btn then return end
    btn:SetAlpha(0)
    btn:EnableMouse(false)
    btn:SetSize(1, 1)
end

-- Skinne une barre (Slider UIPanelScrollBarTemplate). scroll = le ScrollFrame
-- parent, pour recoller le rail sur toute la hauteur. Idempotent.
function Skin.Bar(bar, scroll)
    if not bar or bar._mvlSkinned then return end
    bar._mvlSkinned = true

    -- Fleches haut/bas : on les efface (FauxScrollFrame_Update ne fait que
    -- Enable/Disable, jamais Show ni retexture, donc alpha 0 tient).
    hideButton(bar.ScrollUpButton)
    hideButton(bar.ScrollDownButton)

    -- Rail fin sur toute la hauteur, colle au bord droit du contenu.
    if scroll then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    end
    bar:SetWidth(8)

    if not bar._mvlTrack then
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetTexture(WHITE)
        track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
        track:SetWidth(4)
        track:SetPoint("TOP", bar, "TOP", 0, -2)
        track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 2)
        bar._mvlTrack = track
    end

    -- Curseur : pave bleu clair fin (pas le bouton texture d'origine).
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture() or bar.ThumbTexture
    if thumb then
        thumb:SetTexture(WHITE)
        thumb:SetTexCoord(0, 1, 0, 1)
        thumb:SetVertexColor(THUMB[1], THUMB[2], THUMB[3], THUMB[4])
        thumb:SetWidth(6)
        bar._mvlThumb = thumb
    end

    -- Survol : le curseur s'eclaircit.
    bar:HookScript("OnEnter", function()
        if bar._mvlThumb then bar._mvlThumb:SetVertexColor(THUMB_HL[1], THUMB_HL[2], THUMB_HL[3], THUMB_HL[4]) end
    end)
    bar:HookScript("OnLeave", function()
        if bar._mvlThumb then bar._mvlThumb:SetVertexColor(THUMB[1], THUMB[2], THUMB[3], THUMB[4]) end
    end)
end

-- Point d'entree : depuis un ScrollFrame (Faux ou UIPanel), retrouve sa barre
-- (parentKey ScrollBar, ou <nom>ScrollBar) et la skinne.
function Skin.Apply(scroll)
    if not scroll then return end
    local name = scroll.GetName and scroll:GetName()
    local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"]) or nil
    Skin.Bar(bar, scroll)
end
