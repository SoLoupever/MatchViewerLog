local addonName, ns = ...

-- ====================================================
-- DISCORDDIALOG — popup avec le lien du serveur Discord dans un EditBox
-- pre-selectionne (Ctrl+C). Meme patron que TeamShareDialog (fenetre
-- deplacable, fermable via le bouton ou Echap) : pas d'API WoW pour ouvrir
-- une URL dans le navigateur, donc "controlable" = copiable.
-- ====================================================

local Discord = ns.RegisterModule("DiscordDialog", {})
ns.DiscordDialog = Discord

local LINK = "https://discord.gg/2gfEKGAT46"

local dlg

local function EnsureDlg()
    if dlg then return dlg end
    dlg = CreateFrame("Frame", "MatchViewerLogDiscordDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(360, 112); dlg:SetPoint("CENTER"); dlg:SetFrameStrata("DIALOG"); dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:EnableMouse(true); dlg:SetMovable(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving); dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MatchViewerLogDiscordDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)
    dlg.title:SetText(ns.L("DISCORD_TITLE"))

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    dlg.hintFS = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.hintFS:SetPoint("TOP", 0, -38)
    dlg.hintFS:SetText(ns.L("DISCORD_HINT"))

    -- Zone de lien (EditBox mono-ligne, meme habillage que TeamShareDialog).
    local box = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 16, -58); box:SetPoint("TOPRIGHT", -16, -58); box:SetHeight(22)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6); box:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 6, 0); edit:SetPoint("BOTTOMRIGHT", -6, 0)
    edit:SetAutoFocus(false); edit:SetFontObject("ChatFontNormal")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    dlg.edit = edit

    return dlg
end

function Discord.Open()
    EnsureDlg()
    dlg.edit:SetText(LINK)
    dlg:Show(); dlg:Raise()
    dlg.edit:SetFocus(); dlg.edit:HighlightText()
end
