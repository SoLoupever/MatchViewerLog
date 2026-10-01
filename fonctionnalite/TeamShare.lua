local addonName, ns = ...

-- ====================================================
-- TEAMSHARE (codec) — encodage/decodage d'une equipe en code copiable, et
-- application d'un payload importe (creation de l'equipe). Pure donnee :
-- aucun CreateFrame ici, voir ui/dialogs/TeamShareDialog.lua pour la fenetre.
-- Le code encode : mascottes (speciesID + breed + sorts choisis), slots
-- aleatoires par type, et un blob de script OPAQUE fourni par un
-- compagnon via les hooks (ns.exportHooks / ns.importHooks). MVL ne
-- connait pas le format du script : il ne fait que le transporter.
-- Format : "MVLT1:" + base64( lignes ).
-- ====================================================

local TeamShare = ns.RegisterModule("TeamShare", {})
ns.TeamShare = TeamShare

-- ---- base64 (octets quelconques : le code de script peut tout contenir) ----
local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(data)
    if not data then return "" end
    return ((data:gsub(".", function(x)
        local r, b = "", x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
        return B:sub(c + 1, c + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function b64dec(data)
    if not data then return nil end
    data = data:gsub("[^" .. "A-Za-z0-9+/" .. "=]", "")
    return (data:gsub("=", ""):gsub(".", function(x)
        local f = B:find(x, 1, true)
        if not f then return "" end
        local r, b = "", f - 1
        for i = 6, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

-- ---- construction d'un payload depuis N'IMPORTE QUELLE equipe stockee ----
-- t : { name, pets[i]=petID, abil[i]={a1,a2,a3}, random[i], special[i],
--       targets={npcID,...} / target=npcID, id=teamID }. Meme forme que
-- ns.DB.teams[id] : sert a l'export d'une team seule (BuildPayload, via
-- l'equipe en cours d'edition) ET a l'export d'une categorie entiere (une
-- team stockee a la fois, sans passer par l'edition en cours).
-- includeBreed (bool) : si vrai, le breed reel est ecrit (import strict, cf.
-- TeamResolve.ScanForOwned) ; sinon "0" (import tolerant, comme si le breed
-- etait indetectable). Choix fait dans TeamShareDialog (case a cocher export,
-- decochee par defaut).
-- includeNotes (bool) : si vrai, les notes libres de la team (t.notes) sont
-- ecrites dans le code (case a cocher export, decochee par defaut).
function TeamShare.BuildPayloadFromTeam(t, includeBreed, includeNotes)
    local payload = { v = 1, name = t.name or "", pets = {}, random = {}, special = {} }
    for i = 1, 3 do
        if t.random and t.random[i] then
            payload.random[i] = t.random[i]
        elseif t.special and t.special[i] then
            payload.special[i] = t.special[i]
        elseif type(t.pets and t.pets[i]) == "string" then
            local species = C_PetJournal.GetPetInfoByPetID(t.pets[i])
            local breed = (includeBreed and ns.Breed and ns.Breed.GetForPetID(t.pets[i])) or "0"
            local a = (t.abil and t.abil[i]) or {}
            payload.pets[i] = {
                species = species or 0, breed = breed,
                abil = { a[1] or 0, a[2] or 0, a[3] or 0 },
            }
        end
    end
    local tg = t.targets or (t.target and { t.target }) or nil
    if tg and #tg > 0 then
        payload.targets = {}
        for _, n in ipairs(tg) do payload.targets[#payload.targets + 1] = n end
    end
    if includeNotes and t.notes and t.notes ~= "" then payload.notes = t.notes end
    -- Compagnons : injection du script (blob opaque).
    for _, fn in ipairs(ns.exportHooks or {}) do pcall(fn, payload, t.id) end
    return payload
end

-- Payload de l'equipe en cours d'edition : cible(s) lues sur sa team source
-- (l'equipe en edition ne les porte pas elle-meme), pour survivre a l'export.
function TeamShare.BuildPayload(includeBreed, includeNotes)
    local c = ns.Teams.current
    local src = c.sourceTeamID and ns.DB.teams[c.sourceTeamID]
    return TeamShare.BuildPayloadFromTeam({
        id = c.sourceTeamID, name = c.name,
        pets = c.pets, abil = c.abil, random = c.random, special = c.special,
        targets = src and src.targets, target = src and src.target,
        notes = src and src.notes,
    }, includeBreed, includeNotes)
end

-- ---- lignes d'un payload (une "team seule" = ces lignes prefixees de MVL1 ;
-- une categorie = plusieurs blocs de ces memes lignes a la suite) ----
local function EncodeLines(payload)
    local lines = { "N " .. b64enc(payload.name or "") }
    for i = 1, 3 do
        local p = payload.pets[i]
        if p then
            lines[#lines + 1] = string.format("P %d %d %s %d %d %d",
                i, p.species or 0, p.breed or "0", p.abil[1] or 0, p.abil[2] or 0, p.abil[3] or 0)
        end
        if payload.random[i] then
            if payload.random[i] == ns.RANDOM_XP then
                lines[#lines + 1] = "RX " .. i
            else
                lines[#lines + 1] = string.format("R %d %d", i, payload.random[i])
            end
        end
        if payload.special[i] then
            lines[#lines + 1] = string.format("S %d %s", i, payload.special[i])
        end
    end
    if payload.targets and #payload.targets > 0 then
        lines[#lines + 1] = "T " .. table.concat(payload.targets, " ")
    end
    if payload.scriptBlob and payload.scriptBlob ~= "" then
        lines[#lines + 1] = "SB " .. b64enc(payload.scriptBlob)
    end
    -- Notes en base64 : sauts de ligne et caracteres libres sans risque.
    if payload.notes and payload.notes ~= "" then
        lines[#lines + 1] = "NT " .. b64enc(payload.notes)
    end
    return lines
end

local function DecodeLines(raw)
    local payload = { name = "", pets = {}, random = {}, special = {} }
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local tag, rest = line:match("^(%S+)%s*(.*)$")
        if tag == "N" then
            payload.name = b64dec(rest) or ""
        elseif tag == "P" then
            local slot, sp, br, a1, a2, a3 = rest:match("^(%d+)%s+(%d+)%s+(%S+)%s+(%d+)%s+(%d+)%s+(%d+)$")
            slot = tonumber(slot)
            if slot then
                payload.pets[slot] = {
                    species = tonumber(sp), breed = br,
                    abil = { tonumber(a1), tonumber(a2), tonumber(a3) },
                }
            end
        elseif tag == "R" then
            local slot, t = rest:match("^(%d+)%s+(%d+)$")
            slot = tonumber(slot)
            if slot then payload.random[slot] = tonumber(t) end
        elseif tag == "RX" then
            local slot = tonumber(rest:match("^(%d+)$"))
            if slot then payload.random[slot] = ns.RANDOM_XP end
        elseif tag == "S" then
            local slot, kind = rest:match("^(%d+)%s+(%S+)$")
            slot = tonumber(slot)
            if slot and (kind == "leveling" or kind == "ignored") then
                payload.special[slot] = kind
            end
        elseif tag == "T" then
            local t = {}
            for n in rest:gmatch("%d+") do t[#t + 1] = tonumber(n) end
            if #t > 0 then payload.targets = t end
        elseif tag == "SB" then
            payload.scriptBlob = b64dec(rest)
        elseif tag == "NT" then
            local n = b64dec(rest)
            if n and n ~= "" then payload.notes = n end
        end
    end
    return payload
end

-- ---- encodage / decodage d'une team seule ----
function TeamShare.Encode(payload)
    local lines = { "MVL1" }
    for _, l in ipairs(EncodeLines(payload)) do lines[#lines + 1] = l end
    return "MVLT1:" .. b64enc(table.concat(lines, "\n"))
end

function TeamShare.Decode(code)
    if type(code) ~= "string" then return nil end
    code = code:gsub("%s+", "")
    local body = code:match("^MVLT1:(.+)$")
    if not body then return nil end
    local raw = b64dec(body)
    if not raw or raw == "" then return nil end
    return DecodeLines(raw)
end

-- ---- encodage / decodage d'une categorie entiere (plusieurs teams) ----
-- Format "MVLC1:" + base64( CN <nom> / CC <couleur> / puis, par team,
-- une ligne MVL1 suivie de ses lignes EncodeLines ). Chaque bloc team est
-- au format IDENTIQUE a l'export d'une team seule, juste concatenes.
function TeamShare.EncodeCategory(catID, includeBreed, includeNotes)
    local cat = ns.Cats and ns.Cats.GetByID(catID)
    if not cat then return nil end
    local lines = { "CN " .. b64enc(cat.name or ""), "CC " .. (cat.color or "") }
    for _, t in ipairs(ns.Cats.TeamsIn(catID)) do
        local payload = TeamShare.BuildPayloadFromTeam(t, includeBreed, includeNotes)
        lines[#lines + 1] = "MVL1"
        for _, l in ipairs(EncodeLines(payload)) do lines[#lines + 1] = l end
    end
    return "MVLC1:" .. b64enc(table.concat(lines, "\n"))
end

-- Retourne { name, color, teams = {payload, ...} }, ou nil si invalide.
function TeamShare.DecodeCategory(code)
    if type(code) ~= "string" then return nil end
    code = code:gsub("%s+", "")
    local body = code:match("^MVLC1:(.+)$")
    if not body then return nil end
    local raw = b64dec(body)
    if not raw or raw == "" then return nil end
    local catPayload = { name = "", color = nil, teams = {} }
    local block
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local tag, rest = line:match("^(%S+)%s*(.*)$")
        if tag == "CN" then
            catPayload.name = b64dec(rest) or ""
        elseif tag == "CC" then
            catPayload.color = rest ~= "" and rest or nil
        elseif tag == "MVL1" then
            if block then catPayload.teams[#catPayload.teams + 1] = DecodeLines(table.concat(block, "\n")) end
            block = {}
        elseif block then
            block[#block + 1] = line
        end
    end
    if block then catPayload.teams[#catPayload.teams + 1] = DecodeLines(table.concat(block, "\n")) end
    return #catPayload.teams > 0 and catPayload or nil
end

-- ---- application d'un payload importe (creation de l'equipe) ----
-- Expose comme methode : l'import Xufu (chaine Rematch) reutilise ce meme
-- chemin de creation + hooks au lieu d'un systeme parallele.
-- skipLoad : ne charge pas l'equipe creee au centre et n'emet pas
-- TEAMS_CHANGED (import par lot, ex. categorie entiere : ApplyCategoryPayload
-- emet un seul signal a la fin au lieu d'un par equipe importee).
function TeamShare.ApplyPayload(payload, category, skipLoad)
    local pets, abil, random, special, unowned = {}, {}, {}, {}, {}
    local missing = 0
    for i = 1, 3 do
        local p = payload.pets[i]
        if p and p.species and p.species > 0 then
            local pid = ns.Teams.FindOwnedPet(p.species, p.breed)
            if pid then
                pets[i] = pid
                if p.abil and (p.abil[1] or p.abil[2] or p.abil[3]) then
                    abil[i] = { p.abil[1] ~= 0 and p.abil[1] or nil,
                                p.abil[2] ~= 0 and p.abil[2] or nil,
                                p.abil[3] ~= 0 and p.abil[3] or nil }
                end
            else
                -- Non possedee : on la garde pour l'afficher (icone grisee +
                -- cadenas + attaques choisies) au lieu de la faire disparaitre.
                unowned[i] = { species = p.species, breed = p.breed, abil = p.abil }
                missing = missing + 1
            end
        end
        if payload.random[i] then random[i] = payload.random[i] end
        if payload.special and payload.special[i] then special[i] = payload.special[i] end
    end
    local id = ns.Teams.CreateStored({ name = payload.name, pets = pets, abil = abil, random = random, special = special, unowned = unowned, category = category, targets = payload.targets }, skipLoad)
    if id then
        if payload.notes then ns.Teams.SetNotes(id, payload.notes) end
        for _, fn in ipairs(ns.importHooks or {}) do pcall(fn, payload, id) end
        if not skipLoad then
            local team = ns.DB.teams[id]
            if team then ns.Teams.Load(team) end
        end
    end
    return id, missing
end

-- Applique une categorie importee : cree la categorie (sauf si
-- existingCategoryID est fourni, auquel cas les teams rejoignent une
-- categorie existante) puis chaque team dedans, en silence (voir skipLoad
-- ci-dessus) ; un seul CATS_CHANGED/TEAMS_CHANGED a la fin du lot.
-- Retourne catID, nbEquipesImportees, nbMascottesNonPossedees.
function TeamShare.ApplyCategoryPayload(catPayload, existingCategoryID)
    local catID = existingCategoryID
    if not catID then
        if not (ns.Cats and catPayload.name and catPayload.name ~= "") then return nil end
        catID = ns.Cats.Create(catPayload.name, catPayload.color)
    end
    local imported, missing = 0, 0
    for _, payload in ipairs(catPayload.teams) do
        local id, m = TeamShare.ApplyPayload(payload, catID, true)
        if id then imported = imported + 1; missing = missing + (m or 0) end
    end
    ns.Fire("CATS_CHANGED"); ns.Fire("TEAMS_CHANGED")
    return catID, imported, missing
end
