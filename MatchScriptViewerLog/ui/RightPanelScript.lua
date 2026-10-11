local addonName, ns = ...

-- ====================================================
-- RIGHTPANELSCRIPT — injecte le mode "Script" a droite de "File"
-- dans le panneau droit de MVL (via RegisterRightPanelMode). Edite le
-- script "code" de l'equipe CHARGEE. Bouton d'import des scripts
-- . Bouton "Enregistrer" = interrupteur de
-- l'enregistrement de combat (rouge quand actif), cf. BattleRecorder.
-- ====================================================

ns.RegisterModule("RightPanelScript", {})

local PAD = 8
local container, codeEditor, headerBtn, hintFS, recordBtn

-- Couleur du bouton Enregistrer : rouge quand l'enregistrement est arme.
local function PaintRecordBtn(b)
    local on = ns.Recorder.IsArmed()
    if on then
        b:SetBackdropColor(0.45, 0.07, 0.07, 1)
    else
        b:SetBackdropColor(0.14, 0.12, 0.18, 1)
    end
    if b.hovered then
        b:SetBackdropBorderColor(1, 0.82, 0, 1)
    elseif on then
        b:SetBackdropBorderColor(1, 0.25, 0.25, 1)
    else
        b:SetBackdropBorderColor(0.4, 0.3, 0.55, 1)
    end
end

-- teamID actuellement edite = equipe chargee dans MVL.
function ns.CurrentEditTeam()
    local cur = ns.MVL.GetCurrentTeam()
    return cur and cur.sourceTeamID or nil
end

local SmallBtn = ns.Widgets.SmallBtn

local function Refresh()
    if not (container and container:IsShown()) then return end

    local ids = ns.Scripts.AllScriptedIDs()
    headerBtn.text:SetText(ns.L("SCRIPT_TEAMS_MENU"):format(#ids) .. " |cffffffffv|r")

    local id = ns.CurrentEditTeam()
    if not id then
        hintFS:SetText(ns.L("SCRIPT_HINT_LOAD"))
    elseif not ns.Scripts.Has(id) then
        hintFS:SetText(ns.L("SCRIPT_HINT_EMPTY"))
    else
        hintFS:SetText("")
    end

    codeEditor:RefreshEditor()
end

local function BuildContainer(panel)
    if container then return end
    container = CreateFrame("Frame", nil, panel)
    container:SetPoint("TOPLEFT", PAD, -PAD - 30)
    container:SetPoint("BOTTOMRIGHT", -PAD, 34)

    -- En-tete : menu des equipes scriptees.
    headerBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    headerBtn:SetHeight(22)
    headerBtn:SetPoint("TOPLEFT", 0, 0); headerBtn:SetPoint("TOPRIGHT", 0, 0)
    headerBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    headerBtn:SetBackdropColor(0.16, 0.10, 0.22, 1); headerBtn:SetBackdropBorderColor(0.55, 0.35, 0.85, 1)
    headerBtn.text = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerBtn.text:SetPoint("CENTER")
    headerBtn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:SetTag("MSVL_SCRIPT_TEAMS")
            local ids = ns.Scripts.AllScriptedIDs()
            if #ids == 0 then root:CreateTitle(ns.L("SCRIPT_NO_TEAMS")); return end
            for _, id in ipairs(ids) do
                local t = ns.MVL.GetTeam(id)
                root:CreateButton(t and t.name or id, function() ns.MVL.SelectTeam(id) end)
            end
        end)
    end)

    -- Rangee A : Enregistrer (interrupteur d'enregistrement de combat) +
    -- Code (repere visuel, forme unique desormais) + Deployer (occupe tout
    -- l'espace restant a droite jusqu'au bord).
    local saveBtn = SmallBtn(container, 70, ns.L("SCRIPT_SAVE_BTN"))
    saveBtn:SetPoint("TOPLEFT", headerBtn, "BOTTOMLEFT", 0, -4)
    PaintRecordBtn(saveBtn)
    saveBtn:SetScript("OnEnter", function(self)
        self.hovered = true; PaintRecordBtn(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L("REC_TIP_TITLE"), 0.8, 0.5, 1)
        GameTooltip:AddLine(ns.L(ns.Recorder.IsArmed() and "REC_TIP_ON" or "REC_TIP_OFF"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    saveBtn:SetScript("OnLeave", function(self)
        self.hovered = false; PaintRecordBtn(self)
        GameTooltip_Hide()
    end)
    saveBtn:SetScript("OnClick", function() ns.Recorder.Toggle() end)
    recordBtn = saveBtn

    local codeBtn = SmallBtn(container, 70, ns.L("SCRIPT_KIND_CODE"))
    codeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 4, 0)

    local deployBtn = SmallBtn(container, 100, ns.L("DEPLOY_BTN"))
    deployBtn:SetPoint("TOPLEFT", codeBtn, "TOPRIGHT", 4, 0)
    deployBtn:SetPoint("TOPRIGHT", headerBtn, "BOTTOMRIGHT", 0, -4)
    deployBtn:SetBackdropColor(0.10, 0.20, 0.14, 1); deployBtn:SetBackdropBorderColor(0.35, 0.7, 0.45, 1)
    deployBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    deployBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.35, 0.7, 0.45, 1) end)
    deployBtn:SetScript("OnClick", function() if ns.Deploy then ns.Deploy.Current(true) end end)

    -- Rangee B : import pleine largeur.
    local importBtn = SmallBtn(container, 120, ns.L("SCRIPT_IMPORT_TD"))
    importBtn:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -4)
    importBtn:SetPoint("TOPRIGHT", deployBtn, "BOTTOMRIGHT", 0, -4)
    importBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    importBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.4, 0.3, 0.55, 1) end)
    importBtn:SetScript("OnClick", function() if MatchViewerLog_Converter then MatchViewerLog_Converter.ImportTd(true) end end)

    hintFS = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintFS:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 2, -4)
    hintFS:SetPoint("TOPRIGHT", importBtn, "BOTTOMRIGHT", -2, -4)
    hintFS:SetJustifyH("LEFT")

    codeEditor = ns.CodeEditor.Create(container)
    codeEditor:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 0, -18)
    codeEditor:SetPoint("BOTTOMRIGHT", 0, 0)

    container:Hide()
end

-- Enregistrement du mode aupres de MVL (a droite de File).
ns.MVL.RegisterRightPanelMode({
    key    = "script",
    label  = ns.L("MODE_SCRIPT"),
    col    = { 0.30, 0.55, 0.90 },
    custom = true,
    onShow = function(panel)
        BuildContainer(panel)
        container:Show()
        Refresh()
    end,
    onHide = function()
        if container then container:Hide() end
    end,
})

ns.On("MSVL_RECORD_STATE", function() if recordBtn then PaintRecordBtn(recordBtn) end end)
ns.On("TEAM_LOADED", Refresh)
ns.On("MSVL_SCRIPTS_CHANGED", Refresh)
