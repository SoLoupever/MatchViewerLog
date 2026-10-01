local addonName, ns = ...

-- ====================================================
-- PETTEAMBADGE — pastille "mascotte deja dans une team" +
-- infobulle listant les teams (nom + categorie). Reutilisee
-- par la liste de gauche et la PetCard.
-- ====================================================

local Badge = ns.RegisterModule("PetTeamBadge", {})
ns.PetTeamBadge = Badge

local ICON = 613074   -- tracking_wildpet
local MAX_LINES = 12

local function CatInfo(t)
    local c = ns.Cats and t.category and ns.Cats.GetByID(t.category)
    local name = c and c.name or ns.L("CAT_NONE")
    local color = c and c.color or "9d9d9d"
    return name, color
end

local function ShowTip(self)
    local list = self.petID and ns.PetTeams.Get(self.petID)
    if not list or #list == 0 then return end
    GameTooltip:SetOwner(self, self.tipAnchor)
    GameTooltip:AddLine(ns.L("PETTEAM_TITLE"):format(#list), 1, 0.82, 0)
    for i = 1, math.min(#list, MAX_LINES) do
        local t = list[i]
        local cname, ccol = CatInfo(t)
        GameTooltip:AddDoubleLine(t.name or "?", "|cff" .. ccol .. cname .. "|r", 1, 1, 1)
    end
    if #list > MAX_LINES then
        GameTooltip:AddLine(ns.L("PETTEAM_MORE"):format(#list - MAX_LINES), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- tipAnchor : ancrage GameTooltip. onEnter/onLeave : relais optionnels
-- (ex. garder la PetCard ouverte quand la souris passe sur la pastille).
function Badge.Create(parent, size, tipAnchor, onEnter, onLeave)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tipAnchor = tipAnchor
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(ICON)
    if b.SetPropagateMouseClicks then b:SetPropagateMouseClicks(true) end
    b:SetScript("OnEnter", function(self)
        if onEnter then onEnter() end
        ShowTip(self)
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if onLeave then onLeave() end
    end)
    b:Hide()

    -- petID nil/non utilisee -> masquee.
    function b:SetPetID(petID)
        self.petID = petID
        self:SetShown(petID ~= nil and #ns.PetTeams.Get(petID) > 0)
    end
    return b
end
