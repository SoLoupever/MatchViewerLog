local addonName, ns = ...

-- ====================================================
-- ENGINE/DIRECTOR — compile le code, execute UNE action par appel
-- (RunOnce) et permet de lire la prochaine action sans l'executer
-- (PeekNext, pour l'affichage du bouton). Portage fidele de la logique
-- de tdBattlePetScript, sans l'UI d'origine.
-- ====================================================

local E         = ns.Engine
local Util      = E.Util
local Action    = E.Action
local Condition = E.Condition
local Stack     = E.Stack

local Director = {}
E.Director = Director

-- Execute la premiere action jouable dont la condition passe. Renvoie true si agi.
function Director:Action(item)
    if type(item) == 'table' then
        for i, v in ipairs(item) do
            if Condition:Run(v[2]) and self:Action(v[1]) then
                return true
            end
        end
    elseif type(item) == 'string' then
        if Action:Run(item) then
            return true
        end
    else
        error('No item')
    end
end

-- Comme Action mais sans executer : renvoie la chaine de la prochaine action.
function Director:Peek(item)
    if type(item) == 'table' then
        for i, v in ipairs(item) do
            if Condition:Run(v[2]) then
                local r = self:Peek(v[1])
                if r then return r end
            end
        end
    elseif type(item) == 'string' then
        if Action:Test(item) then
            return item
        end
    end
end

local function CheckCondition(item)
    if type(item) == 'string' then
        return Condition:ParseCondition(item)
    elseif type(item) == 'table' then
        for i, v in ipairs(item) do
            CheckCondition(v)
        end
    elseif not item then
        return
    else
        Util.assert(false, 'Invalid Script (Struct Error)')
    end
end

local function CheckAction(item)
    if type(item) == 'string' then
        return Action:ParseAction(item)
    elseif type(item) == 'table' then
        for i, v in ipairs(item) do
            CheckCondition(v[2])
            CheckAction(v[1])
        end
    else
        Util.assert(false, 'Invalid Script (Struct Error)')
    end
end

function Director:Check(item)
    return pcall(CheckAction, item)
end

local function MergeCondition(...)
    local dest = {}
    local function merge(...)
        for i = 1, select('#', ...) do
            local v = select(i, ...)
            if type(v) == 'table' then
                merge(unpack(v))
            elseif type(v) == 'string' then
                v = v:trim()
                if v ~= '' then tinsert(dest, v) end
            end
        end
    end
    merge(...)
    if #dest > 1 then
        return dest
    elseif #dest == 1 then
        return dest[1]
    else
        return nil
    end
end

function Director:Build(code)
    if type(code) ~= 'string' then
        return nil, 'No code'
    end

    local script = {}
    local stack  = Stack.New()
    stack:Push(script)

    for line in code:gmatch('[^\r\n]+') do
        line = line:trim()

        if line ~= '' then
            local script = stack:Top()
            local action, condition do
                if line:find('^%-%-') then
                    action = line
                elseif line:find('[', nil, true) then
                    action, condition = line:match('^/?([^%[]-)%s*%[([^%]]+)%]$')
                else
                    action = line:match('^/?(.+)$')
                end
            end

            if not action then
                return nil, format('Invalid Line: `%s`', line)
            end

            if condition then
                condition = MergeCondition({strsplit('&', condition)})
            end

            if action == 'if' then
                stack:Push({})
                tinsert(script, {stack:Top(), condition})
            elseif action == 'endif' or action == 'ei' then
                stack:Pop()

                local parent = stack:Top()
                if not parent then
                    return nil, 'Invalid Script: if endif unpaired'
                end

                if #script == 1 then
                    local dest = parent[#parent]
                    local item = script[1]
                    dest[1] = item[1]
                    dest[2] = MergeCondition(dest[2], item[2])
                end
            else
                tinsert(script, {action, condition})
            end
        end
    end

    if stack:Top() ~= script then
        return nil, 'Invalid Script: if endif unpaired'
    end

    local ok, err = Director:Check(script)
    if not ok then
        return nil, err
    end
    return script
end

-- ---- API publique du moteur ----

-- Compile ; renvoie compiled | nil, err.
function E.Build(code)
    return Director:Build(code)
end

-- Execute une action. A APPELER SUR CLIC MATERIEL uniquement.
function E.RunOnce(compiled)
    if not (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()) then
        return false
    end
    if type(compiled) ~= 'table' then return false end
    local ok, ran = pcall(function() return Director:Action(compiled) end)
    if not ok then ns.Debug("RunOnce error", ran) end
    return ok and ran or false
end

-- Chaine de la prochaine action (sans executer), ou nil.
function E.PeekNext(compiled)
    if type(compiled) ~= 'table' then return nil end
    local ok, res = pcall(function() return Director:Peek(compiled) end)
    if not ok then ns.Debug("PeekNext error", res) end
    return ok and res or nil
end
