local addonName, ns = ...

-- ====================================================
-- STYLE — palette + petits helpers visuels partages (fond plat, bouton
-- plat, icone ronde). Les panneaux n'ont plus de litteraux de couleur
-- dupliques : ils lisent ns.Style.COL.
-- ====================================================

local Style = ns.RegisterModule("Style", {})
ns.Style = Style

Style.WHITE = "Interface\\Buttons\\WHITE8x8"

Style.COL = {
    bg      = { 0.030, 0.030, 0.038, 1 },   -- fond fenetre
    panel   = { 0.026, 0.026, 0.032, 1 },   -- fond des colonnes
    card    = { 0.050, 0.050, 0.060, 1 },   -- lignes / cartes
    border  = { 0.40, 0.33, 0.17, 1 },      -- cadre exterieur, champs
    edge    = { 0.21, 0.18, 0.10, 1 },      -- bordure discrete
    gold    = { 1.00, 0.82, 0.00, 1 },
    text    = { 0.90, 0.90, 0.92, 1 },
    dim     = { 0.62, 0.62, 0.67, 1 },
    blue    = { 0.30, 0.55, 0.90, 1 },
    navy    = { 0.05, 0.09, 0.17, 1 },
}
local COL = Style.COL

-- Police des titres (capitales serif de la maquette) : police standard du client.
local titleFont = CreateFont("MatchViewerLogTitleFont")
titleFont:SetFont(STANDARD_TEXT_FONT, 17, "")
titleFont:SetTextColor(0.30, 0.55, 0.90)
Style.TITLE_FONT = "MatchViewerLogTitleFont"

local function Tint(c, f, a)
    return { c[1] * f, c[2] * f, c[3] * f, a or 1 }
end
Style.Tint = Tint

-- Fond + bordure d'1px sur une frame BackdropTemplate.
function Style.Paint(f, bg, border)
    f:SetBackdrop({ bgFile = Style.WHITE, edgeFile = Style.WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or COL.card))
    f:SetBackdropBorderColor(unpack(border or COL.edge))
end

function Style.Box(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Style.Paint(f, bg, border)
    return f
end

-- Bouton plat. spec : bg, border, text, hover, activeBg, activeBorder,
-- activeText, font. b:SetActive(on) bascule l'etat "actif".
function Style.Button(parent, label, w, h, spec)
    spec = spec or {}
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 80, h or 24)
    b.spec = {
        bg = spec.bg or COL.card, border = spec.border or COL.edge,
        text = spec.text or COL.text, hover = spec.hover or COL.gold,
        activeBg = spec.activeBg or spec.bg or COL.card,
        activeBorder = spec.activeBorder or spec.border or COL.edge,
        activeText = spec.activeText or spec.text or COL.text,
    }
    b.text = b:CreateFontString(nil, "OVERLAY", spec.font or "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(label or "")
    b.SetText = function(self, t) self.text:SetText(t) end

    function b:Paint()
        local s = self.spec
        local on = self.active
        local bg, bd, tx = on and s.activeBg or s.bg, on and s.activeBorder or s.border, on and s.activeText or s.text
        if self.hovered then bd = s.hover end
        self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        self:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 1)
        self.text:SetTextColor(tx[1], tx[2], tx[3])
    end
    function b:SetActive(on)
        self.active = on and true or false
        self:Paint()
    end

    b:SetBackdrop({ bgFile = Style.WHITE, edgeFile = Style.WHITE, edgeSize = 1 })
    b:HookScript("OnEnter", function(self) self.hovered = true; self:Paint() end)
    b:HookScript("OnLeave", function(self) self.hovered = false; self:Paint() end)
    b:Paint()
    return b
end

-- Rend une texture circulaire (masque). A appeler une fois a la creation :
-- SetTexture/SetTexCoord restent utilisables ensuite.
function Style.Round(tex, owner)
    local m = (owner or tex:GetParent()):CreateMaskTexture()
    m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(tex)
    tex:AddMaskTexture(m)
    return tex
end

-- Texcoords de l'icone nette de type (sous-region de l'atlas PetIcon-*).
Style.TYPE_COORDS = { 0.796875, 0.4921875, 0.50390625, 0.65625 }
