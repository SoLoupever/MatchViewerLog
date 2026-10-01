local addonName, ns = ...

-- ====================================================
-- REMATCHSTRING — importe une chaine d'equipe REMATCH collee (fournie par
-- xufu.gg / wow-petguide), au lieu de lire les SavedVariables. On decode
-- la chaine avec le format exact de Rematch (process/teamStrings.lua +
-- process/petTags.lua) et on la convertit en payload MVL (meme forme que
-- TeamShare.Decode). Le script tdBattlePetScript, embarque dans les notes
-- entre les marqueurs BEGIN/END, ressort en scriptBlob "code:" (relu par
-- le hook d'import de MatchScriptViewerLog). Rien d'invente : tout vient
-- du code source Rematch/TD fourni.
-- S'enregistre comme convertisseur de chaine aupres de MVL (la case xufu
-- de la fenetre d'import l'appelle).
-- ====================================================

local MVL = ns.MVL
local Xufu = ns.RegisterModule("ImportXufu", {})

-- Sorts d'un tag Rematch : positions 1-3 = offsets base32 (0 ignore,
-- 1 = list[t], 2 = list[t+3]). Meme convention que source/Import.lua.
local function DecodeAbil(tag, species)
    local out = { 0, 0, 0 }
    if not species then return out end
    local list = C_PetJournal.GetPetAbilityList(species)
    if type(list) ~= "table" then return out end
    for t = 1, 3 do
        local choice = tonumber(tag:sub(t, t), 32)
        if choice == 1 then out[t] = list[t] or 0
        elseif choice == 2 then out[t] = list[t + 3] or 0 end
    end
    return out
end

-- Traduit un petTag en entree de payload. Retourne kind + donnee :
-- "pet" {species,breed,abil} | "random" N | "special" "leveling"/"ignored" | "skip".
-- Tags speciaux Rematch (process/petTags.lua) : ZL leveling, ZI ignored,
-- ZR<n> random (n = type 0..10), ZN/ZU sans equivalent exploitable.
local function DecodeTag(tag)
    if type(tag) ~= "string" or tag == "" then return "skip" end
    if tag == "ZL" then return "special", "leveling" end
    if tag == "ZI" then return "special", "ignored" end
    local rt = tag:match("^ZR(%w+)")
    if rt then return "random", tonumber(rt, 32) end
    if tag:sub(1, 1) == "Z" then return "skip" end

    local species = tonumber(tag:sub(5, -1), 32)
    if not species then return "skip" end
    local breedID = tonumber(tag:sub(4, 4), 32) or 0
    return "pet", { species = species, breed = MVL.GetBreedName(breedID) or "0", abil = DecodeAbil(tag, species) }
end

-- Script tdBattlePetScript : entre les deux marqueurs, dans les notes.
local BEGIN_MARK = "-----BEGIN PET BATTLE SCRIPT-----"
local END_MARK   = "-----END PET BATTLE SCRIPT-----"
-- Recherche LITTERALE (les tirets des marqueurs sont des caracteres magiques
-- en pattern Lua : on utilise string.find en mode plain).
local function ExtractScript(notes)
    local _, b2 = notes:find(BEGIN_MARK, 1, true)
    if not b2 then return nil end
    local e1 = notes:find(END_MARK, b2 + 1, true)
    local body = notes:sub(b2 + 1, e1 and (e1 - 1) or nil)
    body = body:gsub("^%s+", ""):gsub("%s+$", "")
    return body ~= "" and body or nil
end

-- Parse une chaine d'equipe Rematch (une seule equipe).
-- Format : Nom:npc,npc:tag1:tag2:tag3:[P:...:][N:notes]  (les notes ont
-- leurs sauts de ligne echappes en "\n" -> on les restaure).
-- Retourne un payload TeamShare, ou nil si la chaine n'est pas reconnue.
function Xufu.Parse(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("\r", ""):gsub("^%s+", "")

    -- Base obligatoire + extras (Lua "." matche aussi "\n" : les extras
    -- multi-lignes sont bien captures).
    local teamStr, extras = text:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:)(.*)$")
    if not teamStr then return nil end
    local name, npcIDs, t1, t2, t3 = teamStr:match("^([^\n]-):([%w,]*):(%w*):(%w*):(%w*):$")
    if not name then return nil end

    local payload = {
        name = name:gsub("^%s+", ""):gsub("%s+$", ""),
        pets = {}, random = {}, special = {},
    }

    local tags = { t1, t2, t3 }
    for i = 1, 3 do
        local kind, data = DecodeTag(tags[i])
        if kind == "pet" then payload.pets[i] = data
        elseif kind == "random" then payload.random[i] = data
        elseif kind == "special" then payload.special[i] = data end
    end

    -- Cibles (npcID base32, separes par des virgules).
    if npcIDs ~= "" then
        local targets = {}
        for id in npcIDs:gmatch("[^,]+") do
            local n = tonumber(id, 32)
            if n then targets[#targets + 1] = n end
        end
        if #targets > 0 then payload.targets = targets end
    end

    -- Extras : on ne lit que les notes (N:...) pour en extraire le script.
    -- Les preferences (P:...) ne sont pas transportees par le format MVL.
    if extras and extras ~= "" then
        local notes = extras:match("N:(.+)$")
        if notes then
            notes = notes:gsub("\\n", "\n")
            local script = ExtractScript(notes)
            if script then payload.scriptBlob = "code:" .. script end
        end
    end

    return payload
end

-- Detecte une ligne "entete d'equipe" xufu/Rematch (Nom:npcs:tag1:tag2:tag3:).
-- Sert uniquement a decouper un lot de plusieurs codes colles a la suite
-- (import d'une categorie entiere) ; la validation reelle reste Xufu.Parse,
-- qui rejette silencieusement tout faux positif de decoupage.
local function IsHeaderLine(line)
    return line:match("^[^\n]-:[%w,]*:%w*:%w*:%w*:") ~= nil
end

-- Decoupe un texte contenant PLUSIEURS codes xufu colles a la suite (ex :
-- une page de strategies copiee telle quelle) en autant de payloads. Chaque
-- bloc va d'une ligne d'entete a la suivante (ou la fin du texte) ; chaque
-- bloc est decode par Xufu.Parse (aucune logique de decodage dupliquee).
function Xufu.ParseMulti(text)
    if type(text) ~= "string" then return nil end
    -- Normalise les retours a la ligne : reels (\r\n) ET litteraux ("\n" a
    -- deux caracteres, tels qu'exportes par Xufu quand plusieurs teams sont
    -- copiees a la suite) vers de vrais retours a la ligne. Xufu.Parse
    -- desechappe deja "\n" dans les notes : sur du texte deja normalise ici,
    -- ce desechappement devient un no-op sans effet, rien de casse.
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\\n", "\n")
    local starts = {}
    local pos = 1
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if IsHeaderLine(line) then starts[#starts + 1] = pos end
        pos = pos + #line + 1
    end
    if #starts == 0 then return nil end
    local payloads = {}
    for k, s in ipairs(starts) do
        local e = starts[k + 1] and (starts[k + 1] - 1) or #text
        local p = Xufu.Parse(text:sub(s, e))
        if p then payloads[#payloads + 1] = p end
    end
    return #payloads > 0 and payloads or nil
end

-- Enregistrement aupres de MVL : la case xufu de la fenetre d'import (team
-- seule ou categorie) essaiera ces convertisseurs. Aucun couplage inverse.
MVL.RegisterStringImporter(Xufu.Parse)
MVL.RegisterCategoryStringImporter(Xufu.ParseMulti)
