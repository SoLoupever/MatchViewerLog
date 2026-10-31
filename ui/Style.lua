local addonName, ns = ...

-- ====================================================
-- STYLE — palette + petits helpers visuels partages (fond plat, bouton
-- plat, icone ronde). Les panneaux n'ont plus de litteraux de couleur
-- dupliques : ils lisent ns.Style.COL.
-- Point unique du theme (ns.Theme) : les fabriques (Button, Paint, Box,
-- Picker, ...) rendent le look MVL ou Blizzard. Le theme est fige au
-- chargement : pas de test de theme dans les modules UI.
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
    input   = { 0.04, 0.04, 0.05, 1 },      -- champ de recherche
    slot    = { 0.04, 0.04, 0.05, 1 },      -- cartes du centre, cible
    flyout  = { 0.04, 0.04, 0.05, 0.98 },   -- menu de choix de sort
    team    = { 0.12, 0.09, 0.09, 1 },      -- barre du nom de team
    teamBd  = { 0.45, 0.20, 0.20, 1 },
    pill    = { 0.05, 0.16, 0.08, 1 },      -- pastille type/niveau (PetCard)
    pillBd  = { 0.20, 0.50, 0.25, 1 },
}
local COL = Style.COL

-- Palette du theme Blizzard : appliquee en place sur COL (les modules
-- gardent la meme reference de table).
local BLIZZ_COL = {
    bg      = { 0.08, 0.08, 0.10, 1 },
    panel   = { 0.06, 0.06, 0.08, 0.96 },
    card    = { 0.10, 0.10, 0.12, 0.95 },
    border  = { 0.80, 0.80, 0.80, 1 },
    edge    = { 0.55, 0.55, 0.55, 1 },
    text    = { 1, 1, 1, 1 },
    input   = { 0.06, 0.06, 0.08, 0.96 },
    slot    = { 0.08, 0.08, 0.10, 1 },
    flyout  = { 0.06, 0.06, 0.08, 0.98 },
    team    = { 0.08, 0.08, 0.10, 1 },
    teamBd  = { 0.80, 0.80, 0.80, 1 },
    column  = { 0.03, 0.03, 0.04, 1 },
    pill    = { 0.10, 0.10, 0.12, 0.95 },
    pillBd  = { 0.80, 0.80, 0.80, 1 },
}

local function IsBlizz() return ns.Theme and ns.Theme.IsBlizzard() end
Style.IsBlizzard = IsBlizz

-- Marge droite reservee a la barre de defilement (native = plus large).
Style.SCROLL_INSET = 18

-- Police des titres : bleue (MVL) ou police Blizzard doree (theme Blizzard).
local titleFont = CreateFont("MatchViewerLogTitleFont")
titleFont:SetFont(STANDARD_TEXT_FONT, 17, "")
titleFont:SetTextColor(0.30, 0.55, 0.90)
Style.TITLE_FONT = "MatchViewerLogTitleFont"

-- Bascule la palette/police une fois les SavedVariables chargees.
ns.On("DB_READY", function()
    if not IsBlizz() then return end
    for k, v in pairs(BLIZZ_COL) do COL[k] = v end
    titleFont:CopyFontObject("GameFontNormalLarge")
    Style.SCROLL_INSET = 26
end)

local function Tint(c, f, a)
    return { c[1] * f, c[2] * f, c[3] * f, a or 1 }
end
Style.Tint = Tint

local FLAT_BACKDROP = { bgFile = Style.WHITE, edgeFile = Style.WHITE, edgeSize = 1 }
local BLIZZ_BACKDROP = {
    bgFile = Style.WHITE,   -- aplat opaque (la texture d'infobulle est translucide)
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
function Style.Backdrop() return IsBlizz() and BLIZZ_BACKDROP or FLAT_BACKDROP end

-- Fond + bordure sur une frame BackdropTemplate (1px plat, ou cadre infobulle Blizzard).
-- flat = true : bordure 1px meme en theme Blizzard (petits cadres, ex: icones).
function Style.Paint(f, bg, border, flat)
    f:SetBackdrop(flat and FLAT_BACKDROP or Style.Backdrop())
    f:SetBackdropColor(unpack(bg or COL.card))
    f:SetBackdropBorderColor(unpack(border or COL.edge))
end

function Style.Box(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Style.Paint(f, bg, border)
    return f
end

-- Cree un frame depuis un template Blizzard ; nil si le template est absent
-- (le bouton retombe alors sur le look plat, sans erreur).
local function TryTemplate(kind, parent, template)
    local ok, f = pcall(CreateFrame, kind, nil, parent, template)
    return ok and f or nil
end
Style.TryTemplate = TryTemplate

-- Bouton Blizzard (UIPanelButtonTemplate). Memes methodes que le bouton plat.
local function BlizzButton(parent, label, w, h, spec)
    local b = TryTemplate("Button", parent, "UIPanelButtonTemplate")
    if not b then return nil end
    b:SetSize(w or 80, math.max(h or 22, 22))
    -- spec.small : police reduite pour les boutons etroits (le libelle ne deborde pas).
    if spec and spec.small then
        b:SetNormalFontObject("GameFontNormalSmall")
        b:SetHighlightFontObject("GameFontHighlightSmall")
        b:SetDisabledFontObject("GameFontDisableSmall")
    end
    b:SetText(label or "")
    b.text = b:GetFontString()
    function b:SetActive(on)
        self.active = on and true or false
        if on then self:LockHighlight() else self:UnlockHighlight() end
        self:SetButtonState(on and "PUSHED" or "NORMAL", on and true or false)
    end
    return b
end

-- Bouton plat. spec : bg, border, text, hover, activeBg, activeBorder,
-- activeText, font. b:SetActive(on) bascule l'etat "actif".
-- Theme Blizzard : bouton natif, spec ignore.
function Style.Button(parent, label, w, h, spec)
    if IsBlizz() then
        local nb = BlizzButton(parent, label, w, h, spec)
        if nb then return nb end
    end
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

-- Selecteur deroulant : bouton + libelle b.fs + fleche. Le menu est gere par l'appelant.
function Style.Picker(parent)
    local b = IsBlizz() and TryTemplate("Button", parent, "UIPanelButtonTemplate") or nil
    if b then
        b:SetHeight(24)
    else
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetHeight(22)
        Style.Paint(b, { 0.12, 0.12, 0.16, 1 }, { 0.4, 0.4, 0.5, 1 })
    end
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.fs:SetPoint("LEFT", 8, 0); b.fs:SetPoint("RIGHT", -20, 0)
    b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12); arrow:SetPoint("RIGHT", -6, 0)
    if IsBlizz() then arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    else arrow:SetAtlas("housing-floor-arrow-down-default") end
    return b
end

-- Icone plier/deplier d'une ligne de liste.
function Style.SetFoldIcon(tex, open)
    if IsBlizz() then
        tex:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetAtlas(open and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
    end
end

-- Surbrillance de survol d'une ligne de liste.
function Style.RowHighlight(row)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    if IsBlizz() then
        hl:SetAtlas("PetList-ButtonHighlight")
        hl:SetBlendMode("ADD")
    else
        hl:SetColorTexture(1, 1, 1, 0.08)
    end
    return hl
end

-- Fond de ligne de liste facon Journal Blizzard (atlas natifs PetList-*).
-- Theme MVL : rien (nil), le fond reste celui de la colonne.
function Style.RowBackground(row)
    if not IsBlizz() then return nil end
    local bg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints(); bg:SetAtlas("PetList-ButtonBackground")
    return bg
end

-- Ligne de la liste de mascottes : fond + selection natifs.
function Style.DecorateRoster(row)
    if not IsBlizz() then return end
    row.bgTex = Style.RowBackground(row)
    row.sel = row:CreateTexture(nil, "OVERLAY")
    row.sel:SetAllPoints(); row.sel:SetAtlas("PetList-ButtonSelect"); row.sel:Hide()
end

-- Retourne true si le theme gere la selection (sinon l'appelant garde sa bordure doree).
function Style.UpdateRoster(row, selected)
    if not row.sel then return false end
    row.sel:SetShown(selected)
    return true
end

-- Fond de carte de mascotte (theme Blizzard) : texture PetBattles\\PetJournal + motif du type.
local SLOT_TINT = {
    leveling = { 0.5, 0.75, 1 }, random = { 0.5, 1, 0.5 }, ignored = { 1, 0.5, 0.5 },
}
local SLOT_DIM = 0.5
function Style.SlotArt(frame)
    if not IsBlizz() then return end
    frame.back = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.back:SetPoint("TOPLEFT", 3, -3); frame.back:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.back:SetTexture("Interface\\PetBattles\\PetJournal")
    frame.back:SetTexCoord(0, 0.44296875, 0.484375, 0.59375)
    frame.decal = frame:CreateTexture(nil, "BORDER")
    frame.decal:SetSize(77, 77); frame.decal:SetPoint("TOPRIGHT", -4, -4)
    frame.decal:SetTexCoord(0.03125, 0.84375, 0, 0.421875)
    frame.decal:SetAlpha(0.4)
    frame.decal:Hide()
end

-- Fond de la barre du nom de team (theme Blizzard) : bande de _PetJournalHorizTile (64x128, lignes 30-56), assombrie comme les cartes.
local TEAMBAR_TEX = "Interface\\PetBattles\\_PetJournalHorizTile"
local TEAMBAR_DIM = 0.7
function Style.TeamBarArt(bar)
    if not IsBlizz() then return end
    local t = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1)
    t:SetTexture(TEAMBAR_TEX)
    t:SetTexCoord(0, 1, 30 / 128, 56 / 128)
    t:SetDesaturated(true)
    t:SetVertexColor(TEAMBAR_DIM, TEAMBAR_DIM, TEAMBAR_DIM * 1.1)
    bar.back = t
end

-- Texture 512x1024 ; zone utilisee (px) et encoche de l'icone : centre + ouverture interne.
local TEX_W, TEX_H = 512, 1024
local REG_X, REG_Y, REG_W, REG_H = 0, 496, 226, 112
local FRM_CX, FRM_CY, FRM_IN = 30.5, 33.3, 35
-- Echelle uniforme (pas de deformation) : la zone est rognee pour remplir la carte,
-- puis l'icone est posee dans l'encoche. Retourne le decalage x de l'icone (nil hors Blizzard).
function Style.PlaceSlotIcon(frame, iconBtn, w, h)
    if not frame.back then return nil end
    local iw, ih = w - 6, h - 6
    local s = math.max(iw / REG_W, ih / REG_H)
    frame.back:SetTexCoord(REG_X / TEX_W, (REG_X + iw / s) / TEX_W, REG_Y / TEX_H, (REG_Y + ih / s) / TEX_H)
    local size = FRM_IN * s
    local x = 3 + FRM_CX * s - size / 2
    iconBtn:ClearAllPoints()
    iconBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(3 + FRM_CY * s - size / 2))
    iconBtn:SetSize(size, size)
    return x
end

-- kind : nil (normal) | "leveling" | "random" | "ignored" ; petType : motif (optionnel).
function Style.SetSlotArt(frame, kind, petType)
    if not frame.back then return end
    local c = SLOT_TINT[kind]
    -- Toujours desature et assombri : le motif reste, mais la couleur s'accorde au reste du theme.
    frame.back:SetDesaturated(true)
    local k = SLOT_DIM
    if c then frame.back:SetVertexColor(c[1] * k, c[2] * k, c[3] * k)
    else frame.back:SetVertexColor(k, k, k * 1.1) end
    local tex = petType and GetPetTypeTexture and GetPetTypeTexture(petType)
    if tex then frame.decal:SetTexture(tex); frame.decal:Show() else frame.decal:Hide() end
end

-- Fond uni des colonnes gauche/droite (theme Blizzard) : meme noir que les barres de liste.
function Style.FillColumn(col)
    if not IsBlizz() then return end
    local t = col:CreateTexture(nil, "BACKGROUND", nil, 6)
    t:SetAllPoints(col)
    t:SetColorTexture(unpack(COL.column))
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

-- Couleur d'accent par type de mascotte (index = petType 1..10).
Style.TYPE_COL = {
    [1] = { 0.45, 0.65, 0.95, 1 }, [2] = { 0.40, 0.80, 0.45, 1 }, [3] = { 0.75, 0.80, 0.95, 1 },
    [4] = { 0.70, 0.45, 0.85, 1 }, [5] = { 0.80, 0.70, 0.55, 1 }, [6] = { 0.55, 0.45, 0.95, 1 },
    [7] = { 0.95, 0.55, 0.25, 1 }, [8] = { 0.90, 0.75, 0.30, 1 }, [9] = { 0.35, 0.75, 0.95, 1 },
    [10] = { 0.75, 0.75, 0.80, 1 },
}

-- Texcoords de l'icone nette de type (sous-region de l'atlas PetIcon-*).
Style.TYPE_COORDS = { 0.796875, 0.4921875, 0.50390625, 0.65625 }
