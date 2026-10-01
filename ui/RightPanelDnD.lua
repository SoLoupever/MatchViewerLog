local addonName, ns = ...

-- ====================================================
-- RIGHTPANELDND — glisser-deposer visuel des lignes du panneau droit
-- (reordonner categories / equipes) : fantome semi-transparent + ligne
-- d'insertion. Extrait de RightPanel ; celui-ci injecte la liste des lignes
-- et la hauteur de ligne via DnD.Init, et delegue Start/Finish.
-- ====================================================

local DnD = ns.RegisterModule("RightPanelDnD", {})
ns.RightPanelDnD = DnD

-- Injectes par RightPanel.Build (memes references que le panneau).
local rows, ROW_H
function DnD.Init(rowList, rowHeight)
    rows = rowList
    ROW_H = rowHeight
end

local drag = { active = false }
local ghost, dropLine
local UpdateDropTarget      -- forward (utilisee par le OnUpdate du fantome)

local function RowID(row)
    if drag.kind == "cat" then return row.catID end
    return row.team and row.team.id
end

-- Lignes visibles compatibles avec le drag en cours (memes categorie/type).
-- Calculee une seule fois par StartDrag (le lot de lignes ne change pas en
-- cours de drag) : evite de rescanner "rows" et de reallouer une table a
-- chaque OnUpdate du fantome (~60 fois/seconde pendant un drag).
local function DraggableRows()
    local out = {}
    for _, row in ipairs(rows) do
        if row:IsShown() then
            if drag.kind == "cat" and row._type == "cat" then
                out[#out + 1] = row
            elseif drag.kind == "team" and row._type == "team"
                   and row.team and row.team.category == drag.category then
                out[#out + 1] = row
            end
        end
    end
    return out
end

local function EnsureGhost()
    if ghost then return end
    ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ghost:SetFrameStrata("TOOLTIP"); ghost:SetSize(150, ROW_H)
    ghost:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    ghost:SetBackdropColor(0.10, 0.10, 0.14, 0.85); ghost:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    ghost:SetAlpha(0.7); ghost:EnableMouse(false)
    ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ghost.text:SetPoint("LEFT", 8, 0); ghost.text:SetPoint("RIGHT", -6, 0)
    ghost.text:SetJustifyH("LEFT"); ghost.text:SetWordWrap(false)
    ghost:Hide()

    -- Ligne d'insertion : frame dediee au-dessus des lignes (strata DIALOG).
    local holder = CreateFrame("Frame", nil, ghost:GetParent())
    holder:SetFrameStrata("DIALOG")
    dropLine = holder:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(3); dropLine:SetColorTexture(1, 0.82, 0, 1); dropLine:Hide()

    ghost:SetScript("OnUpdate", function(self)
        if not drag.active then return end
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 14, y / s + 8)
        UpdateDropTarget()
    end)
end

-- Positionne la ligne d'insertion sur le bord haut ("top") ou bas ("bottom")
-- de la ligne visee.
local function PlaceLine(row, edge)
    dropLine:ClearAllPoints()
    local corner = (edge == "top") and "TOPLEFT" or "BOTTOMLEFT"
    local corner2 = (edge == "top") and "TOPRIGHT" or "BOTTOMRIGHT"
    dropLine:SetPoint("TOPLEFT", row, corner, 2, 1)
    dropLine:SetPoint("TOPRIGHT", row, corner2, -2, 1)
    dropLine:Show()
end

-- Recalcule la cible d'insertion (avant quelle ligne, ou en fin) et l'apercu.
UpdateDropTarget = function()
    drag.beforeID, drag.atEnd = nil, false
    if dropLine then dropLine:Hide() end
    local sib = drag.siblings
    if not sib or #sib == 0 then return end
    local scale = sib[1]:GetEffectiveScale()
    local _, cy = GetCursorPosition(); cy = cy / scale
    for i, row in ipairs(sib) do
        local top, bottom = row:GetTop(), row:GetBottom()
        if top and bottom and cy <= top and cy >= bottom then
            if cy >= (top + bottom) / 2 then
                drag.beforeID = RowID(row); PlaceLine(row, "top")
            else
                local nxt = sib[i + 1]
                if nxt then drag.beforeID = RowID(nxt); PlaceLine(nxt, "top")
                else drag.atEnd = true; PlaceLine(row, "bottom") end
            end
            return
        end
    end
    -- Hors des lignes : au-dessus de la premiere -> debut ; sinon -> fin.
    local first, last = sib[1], sib[#sib]
    if first:GetTop() and cy > first:GetTop() then
        drag.beforeID = RowID(first); PlaceLine(first, "top")
    else
        drag.atEnd = true; PlaceLine(last, "bottom")
    end
end

local function StartDrag(row)
    EnsureGhost()
    drag.active = true
    drag.kind = row._type
    drag.id = RowID(row)
    drag.category = (row._type == "team") and row.team and row.team.category or nil
    drag.sourceRow = row
    drag.siblings = DraggableRows()   -- fige le lot compatible pour toute la duree du drag
    row:SetAlpha(0.35)          -- la ligne saisie s'estompe (elle "part" dans le fantome)
    ghost.text:SetText(row.name:GetText() or "")
    ghost:Show()
end

local function FinishDrag()
    if not drag.active then return end
    drag.active = false
    if drag.sourceRow then drag.sourceRow:SetAlpha(1); drag.sourceRow = nil end
    if ghost then ghost:Hide() end
    if dropLine then dropLine:Hide() end
    local id = drag.id
    if id and (drag.beforeID or drag.atEnd) and ns.Cats then
        if drag.kind == "cat" then
            if drag.atEnd then ns.Cats.MoveBefore(id, nil)
            elseif drag.beforeID ~= id then ns.Cats.MoveBefore(id, drag.beforeID) end
        elseif drag.kind == "team" then
            if drag.atEnd then ns.Cats.MoveTeamBefore(id, nil)
            elseif drag.beforeID ~= id then ns.Cats.MoveTeamBefore(id, drag.beforeID) end
        end
    end
    drag.id, drag.beforeID, drag.atEnd, drag.category, drag.kind, drag.siblings = nil, nil, false, nil, nil, nil
end

DnD.Start  = StartDrag
DnD.Finish = FinishDrag
